package com.howmuch.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.SetOptions;
import com.google.cloud.firestore.WriteResult;
import com.google.cloud.firestore.WriteBatch;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.dto.UserProfileResponse;
import com.howmuch.dto.StoreCoordinates;
import com.howmuch.dto.NotificationSettingsDto;
import com.howmuch.dto.PriceAlertSubscriptionDto;
import com.howmuch.dto.PriceAlertSubscriptionRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.event.EventListener;
import org.springframework.core.io.ClassPathResource;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.multipart.MultipartFile;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalTime;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.ExecutionException;
import java.util.stream.Stream;

@Slf4j
@Service
public class FirebaseService {

    private final Firestore db;
    private final ReportImageStorage reportImageStorage;
    private final ObjectMapper objectMapper = new ObjectMapper();
    private TruePriceService truePriceService;
    private StoreHoursCatalog storeHoursCatalog;

    /**
     * 착한가격업소(공공데이터) 인메모리 캐시.
     * Firestore 일일 읽기 한도(무료 5만) 보호를 위해 요청마다 읽지 않습니다.
     * volatile 참조 교체 방식이라 조회 중에도 안전합니다.
     */
    private volatile List<Map<String, Object>> cachedStores = List.of();

    /** 자동 갱신되는 공공데이터 원본. 행안부 검증 보강 목록과 분리해 주간 스냅샷에 역혼입되지 않게 합니다. */
    private volatile List<Map<String, Object>> cachedBaseStores = List.of();

    /** 사용자 제보 매장 인메모리 캐시 (bounds 조회 시 Firestore 실시간 조회 제거) */
    private volatile List<Map<String, Object>> cachedUserStores = List.of();
    /** Reviewed overlays survive snapshots/restarts; source records are never overwritten. */
    private volatile Map<String, Map<String, Object>> cachedStoreCorrections = Map.of();
    private static final String STORE_CORRECTIONS_COLLECTION = "store_corrections";

    /** /api/stores/all 응답 캐시. 원본 캐시 참조가 바뀌면 자동으로 새로 만듭니다. */
    private final Object allStoresCacheLock = new Object();
    private volatile AllStoresCacheEntry allStoresCache = null;

    /** 커뮤니티 피드 인메모리 캐시 (60초 TTL, N+1 Firestore 읽기 및 쿼터 보호) */
    private final Object feedsCacheLock = new Object();
    private volatile List<com.howmuch.dto.FeedResponseDto> cachedFeeds = null;
    private volatile long lastFeedsCacheTime = 0L;
    private static final long FEEDS_CACHE_TTL_MS = 60_000L;

    private static final int REPORT_IMAGE_MAX_COUNT = 3;
    private static final long REPORT_IMAGE_MAX_BYTES = 5L * 1024L * 1024L;
    private static final int MAX_NOTIFICATION_RESULTS = 100;
    private static final int MAX_COMMUNITY_COMMENTS = 200;
    private static final int MAX_COMMUNITY_REPLIES = 100;

    @Value("${admin.list.max-items:500}")
    private int adminListMaxItems = 500;

    @Value("${community.feed.max-items:500}")
    private int communityFeedMaxItems = 500;

    /** 공공데이터 마지막 갱신 성공 시각 (24시간 가드: 1시간 주기 실행되지만 성공 후 24시간 내엔 Firestore 미호출) */
    private volatile long lastGovRefreshSuccessMillis = 0L;

    /** 스냅샷 파일 경로 (기본: 작업 디렉터리 data/stores-snapshot.json) */
    @Value("${stores.snapshot.path:data/stores-snapshot.json}")
    private String snapshotPath;

    public FirebaseService(Firestore db, ReportImageStorage reportImageStorage) {
        this.db = db;
        this.reportImageStorage = reportImageStorage;
    }

    @Autowired
    public void setTruePriceService(TruePriceService truePriceService) {
        this.truePriceService = truePriceService;
    }

    @Autowired
    public void setStoreHoursCatalog(StoreHoursCatalog storeHoursCatalog) {
        this.storeHoursCatalog = storeHoursCatalog;
    }

    @Async
    @EventListener(ApplicationReadyEvent.class)
    public void warmStoreCaches() {
        try {
            loadStoreCorrections();
            // 시작 전에 동기로 올린 스냅샷이 있으면 다시 읽지 않습니다(BE-CORE-7).
            if (cachedStores.isEmpty()) {
                // 1순위: 디스크 스냅샷 (같은 인스턴스 재시작 시 Firestore 읽기 0)
                if (loadGovStoresFromDisk()) {
                    log.info("디스크 스냅샷에서 매장 {}개를 로드했습니다.", cachedStores.size());
                // 2순위: 리포지토리에 커밋된 classpath 스냅샷 (신규 인스턴스 콜드스타트 대비)
                } else if (loadGovStoresFromClasspath()) {
                    log.info("classpath 스냅샷에서 매장 {}개를 로드했습니다.", cachedStores.size());
                // 3순위: Firestore 로드 후 디스크에 영속화 (하루 1회 갱신 주기 내 최초 1회)
                } else {
                    refreshGovStores();
                }
            }
            // 사용자 제보 매장은 소량이므로 부팅 시 로드
            loadUserStoresFromFirestore();
        } finally {
            storeCatalogWarmingUp = false;
        }
    }

    /** 사용자 제보 매장·매장 보정의 첫 로드가 끝나기 전인지 여부(BE-CORE-7). */
    private volatile boolean storeCatalogWarmingUp = true;

    /**
     * BE-CORE-7: 서버 시작 직후 첫 요청 전에 번들(디스크·classpath) 스냅샷을 동기로 올려
     * 콜드스타트 구간에 지도 목록이 비거나 매장 상세가 404가 되지 않게 합니다. Firestore는 읽지 않습니다.
     */
    @jakarta.annotation.PostConstruct
    void loadBundledStoresBeforeServing() {
        if (!cachedStores.isEmpty()) return;
        if (loadGovStoresFromDisk()) {
            log.info("시작 전 디스크 스냅샷에서 매장 {}개를 로드했습니다.", cachedStores.size());
        } else if (loadGovStoresFromClasspath()) {
            log.info("시작 전 classpath 스냅샷에서 매장 {}개를 로드했습니다.", cachedStores.size());
        }
    }

    /**
     * 매장 목록이 아직 준비 중이면 true입니다. 이때 "매장을 찾을 수 없음"은 확정 답이 아니므로
     * 컨트롤러가 404·422 대신 503과 Retry-After로 응답합니다.
     */
    public boolean isStoreCatalogWarmingUp() {
        return storeCatalogWarmingUp || cachedStores.isEmpty();
    }

    /**
     * 공공데이터 매장 Firestore 갱신: 시작 10분 후 + 1시간 주기로 실행.
     * 단, 마지막 성공 후 24시간이 지나지 않았으면 Firestore를 호출하지 않고 건너뜁니다.
     * → 평시 일일 읽기 ~1.1만 1회, 실패(쿼터 초과) 시에도 1시간 뒤 자동 재시도.
     */
    /** 공공데이터 갱신 메타 문서 위치 (재시작 후에도 24h 가드 유지용) */
    private static final String GOV_META_COLLECTION = "meta";
    private static final String GOV_META_DOC = "govStores";

    @Scheduled(initialDelayString = "${stores.refresh.initial-delay-ms:600000}",
            fixedDelayString = "${stores.refresh.delay-ms:3600000}")
    public void refreshGovStores() {
        if (System.currentTimeMillis() - lastGovRefreshSuccessMillis < 86_400_000L
                && !cachedStores.isEmpty()) {
            return;
        }
        // 💡 인메모리 가드(lastGovRefreshSuccessMillis)는 재시작 시 0으로 초기화됨
        // → Render 재배포/재시작마다 전량(1.1만) 강제 갱신되던 문제 방지:
        //   Firestore 메타 문서의 마지막 갱신 시각을 읽기 1회로 확인해 24h 가드를 영속화
        try {
            DocumentSnapshot meta = db.collection(GOV_META_COLLECTION).document(GOV_META_DOC).get().get();
            if (meta.exists() && meta.get("lastRefreshAt") != null) {
                long last = Long.parseLong(meta.get("lastRefreshAt").toString());
                if (System.currentTimeMillis() - last < 86_400_000L && !cachedStores.isEmpty()) {
                    lastGovRefreshSuccessMillis = last;
                    log.info("24시간 내 매장 갱신 이력이 있어 전량 갱신을 건너뜁니다.");
                    return;
                }
            }
        } catch (Exception e) {
            // 메타 조회 실패(쿼터 초과 등) 시 전량 갱신 대신 이번 주기는 건너뜀 — 기존 캐시 유지
            log.warn("매장 갱신 메타 조회 실패로 이번 주기를 건너뜁니다: {}",
                    e.getClass().getSimpleName());
            return;
        }
        try {
            log.info("Firestore 공공데이터 매장 갱신을 시작합니다.");
            List<Map<String, Object>> stores = db.collection("stores")
                    .get().get().getDocuments().stream()
                    .map(DocumentSnapshot::getData)
                    .toList();
            if (!stores.isEmpty() && isSuspiciousCatalogShrink(stores.size())) {
                // BE-CORE-25: 동기화 오류로 매장 수가 급감한 결과는 설치·디스크 저장하지 않고 기존 캐시를 유지합니다.
                // 매시간 전량을 다시 읽어 일일 쿼터를 소진하지 않도록 이번 시도도 24시간 가드에 기록합니다.
                log.warn("Firestore 매장 수가 급감해 갱신을 보류합니다: 기존 {}개 → 새 {}개",
                        cachedBaseStores.size(), stores.size());
                lastGovRefreshSuccessMillis = System.currentTimeMillis();
                try {
                    db.collection(GOV_META_COLLECTION).document(GOV_META_DOC).set(Map.of(
                            "lastRefreshAt", lastGovRefreshSuccessMillis,
                            "lastRejectedCount", stores.size(),
                            "lastAcceptedCount", cachedBaseStores.size())).get();
                } catch (Exception metaEx) {
                    log.warn("매장 갱신 보류 기록 저장 실패: {}", metaEx.getClass().getSimpleName());
                }
            } else if (!stores.isEmpty()) {
                installGovStores(stores);
                lastGovRefreshSuccessMillis = System.currentTimeMillis();
                persistGovStoresSnapshot(stores);
                try {
                    db.collection(GOV_META_COLLECTION).document(GOV_META_DOC)
                            .set(Map.of("lastRefreshAt", lastGovRefreshSuccessMillis)).get();
                } catch (Exception metaEx) {
                    log.warn("매장 갱신 메타 저장 실패: {}", metaEx.getClass().getSimpleName());
                }
                log.info("공공데이터 매장 갱신 완료: {}개", stores.size());
            } else {
                log.warn("Firestore 매장 결과가 비어 있어 기존 캐시를 유지합니다.");
            }
        } catch (Exception e) {
            // 쿼터 초과 등 실패 시 기존 캐시 유지 (서비스 무중단)
            log.warn("공공데이터 매장 갱신 실패로 기존 캐시를 유지합니다: {}",
                    e.getClass().getSimpleName());
        }
    }

    /** 사용자 제보 매장 갱신: 시작 5분 후 + 10분 주기 (소량 컬렉션) */
    @Scheduled(initialDelayString = "${stores.user.refresh.initial-delay-ms:300000}",
            fixedDelayString = "${stores.user.refresh.delay-ms:600000}")
    public void refreshUserStores() {
        loadUserStoresFromFirestore();
        loadStoreCorrections();
    }

    /** 새 공공데이터가 기존의 80% 미만이면 동기화 오류로 보고 설치하지 않습니다. */
    static final double MIN_CATALOG_RETENTION_RATIO = 0.8;

    boolean isSuspiciousCatalogShrink(int incomingCount) {
        int current = cachedBaseStores.size();
        return current > 0 && incomingCount < current * MIN_CATALOG_RETENTION_RATIO;
    }

    private void loadStoreCorrections() {
        try {
            Map<String, Map<String, Object>> corrections = new HashMap<>();
            for (DocumentSnapshot doc : db.collection(STORE_CORRECTIONS_COLLECTION).get().get().getDocuments()) {
                if (doc.getData() != null) corrections.put(doc.getId(), immutableStoreCopy(doc.getData()));
            }
            synchronized (allStoresCacheLock) {
                // A refresh may have started before an approval committed. Never
                // replace that newer locally committed revision with an older
                // query snapshot (nor drop a commit absent from that snapshot).
                cachedStoreCorrections.forEach((id, current) -> {
                    Map<String, Object> loaded = corrections.get(id);
                    if (loaded == null || correctionRevision(current) > correctionRevision(loaded)) {
                        corrections.put(id, current);
                    }
                });
                cachedStoreCorrections = Map.copyOf(corrections);
                allStoresCache = null;
            }
        } catch (Exception exception) {
            log.warn("매장 수정 기록 조회 실패로 기존 기록을 유지합니다: {}", exception.getClass().getSimpleName());
        }
    }

    private void loadUserStoresFromFirestore() {
        List<Map<String, Object>> beforeRefresh = cachedUserStores;
        try {
            List<Map<String, Object>> userStores = db.collection("stores_user")
                    .get().get().getDocuments().stream()
                    .map(doc -> {
                        Map<String, Object> data = new HashMap<>(doc.getData());
                        data.put("id", doc.getId());
                        return data;
                    })
                    .toList();
            synchronized (allStoresCacheLock) {
                if (cachedUserStores != beforeRefresh) {
                    log.info("조회 중 제보가 변경되어 이전 조회 결과를 캐시에 반영하지 않습니다.");
                    return;
                }
                cachedUserStores = immutableStoreList(userStores);
                allStoresCache = null;
            }
            invalidateCommunityFeedCache();
            log.info("사용자 제보 매장 로드 완료: {}개", userStores.size());
        } catch (Exception e) {
            log.warn("사용자 제보 매장 로드 실패로 기존 캐시를 유지합니다: {}",
                    e.getClass().getSimpleName());
        }
    }

    private boolean loadGovStoresFromDisk() {
        try {
            Path path = Path.of(snapshotPath);
            if (!Files.exists(path) || Files.size(path) < 2) return false;
            List<Map<String, Object>> stores = readStoresJson(Files.newInputStream(path));
            if (stores.isEmpty()) return false;
            installGovStores(stores);
            return true;
        } catch (Exception e) {
            log.warn("디스크 매장 스냅샷 로드 실패: {}", e.getClass().getSimpleName());
            return false;
        }
    }

    private boolean loadGovStoresFromClasspath() {
        try {
            ClassPathResource resource = new ClassPathResource("stores-snapshot.json");
            if (!resource.exists()) return false;
            List<Map<String, Object>> stores = readStoresJson(resource.getInputStream());
            if (stores.isEmpty()) return false;
            installGovStores(stores);
            return true;
        } catch (Exception e) {
            log.warn("classpath 매장 스냅샷 로드 실패: {}", e.getClass().getSimpleName());
            return false;
        }
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> readStoresJson(InputStream in) throws Exception {
        try (in) {
            return objectMapper.readValue(in, List.class);
        }
    }

    /**
     * 자동 갱신 원본과 행안부 상세 API로 별도 검증한 신규 매장을 런타임에서만 합칩니다.
     * 보강 목록은 classpath 파일로 독립 보존되어 Firestore/주간 스냅샷 갱신에 덮어쓰이지 않습니다.
     */
    private void installGovStores(List<Map<String, Object>> baseStores) {
        List<Map<String, Object>> safeBase = immutableStoreList(baseStores);
        cachedBaseStores = safeBase;
        cachedStores = mergeVerifiedSupplement(safeBase);
    }

    private List<Map<String, Object>> mergeVerifiedSupplement(List<Map<String, Object>> baseStores) {
        List<Map<String, Object>> merged = new ArrayList<>();
        Set<String> identities = new HashSet<>();
        Set<String> phoneNumbers = new HashSet<>();
        Set<String> nameAddresses = new HashSet<>();
        for (Map<String, Object> store : baseStores) {
            String identity = stableStoreId(
                    strOrNull(store.get("storeName")),
                    strOrNull(store.get("address")),
                    strOrNull(store.get("phoneNumber")));
            if (!identities.add(identity)) continue;
            merged.add(store);
            String phoneNumber = comparablePhone(store.get("phoneNumber"));
            if (!phoneNumber.isBlank()) phoneNumbers.add(phoneNumber);
            nameAddresses.add(comparableNameAddress(store));
        }
        if (merged.size() != baseStores.size()) {
            log.info("공공데이터 원본의 완전 중복 {}건을 런타임 목록에서 제거했습니다.",
                    baseStores.size() - merged.size());
        }
        try {
            ClassPathResource resource = new ClassPathResource("stores-supplement.json");
            if (!resource.exists()) return List.copyOf(merged);
            List<Map<String, Object>> supplement = readStoresJson(resource.getInputStream());
            int accepted = 0;
            for (Map<String, Object> store : supplement) {
                String name = strOrNull(store.get("storeName"));
                String address = strOrNull(store.get("address"));
                String phoneNumber = strOrNull(store.get("phoneNumber"));
                String expectedId = stableStoreId(name, address, phoneNumber);
                String suppliedId = strOrNull(store.get("storeId"));
                String comparablePhone = comparablePhone(phoneNumber);
                String comparableNameAddress = comparableNameAddress(store);
                if (name == null || name.isBlank() || address == null || address.isBlank()
                        || comparablePhone.length() < 8
                        || !expectedId.equals(suppliedId)
                        || !hasValidStoreCoordinate(store)
                        || identities.contains(expectedId)
                        || phoneNumbers.contains(comparablePhone)
                        || nameAddresses.contains(comparableNameAddress)) {
                    log.warn("검증 보강 매장 1건을 무결성 검사에서 제외했습니다: {}", name);
                    continue;
                }
                identities.add(expectedId);
                phoneNumbers.add(comparablePhone);
                nameAddresses.add(comparableNameAddress);
                merged.add(immutableStoreCopy(store));
                accepted++;
            }
            log.info("행안부 상세 검증 보강 매장 {}개를 합쳤습니다.", accepted);
        } catch (Exception e) {
            log.warn("행안부 검증 보강 목록을 읽지 못해 기본 스냅샷만 제공합니다: {}",
                    e.getClass().getSimpleName());
        }
        return List.copyOf(merged);
    }

    private String comparablePhone(Object value) {
        String digits = value == null ? "" : value.toString().replaceAll("\\D", "");
        return digits.length() >= 8 ? digits : "";
    }

    private String comparableNameAddress(Map<String, Object> store) {
        return normalizeStoreIdentityPart(strOrNull(store.get("storeName"))).replaceAll("[^\\p{L}\\p{N}]", "")
                + "|"
                + normalizeStoreIdentityPart(strOrNull(store.get("address"))).replaceAll("[^\\p{L}\\p{N}]", "");
    }

    /** 스냅샷을 임시 파일에 쓴 뒤 원자적으로 교체 (쓰기 중단으로 인한 파일 깨짐 방지) */
    private void persistGovStoresSnapshot(List<Map<String, Object>> stores) {
        try {
            Path path = Path.of(snapshotPath);
            if (path.getParent() != null) {
                Files.createDirectories(path.getParent());
            }
            Path temp = path.resolveSibling(path.getFileName() + ".tmp");
            objectMapper.writeValue(temp.toFile(), stores);
            Files.move(temp, path, StandardCopyOption.REPLACE_EXISTING);
            log.info("매장 스냅샷 저장을 완료했습니다.");
        } catch (Exception e) {
            log.warn("매장 스냅샷 저장 실패: {}", e.getClass().getSimpleName());
        }
    }

    public List<Map<String, Object>> getAllStores() {
        return getStoreCatalogEntry().discoverableStores();
    }

    public String getAllStoresEtag() { return getStoreCatalogEntry().etag(); }

    /** Body and validation tag must describe one immutable catalog snapshot. */
    public record PublicStoreCatalog(List<Map<String, Object>> stores, String etag) {}

    public PublicStoreCatalog getPublicStoreCatalog() {
        AllStoresCacheEntry entry = getStoreCatalogEntry();
        return new PublicStoreCatalog(entry.discoverableStores(), entry.etag());
    }

    /** Includes closed stores for existing favorites, reviewed history and detail only. */
    public Map<String, Object> getStoreById(String storeId) {
        return getStoreCatalogEntry().stores().stream()
                .filter(store -> java.util.Objects.equals(storeId, store.get("storeId")))
                .findFirst().orElse(null);
    }

    private AllStoresCacheEntry getStoreCatalogEntry() {
        List<Map<String, Object>> govSnapshot = cachedStores;
        List<Map<String, Object>> userSnapshot = cachedUserStores;
        Map<String, Map<String, Object>> correctionSnapshot = cachedStoreCorrections;
        AllStoresCacheEntry cached = allStoresCache;
        if (cached != null && cached.matches(govSnapshot, userSnapshot, correctionSnapshot)) {
            return cached;
        }

        synchronized (allStoresCacheLock) {
            govSnapshot = cachedStores;
            userSnapshot = cachedUserStores;
            correctionSnapshot = cachedStoreCorrections;
            cached = allStoresCache;
            if (cached != null && cached.matches(govSnapshot, userSnapshot, correctionSnapshot)) {
                return cached;
            }
            List<Map<String, Object>> stores = buildAllStores(govSnapshot, userSnapshot, correctionSnapshot);
            List<Map<String, Object>> discoverable = stores.stream()
                    .filter(store -> !Boolean.TRUE.equals(store.get("isClosed"))).toList();
            String etag;
            try {
                byte[] digest = MessageDigest.getInstance("SHA-256").digest(objectMapper.writeValueAsBytes(discoverable));
                etag = "\"" + java.util.HexFormat.of().formatHex(digest) + "\"";
            } catch (Exception exception) { throw new IllegalStateException("매장 목록의 검증값을 계산하지 못했습니다.", exception); }
            allStoresCache = new AllStoresCacheEntry(govSnapshot, userSnapshot, correctionSnapshot, stores, discoverable, etag);
            return allStoresCache;
        }
    }

    private record AllStoresCacheEntry(
            List<Map<String, Object>> govSource,
            List<Map<String, Object>> userSource,
            Map<String, Map<String, Object>> correctionSource,
            List<Map<String, Object>> stores,
            List<Map<String, Object>> discoverableStores,
            String etag) {
        boolean matches(
                List<Map<String, Object>> currentGovSource,
                List<Map<String, Object>> currentUserSource,
                Map<String, Map<String, Object>> currentCorrections) {
            return govSource == currentGovSource && userSource == currentUserSource && correctionSource == currentCorrections;
        }
    }

    private List<Map<String, Object>> buildAllStores(
            List<Map<String, Object>> govSnapshot,
            List<Map<String, Object>> userSnapshot,
            Map<String, Map<String, Object>> correctionSnapshot) {
        Map<String, Map<String, Object>> publicStoresById = new LinkedHashMap<>();
        Set<String> publicPhones = new HashSet<>();
        Set<String> publicNamesAndAddresses = new HashSet<>();
        for (Map<String, Object> rawStore : govSnapshot) {
            Map<String, Object> store = toPublicStore(rawStore, "GOV", correctionSnapshot);
            publicStoresById.put(String.valueOf(store.get("storeId")), store);
            addPublicStoreIdentity(store, publicPhones, publicNamesAndAddresses);
        }
        for (Map<String, Object> rawStore : userSnapshot) {
            if (!isPubliclyVisible(rawStore)) continue;
            Map<String, Object> store = toPublicStore(rawStore, "USER", correctionSnapshot);
            String storeId = String.valueOf(store.get("storeId"));
            String phone = comparablePhone(store.get("phoneNumber"));
            String nameAndAddress = comparableNameAddress(store);
            if (publicStoresById.containsKey(storeId)
                    || (!phone.isBlank() && publicPhones.contains(phone))
                    || (!"|".equals(nameAndAddress)
                    && publicNamesAndAddresses.contains(nameAndAddress))) {
                continue;
            }
            publicStoresById.put(storeId, store);
            addPublicStoreIdentity(store, publicPhones, publicNamesAndAddresses);
        }
        return publicStoresById.values().stream()
                .map(this::immutableStoreCopy)
                .toList();
    }

    private Map<String, Object> toPublicStore(Map<String, Object> rawStore, String source,
            Map<String, Map<String, Object>> correctionSnapshot) {
        Map<String, Object> normalized = withStableStoreId(rawStore);
        normalized = applyStoreCorrection(normalized, correctionSnapshot.get(String.valueOf(normalized.get("storeId"))));
        Map<String, Object> result = new HashMap<>();
        for (String field : List.of(
                "storeId", "storeName", "address", "phoneNumber", "industry",
                "menu1", "price1", "menu2", "price2", "menu3", "price3",
                "menu4", "price4", "free1", "free2", "free3", "free4", "latitude", "longitude", "openingHours", "isClosed", "correctionRevision")) {
            if (normalized.containsKey(field)) {
                result.put(field, immutablePublicValue(normalized.get(field)));
            }
        }
        result.put("source", source);
        return result;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> applyStoreCorrection(Map<String, Object> original, Map<String, Object> correction) {
        Map<String, Object> result = new HashMap<>(original);
        if (correction != null && correction.get("fields") instanceof Map<?, ?> fields) {
            for (var entry : fields.entrySet()) {
                String field = String.valueOf(entry.getKey());
                if (field.matches("(?:menu|price|free)[1-4]") || List.of("address", "latitude", "longitude", "isClosed").contains(field)) {
                    result.put(field, entry.getValue());
                }
            }
            result.put("correctionRevision", correction.getOrDefault("revision", 0L));
        } else result.put("correctionRevision", 0L);
        result.putIfAbsent("isClosed", false);
        for (int i = 1; i <= 4; i++) {
            result.putIfAbsent("free" + i, false);
            result.putIfAbsent("menu" + i, ""); result.putIfAbsent("price" + i, "");
        }
        return result;
    }

    private List<Map<String, Object>> immutableStoreList(List<Map<String, Object>> stores) {
        return stores.stream()
                .map(this::immutableStoreCopy)
                .toList();
    }

    private Map<String, Object> immutableStoreCopy(Map<String, Object> store) {
        Map<String, Object> copy = new HashMap<>();
        for (Map.Entry<String, Object> entry : store.entrySet()) {
            copy.put(entry.getKey(), immutablePublicValue(entry.getValue()));
        }
        return Collections.unmodifiableMap(copy);
    }

    private Object immutablePublicValue(Object value) {
        if (value instanceof Map<?, ?> map) {
            Map<String, Object> copy = new LinkedHashMap<>();
            for (Map.Entry<?, ?> entry : map.entrySet()) {
                if (entry.getKey() == null) continue;
                copy.put(String.valueOf(entry.getKey()), immutablePublicValue(entry.getValue()));
            }
            return Collections.unmodifiableMap(copy);
        }
        if (value instanceof List<?> list) {
            return list.stream()
                    .map(this::immutablePublicValue)
                    .toList();
        }
        return value;
    }

    private void addPublicStoreIdentity(
            Map<String, Object> store, Set<String> phones, Set<String> namesAndAddresses) {
        String phone = comparablePhone(store.get("phoneNumber"));
        if (!phone.isBlank()) phones.add(phone);
        String nameAndAddress = comparableNameAddress(store);
        if (!"|".equals(nameAndAddress)) namesAndAddresses.add(nameAndAddress);
    }

    /**
     * AI 추천에 사용할 매장을 서버 캐시에서 다시 확인합니다.
     * 클라이언트가 보낸 매장명·가격·출처는 신뢰하지 않습니다.
     */
    public List<Map<String, Object>> getAiStoreContext(
            List<String> storeIds, Double latitude, Double longitude) {
        return getAiStoreContext(storeIds, latitude, longitude, 3000);
    }

    public List<Map<String, Object>> getAiStoreContext(
            List<String> storeIds, Double latitude, Double longitude, int radiusMeters) {
        validateRecommendationRadius(radiusMeters);
        if (!isValidCoordinate(latitude, longitude)) return List.of();
        // Client candidate IDs are hints, never an authorization to include an out-of-radius shop.
        List<Map<String, Object>> candidates = new ArrayList<>();
        for (Map<String, Object> store : getAllStores()) {
            if (!hasValidStoreCoordinate(store)) continue;
            double distance = haversine(latitude, longitude, parseLat(store), parseLng(store));
            if (distance > radiusMeters) continue;
            Map<String, Object> context = new HashMap<>();
            context.put("storeId", store.get("storeId"));
            context.put("storeName", store.getOrDefault("storeName", "매장명 없음"));
            addAiStoreDetails(context, store);
            context.put("source", store.get("source"));
            context.put("distanceMeters", (int) Math.round(distance));
            candidates.add(context);
        }
        candidates.sort(Comparator.comparingInt(item -> (int) item.get("distanceMeters")));
        return candidates.stream().limit(500).toList();
    }

    private void validateRecommendationRadius(int radiusMeters) {
        if (radiusMeters < 1000 || radiusMeters > 15000 || radiusMeters % 1000 != 0) {
            throw new IllegalArgumentException("추천 거리는 1~15km에서 1km 단위로 선택해주세요.");
        }
    }

    private void addAiStoreDetails(Map<String, Object> context, Map<String, Object> store) {
        context.put("industry", String.valueOf(store.getOrDefault("industry", "")));
        context.put("address", store.getOrDefault("address", ""));
        context.put("latitude", store.get("latitude"));
        context.put("longitude", store.get("longitude"));
        for (int i = 1; i <= 4; i++) {
            context.put("menu" + i, String.valueOf(store.getOrDefault("menu" + i, "")));
            context.put("price" + i, String.valueOf(store.getOrDefault("price" + i, "")));
            context.put("free" + i, Boolean.TRUE.equals(store.get("free" + i)));
        }
    }

    /** 참가격을 우선하고, 미지원 품목은 실제 착한가격업소 가격 표본으로 보완합니다. */
    public java.util.Optional<ReferencePrices.Estimate> estimateReferencePrice(
            String menu, String industry, String address) {
        if (truePriceService != null) {
            java.util.Optional<ReferencePrices.Estimate> official =
                    truePriceService.estimate(menu, industry, address);
            if (official.isPresent()) return official;
        }
        return ReferencePrices.estimateFromPublicStores(getAllStores().stream()
                .filter(store -> "GOV".equals(store.get("source"))).toList(), menu, industry);
    }

    /** 자동화 작업이 classpath 스냅샷을 갱신할 수 있도록 안정된 순서의 캐시 복사본을 반환합니다. */
    public List<Map<String, Object>> getGovStoresSnapshot() {
        Comparator<Map<String, Object>> stableOrder = Comparator
                .comparing(
                        (Map<String, Object> item) -> String.valueOf(item.getOrDefault("storeName", "")),
                        String.CASE_INSENSITIVE_ORDER)
                .thenComparing(
                        item -> String.valueOf(item.getOrDefault("address", "")),
                        String.CASE_INSENSITIVE_ORDER);
        List<Map<String, Object>> baseSnapshot = cachedBaseStores.isEmpty()
                ? cachedStores
                : cachedBaseStores;
        return baseSnapshot.stream()
                .<Map<String, Object>>map(HashMap::new)
                .sorted(stableOrder)
                .toList();
    }

    // 💡 화면 범위(Bounds) 기반 업소 조회 (정부 데이터 + 사용자 제보 통합, 전량 인메모리)
    public List<Map<String, Object>> getStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) {
        return getStoresInBoundsPage(minLat, maxLat, minLng, maxLng).stores();
    }

    /** 지도 범위 조회 상한 */
    static final int MAX_BOUNDS_STORES = 1200;

    /** 범위 안 매장과 상한 때문에 잘렸는지 여부 */
    public record BoundsResult(List<Map<String, Object>> stores, boolean truncated) { }

    /**
     * 계약 C6: 범위 중심에서 가까운 순으로 정렬한 뒤 1,200곳으로 제한합니다. 넓게 줌아웃해도
     * 화면 중앙 근처 매장(사용자 제보 포함)이 가나다·카탈로그 순서 때문에 빠지지 않습니다.
     */
    public BoundsResult getStoresInBoundsPage(double minLat, double maxLat, double minLng, double maxLng) {
        double centerLat = (minLat + maxLat) / 2.0;
        double centerLng = (minLng + maxLng) / 2.0;
        double lngScale = Math.cos(Math.toRadians(centerLat));
        List<Map<String, Object>> inBounds = getAllStores().stream()
                .filter(store -> isInBounds(store, minLat, maxLat, minLng, maxLng))
                .toList();
        if (inBounds.size() <= MAX_BOUNDS_STORES) {
            return new BoundsResult(sortedByCenterDistance(inBounds, centerLat, centerLng, lngScale), false);
        }
        List<Map<String, Object>> nearest = sortedByCenterDistance(inBounds, centerLat, centerLng, lngScale)
                .subList(0, MAX_BOUNDS_STORES);
        return new BoundsResult(List.copyOf(nearest), true);
    }

    private List<Map<String, Object>> sortedByCenterDistance(
            List<Map<String, Object>> stores, double centerLat, double centerLng, double lngScale) {
        // 범위가 10° 이내라 평면 근사로 순서를 정해도 충분합니다(동률은 기존 목록 순서 유지).
        record Ranked(Map<String, Object> store, double distance) { }
        return stores.stream()
                .map(store -> {
                    double dLat = parseLat(store) - centerLat;
                    double dLng = (parseLng(store) - centerLng) * lngScale;
                    return new Ranked(store, dLat * dLat + dLng * dLng);
                })
                .sorted(Comparator.comparingDouble(Ranked::distance))
                .map(Ranked::store)
                .toList();
    }

    /** 매장 상세의 가격 이력 조회. 승인된 가격 변동 제보만 공개합니다. */
    public Map<String, Object> getPriceHistory(String storeIdentity, String menuName) throws Exception {
        Map<String, Object> store = resolveReviewStore(storeIdentity, getStoreCatalogEntry().stores());
        if (store == null) {
            throw new NoSuchElementException("매장을 찾을 수 없습니다.");
        }

        String resolvedMenu = menuName == null || menuName.isBlank()
                ? firstMenu(store)
                : menuName.trim();
        String currentPrice = findMenuPrice(store, resolvedMenu);
        List<Map<String, Object>> history = new ArrayList<>();

        for (Map<String, Object> report : cachedUserStores) {
            if (report == null || !"APPROVED".equals(report.get("status"))
                    || !("PRICE".equals(report.get("resolution")) || StoreCorrectionPolicy.priceReport(report))) continue;
            Map<String, Object> normalized = withStableStoreId(report);
            if (!String.valueOf(store.get("storeId")).equals(String.valueOf(normalized.get("storeId")))) {
                continue;
            }
            Map<String, Object> applied = report.get("appliedFields") instanceof Map<?, ?> fields
                    ? fields.entrySet().stream().collect(java.util.stream.Collectors.toMap(
                            entry -> String.valueOf(entry.getKey()), Map.Entry::getValue)) : report;
            int slot = 1;
            for (int i = 1; i <= 4; i++) if (resolvedMenu.equals(applied.get("menu" + i))) slot = i;
            if ("delete".equals(report.get("changeType")) && report.get("previousFields") instanceof Map<?, ?> previous) {
                for (int i = 1; i <= 4; i++) if (resolvedMenu.equals(previous.get("menu" + i))) slot = i;
                applied = new HashMap<>(applied); applied.put("menu" + slot, resolvedMenu);
            }
            if (!resolvedMenu.equals(String.valueOf(applied.getOrDefault("menu" + slot, "")).trim())) {
                continue;
            }
            String price = String.valueOf(applied.getOrDefault("price" + slot, "")).trim();
            if (price.isBlank() && !"delete".equals(report.get("changeType"))) continue;
            Map<String, Object> item = new HashMap<>();
            item.put("price", price);
            item.put("source", "USER");
            item.put("description", "승인된 가격 변동 반영");
            item.put("free", Boolean.TRUE.equals(applied.get("free" + slot)));
            // BE-CORE-26: 가격이 실제로 바뀐 날은 승인일입니다. 승인 기록이 없는 예전 제보만 작성일을 씁니다.
            item.put("date", stringOrDefault(report, "processedAt", stringOrDefault(report, "createdAt", "")));
            item.put("reportedAt", stringOrDefault(report, "createdAt", ""));
            item.put("changeType", stringOrDefault(report, "changeType", ""));
            history.add(item);
        }
        history.sort((a, b) -> String.valueOf(b.get("date")).compareTo(String.valueOf(a.get("date"))));

        Map<String, Object> result = new HashMap<>();
        result.put("storeId", store.get("storeId"));
        result.put("storeName", store.getOrDefault("storeName", ""));
        result.put("menuName", resolvedMenu);
        result.put("currentPrice", currentPrice);
        result.put("history", history);
        return result;
    }

    private String firstMenu(Map<String, Object> store) {
        for (int index = 1; index <= 4; index++) {
            String menu = strOrNull(store.get("menu" + index));
            if (menu != null && !menu.isBlank()) return menu;
        }
        return "대표 메뉴";
    }

    private String findMenuPrice(Map<String, Object> store, String menuName) {
        for (int index = 1; index <= 4; index++) {
            if (menuName.equals(String.valueOf(store.getOrDefault("menu" + index, "")).trim())) {
                return String.valueOf(store.getOrDefault("price" + index, ""));
            }
        }
        return "";
    }

    /** Price-change validation must use the server catalog, not the client-supplied price. */
    public String getCurrentMenuPrice(String storeId, String storeName, String menuName) {
        if (menuName == null || menuName.isBlank()) return null;
        Map<String, Object> store = resolveReviewStore(storeId != null && !storeId.isBlank() ? storeId : storeName,
                getAllStores());
        if (store == null) return null;
        String price = findMenuPrice(store, menuName);
        return price.isBlank() ? null : price;
    }

    /**
     * 사용자 제보 매장이 공개 지도에 노출 가능한지 판별.
     * APPROVED(어드민 승인) 또는 status 필드가 없는 레거시 제볼만 true.
     */
    private boolean isPubliclyVisible(Map<String, Object> data) {
        if (StoreCorrectionPolicy.informationReport(data) || StoreCorrectionPolicy.priceReport(data)) return false;
        Object status = data.get("status");
        if (status == null || status.toString().isBlank()) return true; // 승인제 도입 전 레거시 데이터
        return "APPROVED".equalsIgnoreCase(status.toString());
    }

    private boolean isInBounds(Map<String, Object> data, double minLat, double maxLat, double minLng, double maxLng) {
        try {
            Object latObj = data.get("latitude");
            Object lngObj = data.get("longitude");
            if (latObj == null || lngObj == null) return false;
            double lat = Double.parseDouble(latObj.toString());
            double lng = Double.parseDouble(lngObj.toString());
            return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
        } catch (NumberFormatException e) {
            return false;
        }
    }

    // 💡 사용자의 매장 제보 저장 (Firestore 쓰기 후 인메모리 캐시에도 즉시 반영)
    public String saveUserReport(com.howmuch.dto.UserReportRequest report) throws Exception {
        report.setStatus("PENDING");
        report.setCreatedAt(java.time.Instant.now().toString());
        // 반려 사유는 관리자만 정합니다. 클라이언트가 보낸 값은 저장하지 않습니다.
        report.setRejectReason(null);
        if (report.getStoreId() == null || report.getStoreId().isBlank()) {
            report.setStoreId(stableStoreId(
                    report.getStoreName(), report.getAddress(), report.getPhoneNumber()));
        }
        validateReportTarget(report);
        report.setImageUrls(normalizeReportImageUrls(
                report.getReporterId(), report.getImageUrls(), Set.of()));

        DocumentReference docRef = db.collection("stores_user").document();
        @SuppressWarnings("unchecked")
        Map<String, Object> data = objectMapper.convertValue(report, Map.class);
        Map<String, Object> targetStore = getStoreById(report.getStoreId());
        if (targetStore != null) data.put("baseRevision", StoreCorrectionPolicy.revision(targetStore));
        ApiFuture<WriteResult> future = docRef.set(data);
        future.get();

        data.put("id", docRef.getId());
        synchronized (allStoresCacheLock) {
            List<Map<String, Object>> updated = new ArrayList<>(cachedUserStores);
            updated.add(immutableStoreCopy(data));
            cachedUserStores = List.copyOf(updated);
            allStoresCache = null;
        }
        invalidateCommunityFeedCache();

        return docRef.getId();
    }

    /**
     * 본인이 수정할 수 있는 제보 원본을 돌려줍니다. 수정 요청 검증 전에 기존 유형·대상을 채우는 데 씁니다.
     */
    public Map<String, Object> getOwnedReportForEdit(String reportId, String reporterUid) throws Exception {
        DocumentSnapshot existing = db.collection("stores_user").document(reportId).get().get();
        if (!existing.exists()) {
            throw new NoSuchElementException("제보를 찾을 수 없습니다.");
        }
        if (reporterUid == null || !reporterUid.equals(existing.getString("reporterId"))) {
            throw new SecurityException("본인의 제보만 수정할 수 있습니다.");
        }
        if ("APPROVED".equalsIgnoreCase(existing.getString("status"))) {
            throw new IllegalArgumentException("승인된 제보는 다시 작성할 수 없습니다. 새 변경 제보를 등록해주세요.");
        }
        return existing.getData() == null ? Map.of() : new HashMap<>(existing.getData());
    }

    /**
     * 계약 C7: 수정 요청에 없는 유형(changeType·reportType)·대상(storeId)·설명은 기존 값으로 채웁니다.
     * 제보의 종류는 수정으로 바뀌지 않습니다. 기존 매장 대상 제보(가격 변동·정보 신고)의 유형이나 대상을
     * 바꾸는 요청과, 신규 매장 제보를 기존 매장 대상 제보로 바꾸는 요청은 거부합니다.
     */
    public static void preserveReportIdentity(
            Map<String, Object> existing, com.howmuch.dto.UserReportRequest report) {
        if (existing == null || report == null) return;
        String existingChangeType = blankToNull(existing.get("changeType"));
        String existingReportType = blankToNull(existing.get("reportType"));
        String existingStoreId = blankToNull(existing.get("storeId"));
        String requestedChangeType = blankToNull(report.getChangeType());
        String requestedReportType = blankToNull(report.getReportType());
        String requestedStoreId = blankToNull(report.getStoreId());
        boolean existingStoreTarget = existingChangeType != null || existingReportType != null;
        if (existingStoreTarget) {
            if ((requestedChangeType != null && !requestedChangeType.equalsIgnoreCase(existingChangeType))
                    || (requestedReportType != null && !requestedReportType.equalsIgnoreCase(existingReportType))) {
                throw new IllegalArgumentException("제보 유형은 수정할 수 없어요. 기존 제보를 삭제한 뒤 새로 제보해주세요.");
            }
            if (requestedStoreId != null && existingStoreId != null && !requestedStoreId.equals(existingStoreId)) {
                throw new IllegalArgumentException("제보 대상 매장은 수정할 수 없어요. 기존 제보를 삭제한 뒤 새로 제보해주세요.");
            }
        } else if (requestedChangeType != null || requestedReportType != null) {
            throw new IllegalArgumentException("신규 매장 제보는 가격 변동이나 정보 신고로 바꿀 수 없어요. 새로 제보해주세요.");
        }
        report.setChangeType(existingChangeType);
        report.setReportType(existingReportType);
        // 신규 매장 제보도 처음 정한 식별자를 유지해야 이름·주소를 고쳐도 같은 제보로 남습니다.
        if (existingStoreId != null) report.setStoreId(existingStoreId);
        else report.setStoreId(requestedStoreId);
        if (blankToNull(report.getDescription()) == null) {
            report.setDescription(blankToNull(existing.get("description")));
        }
    }

    private static String blankToNull(Object value) {
        if (value == null) return null;
        String text = value.toString().trim();
        return text.isEmpty() ? null : text;
    }

    public void updateUserReport(
            String reportId,
            String reporterUid,
            com.howmuch.dto.UserReportRequest report) throws Exception {
        DocumentReference docRef = db.collection("stores_user").document(reportId);
        DocumentSnapshot existing = docRef.get().get();
        if (!existing.exists()) {
            throw new NoSuchElementException("제보를 찾을 수 없습니다.");
        }
        if (!reporterUid.equals(existing.getString("reporterId"))) {
            throw new SecurityException("본인의 제보만 수정할 수 있습니다.");
        }
        if ("APPROVED".equalsIgnoreCase(existing.getString("status"))) {
            throw new IllegalArgumentException("승인된 제보는 다시 작성할 수 없습니다. 새 변경 제보를 등록해주세요.");
        }

        Map<String, Object> existingData = existing.getData() == null ? Map.of() : existing.getData();
        preserveReportIdentity(existingData, report);
        List<String> existingImageUrls = stringList(existing.get("imageUrls"));
        report.setReporterId(reporterUid);
        report.setStatus("PENDING");
        if (report.getStoreId() == null || report.getStoreId().isBlank()) {
            report.setStoreId(stableStoreId(
                    report.getStoreName(), report.getAddress(), report.getPhoneNumber()));
        }
        validateReportTarget(report);
        report.setCreatedAt(stringOrDefault(
                existingData, "createdAt", java.time.Instant.now().toString()));
        report.setRejectReason(null);
        // 주소 좌표 변환에 실패한 수정은 기존 좌표·지역을 0이나 빈 값으로 덮지 않습니다.
        if (report.getLatitude() == 0 && report.getLongitude() == 0) {
            Double latitude = finiteNumberOrNull(existingData.get("latitude"));
            Double longitude = finiteNumberOrNull(existingData.get("longitude"));
            if (latitude != null && longitude != null) {
                report.setLatitude(latitude);
                report.setLongitude(longitude);
            }
        }
        if (report.getCityProvince() == null) report.setCityProvince(strOrNull(existingData.get("cityProvince")));
        if (report.getCityDistrict() == null) report.setCityDistrict(strOrNull(existingData.get("cityDistrict")));
        report.setImageUrls(normalizeReportImageUrls(
                reporterUid,
                report.getImageUrls(),
                Set.copyOf(existingImageUrls)));

        @SuppressWarnings("unchecked")
        Map<String, Object> data = objectMapper.convertValue(report, Map.class);
        Map<String, Object> currentTarget = getStoreById(report.getStoreId());
        if (currentTarget != null) data.put("baseRevision", StoreCorrectionPolicy.revision(currentTarget));
        data.put("appliedFields", Map.of()); data.put("previousFields", Map.of()); data.put("resolution", "");
        // 다시 검토 요청된 제보에 이전 처리 기록(처리 시각·검토 사유)이 남지 않게 비웁니다.
        data.put("processedAt", null); data.put("reviewReason", null);
        try {
            db.runTransaction(transaction -> {
                DocumentSnapshot latest = transaction.get(docRef).get();
                if (!latest.exists()) throw new NoSuchElementException("제보를 찾을 수 없습니다.");
                if (!reporterUid.equals(latest.getString("reporterId"))) throw new SecurityException("본인의 제보만 수정할 수 있습니다.");
                if ("APPROVED".equalsIgnoreCase(latest.getString("status"))) {
                    throw new IllegalStateException("검토 중 제보가 승인되었습니다. 새 변경 제보를 등록해주세요.");
                }
                transaction.update(docRef, data);
                return null;
            }).get();
        } catch (ExecutionException exception) {
            if (exception.getCause() instanceof RuntimeException failure) throw failure;
            throw exception;
        }

        Map<String, Object> mergedData = new HashMap<>(existing.getData());
        mergedData.putAll(data);
        mergedData.put("id", reportId);
        synchronized (allStoresCacheLock) {
            cachedUserStores = cachedUserStores.stream()
                    .map(item -> reportId.equals(item.get("id"))
                            && !"APPROVED".equalsIgnoreCase(strOrNull(item.get("status")))
                            ? immutableStoreCopy(mergedData) : item)
                    .toList();
            allStoresCache = null;
        }
        invalidateCommunityFeedCache();

        List<String> removedImages = existingImageUrls.stream()
                .filter(url -> !report.getImageUrls().contains(url))
                .toList();
        try {
            deleteReportImages(reporterUid, removedImages);
        } catch (Exception e) {
            log.warn("수정 후 제거된 제보 사진 정리에 실패했습니다. reportId={}", reportId, e);
        }
    }

    private void validateReportTarget(com.howmuch.dto.UserReportRequest report) {
        if (!"STORE_INFO".equalsIgnoreCase(report.getReportType()) && (report.getChangeType() == null || report.getChangeType().isBlank())) return;
        Map<String, Object> target = getStoreById(report.getStoreId());
        if (target == null || !normalizeStoreIdentityPart(report.getStoreName()).equals(normalizeStoreIdentityPart(strOrNull(target.get("storeName"))))) {
            throw new IllegalArgumentException("신고 대상 매장 정보를 다시 선택해주세요.");
        }
    }

    /** 사용자가 본인 제보를 삭제합니다. 첨부 사진 정리가 끝난 뒤 문서와 캐시를 제거합니다. */
    public Map<String, Object> deleteUserReport(
            String reportId,
            String reporterUid) throws Exception {
        if (reporterUid == null || reporterUid.isBlank()) {
            throw new SecurityException("로그인이 필요합니다.");
        }
        return deleteReport(reportId, reporterUid);
    }

    /** 관리자가 제보를 삭제합니다. 소유자 정보는 저장된 제보 문서만 신뢰합니다. */
    public Map<String, Object> deleteReportAsAdmin(String reportId) throws Exception {
        return deleteReport(reportId, null);
    }

    private Map<String, Object> deleteReport(
            String reportId,
            String expectedReporterUid) throws Exception {
        if (reportId == null || reportId.isBlank()) {
            throw new IllegalArgumentException("삭제할 제보 ID가 필요합니다.");
        }

        DocumentReference docRef = db.collection("stores_user").document(reportId);
        DocumentSnapshot existing = docRef.get().get();
        if (!existing.exists()) {
            throw new NoSuchElementException("제보를 찾을 수 없습니다.");
        }

        String ownerUid = existing.getString("reporterId");
        if (expectedReporterUid != null && !expectedReporterUid.equals(ownerUid)) {
            throw new SecurityException("본인의 제보만 삭제할 수 있습니다.");
        }

        List<String> imageUrls = stringList(existing.get("imageUrls"));
        List<String> ownedImageUrls = imageUrls.stream()
                .filter(url -> reportImageStorage.isOwnedBy(ownerUid, url))
                .toList();
        int deletedImages = ownedImageUrls.isEmpty()
                ? 0
                : reportImageStorage.deleteOwned(ownerUid, ownedImageUrls);

        int deletedComments = deleteWhere("comments", "postId", reportId);
        int deletedLikes = deleteWhere("feed_likes", "postId", reportId);
        int deletedSubscriptions = deleteWhere("feed_notifications", "postId", reportId);
        // BE-CORE-11: 제보 처리 알림(relatedReportId)과 새 댓글 알림(relatedPostId)을 함께 지웁니다.
        int deletedNotifications = deleteWhere("notifications", "relatedReportId", reportId)
                + deleteWhere("notifications", "relatedPostId", reportId);
        docRef.delete().get();
        synchronized (allStoresCacheLock) {
            cachedUserStores = cachedUserStores.stream()
                    .filter(item -> !reportId.equals(item.get("id")))
                    .toList();
            allStoresCache = null;
        }
        invalidateCommunityFeedCache();

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("id", reportId);
        result.put("deletedImages", deletedImages);
        result.put("deletedComments", deletedComments);
        result.put("deletedLikes", deletedLikes);
        result.put("deletedSubscriptions", deletedSubscriptions);
        result.put("deletedNotifications", deletedNotifications);
        return result;
    }

    public List<String> uploadReportImages(
            String reporterUid,
            List<MultipartFile> images) throws Exception {
        if (reporterUid == null || reporterUid.isBlank()) {
            throw new SecurityException("로그인이 필요합니다.");
        }
        if (images == null || images.isEmpty()) {
            return List.of();
        }
        if (images.size() > REPORT_IMAGE_MAX_COUNT) {
            throw new IllegalArgumentException("사진은 최대 3장까지 업로드할 수 있습니다.");
        }

        List<String> imageUrls = new ArrayList<>();
        try {
            for (MultipartFile image : images) {
                if (image == null || image.isEmpty()) {
                    throw new IllegalArgumentException("비어 있는 사진은 업로드할 수 없습니다.");
                }
                if (image.getSize() > REPORT_IMAGE_MAX_BYTES) {
                    throw new IllegalArgumentException("이미지 용량은 한 장당 5MB 이하여야 합니다.");
                }

                byte[] bytes = image.getBytes();
                String contentType = detectReportImageContentType(bytes);
                if (contentType == null) {
                    throw new IllegalArgumentException(
                            "JPEG, PNG, WebP 형식의 이미지 파일만 업로드할 수 있습니다.");
                }

                imageUrls.add(reportImageStorage.upload(reporterUid, bytes, contentType));
            }
            return List.copyOf(imageUrls);
        } catch (Exception e) {
            try {
                reportImageStorage.deleteOwned(reporterUid, imageUrls);
            } catch (Exception cleanupError) {
                log.warn("부분 업로드된 제보 사진 정리에 실패했습니다.", cleanupError);
            }
            throw e;
        }
    }

    /** 영수증 사진과 OCR 판독 결과를 저장합니다. 자동 승인 후보가 아니면 PENDING으로 남습니다. */
    public String saveReceiptVerification(
            String firebaseUid,
            String storeId,
            String storeName,
            String menu,
            long price,
            String receiptFingerprint,
            List<String> imageUrls,
            ReceiptOcrService.Result ocrResult) throws Exception {
        if (firebaseUid == null || firebaseUid.isBlank()) {
            throw new SecurityException("로그인이 필요합니다.");
        }
        if (imageUrls == null || imageUrls.isEmpty()) {
            throw new IllegalArgumentException("영수증 사진이 필요합니다.");
        }
        if (receiptFingerprint == null || !receiptFingerprint.matches("[a-f0-9]{64}")) {
            throw new IllegalArgumentException("영수증 이미지 식별값이 올바르지 않습니다.");
        }
        String createdAt = java.time.Instant.now().toString();
        LocalDate visitDate = receiptVisitDate(
                ocrResult == null ? null : ocrResult.detectedDate(),
                ocrResult != null && ocrResult.receiptDatePlausible(),
                createdAt);
        // 계약 C9: 같은 날 같은 매장 방문(위치 인증·다른 영수증)이 이미 있으면 접수하지 않습니다.
        if (db.collection("visits").document(dailyVisitDocumentId(firebaseUid, storeId, storeName, visitDate))
                .get().get().exists()) {
            throw new DuplicateVisitException("같은 날 이 매장의 방문 기록이 이미 있어요. 같은 방문은 한 번만 적립돼요.");
        }
        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("storeId", storeId);
        data.put("storeName", storeName);
        data.put("menu", menu);
        data.put("price", price);
        data.put("imageUrls", imageUrls);
        data.put("status", "PENDING");
        data.put("createdAt", createdAt);
        data.put("visitDate", visitDate.toString());
        if (ocrResult != null) {
            data.put("ocrProviderAvailable", ocrResult.providerAvailable());
            data.put("ocrStatus", ocrResult.status());
            data.put("ocrDetectedTextLength", ocrResult.detectedTextLength());
            data.put("ocrDetectedPrice", ocrResult.detectedPrice());
            data.put("ocrLabeledPrice", ocrResult.labeledPrice());
            data.put("ocrStoreMatch", ocrResult.storeMatch());
            data.put("ocrPriceMatch", ocrResult.priceMatch());
            data.put("ocrDetectedDate", ocrResult.detectedDate());
            data.put("ocrReceiptDatePlausible", ocrResult.receiptDatePlausible());
            data.put("ocrScore", ocrResult.score());
        }
        DocumentReference document = db.collection("receipt_verifications")
                .document("receipt_" + receiptFingerprint);
        try {
            document.create(data).get();
        } catch (ExecutionException e) {
            if (isAlreadyExists(e)) {
                throw new DuplicateReceiptException("이미 제출된 영수증입니다.");
            }
            throw e;
        }
        return document.getId();
    }

    /**
     * 영수증 방문 인증 대상 매장을 공개 목록(폐업 제외)에서 정확히 확인합니다.
     * ID가 맞지 않으면 고유한 매장명일 때만 찾고, 매장명이 다르면 찾지 못한 것으로 봅니다.
     */
    public java.util.Optional<Map<String, Object>> findVisitableStore(String storeId, String storeName) {
        String key = storeId != null && !storeId.isBlank() ? storeId : storeName;
        Map<String, Object> store = resolveReviewStore(key, getAllStores());
        if (store == null || strOrNull(store.get("storeId")) == null) return java.util.Optional.empty();
        if (storeName != null && !storeName.isBlank()
                && !normalizeStoreIdentityPart(storeName).equals(normalizeStoreIdentityPart(strOrNull(store.get("storeName"))))) {
            return java.util.Optional.empty();
        }
        return java.util.Optional.of(store);
    }

    /**
     * FE-STORE-15: 영수증 방문일은 판독된 영수증 날짜가 타당하면 그 날짜, 아니면 제출일(KST)입니다.
     * 승인 시각은 방문일에 쓰지 않습니다.
     */
    static LocalDate receiptVisitDate(String detectedDate, boolean detectedDatePlausible, String submittedAt) {
        if (detectedDatePlausible && detectedDate != null && !detectedDate.isBlank()) {
            try {
                return LocalDate.parse(detectedDate.trim());
            } catch (java.time.format.DateTimeParseException ignored) {
                // 형식이 맞지 않는 판독 날짜는 제출일로 대체합니다.
            }
        }
        java.time.Instant submitted;
        try {
            submitted = submittedAt == null ? java.time.Instant.now() : java.time.Instant.parse(submittedAt);
        } catch (java.time.format.DateTimeParseException ignored) {
            submitted = java.time.Instant.now();
        }
        return submitted.atZone(ZoneId.of("Asia/Seoul")).toLocalDate();
    }

    /** 저장된 영수증 문서의 방문일입니다. 이전에 접수된 영수증은 판독 결과와 제출 시각으로 다시 계산합니다. */
    private LocalDate receiptVisitDate(DocumentSnapshot receipt) {
        String stored = receipt.getString("visitDate");
        if (stored != null && !stored.isBlank()) {
            try {
                return LocalDate.parse(stored.trim());
            } catch (java.time.format.DateTimeParseException ignored) {
                // 아래 계산으로 대체합니다.
            }
        }
        return receiptVisitDate(receipt.getString("ocrDetectedDate"),
                Boolean.TRUE.equals(receipt.getBoolean("ocrReceiptDatePlausible")),
                receipt.getString("createdAt"));
    }

    public boolean receiptVerificationExists(String receiptFingerprint) throws Exception {
        if (receiptFingerprint == null || !receiptFingerprint.matches("[a-f0-9]{64}")) {
            return false;
        }
        return db.collection("receipt_verifications")
                .document("receipt_" + receiptFingerprint)
                .get().get().exists();
    }

    // [어드민] 영수증 인증 목록 조회. 소량 컬렉션이라 복합 인덱스 없이 필터링합니다.
    public List<Map<String, Object>> getReceiptVerifications(String status) throws Exception {
        com.google.cloud.firestore.Query query = db.collection("receipt_verifications");
        if (status != null && !status.isBlank()) {
            query = query.whereEqualTo("status", status);
        }
        return query.get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    return data;
                })
                .sorted((a, b) -> String.valueOf(b.getOrDefault("createdAt", ""))
                        .compareTo(String.valueOf(a.getOrDefault("createdAt", ""))))
                .limit(adminListLimit())
                .toList();
    }

    /** 영수증 인증 승인 시 위치 인증 없이 방문 기록을 생성합니다. */
    public Map<String, Object> approveReceiptVerification(String receiptId, String approvedBy) throws Exception {
        if (receiptId == null || receiptId.isBlank()) {
            throw new IllegalArgumentException("영수증 인증 ID가 필요합니다.");
        }
        DocumentReference docRef = db.collection("receipt_verifications").document(receiptId);
        try {
            ReceiptApprovalResult committed = db.runTransaction(transaction -> {
                DocumentSnapshot snapshot = transaction.get(docRef).get();
                if (!snapshot.exists()) {
                    throw new ReceiptVerificationNotFoundException(
                            "영수증 인증을 찾을 수 없습니다: " + receiptId);
                }
                String status = snapshot.getString("status");
                if (status != null && !"PENDING".equalsIgnoreCase(status)) {
                    throw new IllegalArgumentException("이미 처리된 영수증 인증입니다.");
                }

                if (!isManualApproval(approvedBy)) {
                    requireUsableReceiptOcrEvidence(snapshot);
                }

                String userId = snapshot.getString("userId");
                String storeName = snapshot.getString("storeName");
                Long price = snapshot.getLong("price");
                if (userId == null || userId.isBlank()
                        || storeName == null || storeName.isBlank()
                        || price == null || price < 0
                        || (price == 0 && !isApprovedFreeMenu(snapshot.getString("storeId"), storeName, snapshot.getString("menu")))) {
                    throw new IllegalArgumentException("영수증 인증 데이터가 올바르지 않습니다.");
                }

                String menu = snapshot.getString("menu");
                if (isClosedStore(snapshot.getString("storeId"), storeName)) throw new IllegalArgumentException("폐업한 매장은 방문 인증할 수 없습니다.");
                String receiptStoreId = snapshot.getString("storeId");
                Map<String, Object> canonicalStore = resolveReviewStore(
                        receiptStoreId != null && !receiptStoreId.isBlank() ? receiptStoreId : storeName,
                        getStoreCatalogEntry().stores());
                String visitStoreId = canonicalStore != null && strOrNull(canonicalStore.get("storeId")) != null
                        ? strOrNull(canonicalStore.get("storeId")) : receiptStoreId;
                // 계약 C9: 위치 방문과 같은 (회원, 정규 매장 ID, KST 방문일) 문서 ID로 만들어
                // 같은 날 같은 매장의 방문이 위치·영수증·재촬영 영수증으로 두 번 적립되지 않게 합니다.
                LocalDate visitDate = receiptVisitDate(snapshot);
                DocumentReference visitRef = db.collection("visits").document(
                        dailyVisitDocumentId(userId, visitStoreId, storeName, visitDate));
                if (transaction.get(visitRef).get().exists()) {
                    throw new DuplicateVisitException("같은 날 이 매장의 방문 기록이 이미 있어 영수증을 승인할 수 없어요.");
                }
                String industry = findIndustryByStoreName(storeName);
                long savedAmount = price == 0 ? 0L : ReferencePrices.savedAmount(
                        estimateReferencePrice(menu, industry, findAddressByStoreName(storeName)), price);
                com.howmuch.dto.VisitRequest visitRequest = com.howmuch.dto.VisitRequest.builder()
                        .storeId(visitStoreId)
                        .storeName(storeName)
                        .menu(menu)
                        .price(price)
                        .verificationMethod("RECEIPT_OCR")
                        .build();

                String processedAt = java.time.Instant.now().toString();
                // FE-STORE-15: 방문 시각은 제출 시각이고, 승인 시각은 별도 필드로 남깁니다.
                String submittedAt = snapshot.getString("createdAt");
                Map<String, Object> visitData = buildVisitData(userId, visitRequest, savedAmount,
                        submittedAt == null || submittedAt.isBlank() ? processedAt : submittedAt);
                visitData.put("visitDate", visitDate.toString());
                visitData.put("approvedAt", processedAt);
                visitData.put("receiptId", receiptId);
                transaction.create(visitRef, visitData);
                List<String> imageUrls = stringList(snapshot.get("imageUrls"));
                Map<String, Object> receiptUpdate = new HashMap<>();
                receiptUpdate.put("status", "APPROVED");
                receiptUpdate.put("approvedBy", approvedBy == null ? "AUTO_OCR" : approvedBy);
                receiptUpdate.put("approvedAt", processedAt);
                receiptUpdate.put("visitId", visitRef.getId());
                if (!imageUrls.isEmpty()) receiptUpdate.put("imageCleanupStatus", "PENDING");
                transaction.update(docRef, receiptUpdate);
                return new ReceiptApprovalResult(
                        userId, imageUrls, visitRef.getId());
            }).get();
            cleanupProcessedReceiptImages(docRef, committed.userId(), committed.imageUrls());
            return Map.of(
                    "success", true,
                    "id", receiptId,
                    "status", "APPROVED",
                    "visitId", committed.visitId());
        } catch (ExecutionException e) {
            if (e.getCause() instanceof DuplicateVisitException duplicateVisit) {
                throw duplicateVisit;
            }
            if (e.getCause() instanceof IllegalArgumentException invalidReceipt) {
                throw invalidReceipt;
            }
            throw e;
        }
    }

    public void rejectReceiptVerification(String receiptId, String reason, String rejectedBy) throws Exception {
        if (receiptId == null || receiptId.isBlank()) {
            throw new IllegalArgumentException("영수증 인증 ID가 필요합니다.");
        }
        DocumentReference docRef = db.collection("receipt_verifications").document(receiptId);
        try {
            ReceiptRejectionResult committed = db.runTransaction(transaction -> {
                DocumentSnapshot snapshot = transaction.get(docRef).get();
                if (!snapshot.exists()) {
                    throw new ReceiptVerificationNotFoundException(
                            "영수증 인증을 찾을 수 없습니다: " + receiptId);
                }
                String status = snapshot.getString("status");
                if (status != null && !"PENDING".equalsIgnoreCase(status)) {
                    throw new IllegalArgumentException("이미 처리된 영수증 인증입니다.");
                }
                List<String> imageUrls = stringList(snapshot.get("imageUrls"));
                Map<String, Object> receiptUpdate = new HashMap<>();
                receiptUpdate.put("status", "REJECTED");
                receiptUpdate.put("rejectReason", reason);
                receiptUpdate.put("rejectedBy", rejectedBy);
                receiptUpdate.put("rejectedAt", java.time.Instant.now().toString());
                if (!imageUrls.isEmpty()) receiptUpdate.put("imageCleanupStatus", "PENDING");
                transaction.update(docRef, receiptUpdate);
                return new ReceiptRejectionResult(
                        snapshot.getString("userId"), imageUrls);
            }).get();
            cleanupProcessedReceiptImages(docRef, committed.userId(), committed.imageUrls());
        } catch (ExecutionException e) {
            if (e.getCause() instanceof IllegalArgumentException invalidReceipt) {
                throw invalidReceipt;
            }
            throw e;
        }
    }

    private void requireUsableReceiptOcrEvidence(DocumentSnapshot snapshot) {
        Boolean providerAvailable = snapshot.getBoolean("ocrProviderAvailable");
        Long detectedTextLength = snapshot.getLong("ocrDetectedTextLength");
        Long detectedPrice = snapshot.getLong("ocrDetectedPrice");
        String detectedDate = snapshot.getString("ocrDetectedDate");
        if (!Boolean.TRUE.equals(providerAvailable)
                || detectedTextLength == null || detectedTextLength <= 0
                || detectedPrice == null || detectedPrice <= 0
                || detectedDate == null || detectedDate.isBlank()) {
            throw new ReceiptOcrEvidenceException(
                    "OCR 판독이 완료되지 않은 영수증은 승인할 수 없습니다. 공급자 설정을 확인한 뒤 다시 제출해주세요.");
        }
    }

    private static boolean isManualApproval(String approvedBy) {
        return "ADMIN".equalsIgnoreCase(approvedBy);
    }

    private record ReceiptApprovalResult(
            String userId, List<String> imageUrls, String visitId) { }

    private record ReceiptRejectionResult(String userId, List<String> imageUrls) { }

    private void cleanupProcessedReceiptImages(
            DocumentReference receiptRef, String ownerUid, List<String> imageUrls) {
        if (ownerUid == null || ownerUid.isBlank() || imageUrls.isEmpty()) return;
        try {
            Set<String> uniqueUrls = new LinkedHashSet<>(imageUrls);
            int deleted = reportImageStorage.deleteOwned(ownerUid, uniqueUrls);
            if (deleted < uniqueUrls.size()) {
                log.warn("처리된 영수증 이미지 일부를 정리하지 못했습니다. receiptId={}, deleted={}/{}",
                        receiptRef.getId(), deleted, uniqueUrls.size());
                recordReceiptCleanupFailure(receiptRef);
                return;
            }
            receiptRef.update(Map.of(
                    "imageUrls", List.of(),
                    "imageCleanupStatus", "DELETED",
                    "imageDeletedAt", java.time.Instant.now().toString()
            )).get();
        } catch (Exception e) {
            log.warn("처리된 영수증 이미지 정리에 실패했습니다. receiptId={}", receiptRef.getId(), e);
            recordReceiptCleanupFailure(receiptRef);
        }
    }

    /** 정리 재시도 상한. 넘으면 FAILED로 바꿔 대기열 앞을 막지 않게 합니다. */
    private static final int MAX_RECEIPT_CLEANUP_ATTEMPTS = 24;
    private static final int RECEIPT_CLEANUP_BATCH = 100;
    private volatile boolean legacyReceiptCleanupSwept = false;

    private void recordReceiptCleanupFailure(DocumentReference receiptRef) {
        try {
            DocumentSnapshot current = receiptRef.get().get();
            Long attempts = current.getLong("imageCleanupAttempts");
            long next = (attempts == null ? 0L : attempts) + 1L;
            receiptRef.update(Map.of(
                    "imageCleanupAttempts", next,
                    "imageCleanupStatus", next >= MAX_RECEIPT_CLEANUP_ATTEMPTS ? "FAILED" : "PENDING")).get();
        } catch (Exception e) {
            log.warn("영수증 이미지 정리 실패 기록을 남기지 못했습니다. receiptId={}", receiptRef.getId());
        }
    }

    /**
     * 승인·반려 직후 외부 저장소가 일시적으로 실패해 남은 영수증 원본을
     * 다음 주기에 재시도한다. 이미 삭제된 Cloudinary 리소스도 완료로
     * 취급하므로 Firestore의 imageUrls가 결국 비워진다.
     * BE-CORE-4: 정리 대기(imageCleanupStatus=PENDING) 문서만 조회해 처리된 영수증 전체를
     * 매시간 읽지 않습니다. 상태 필드가 생기기 전에 처리된 영수증은 프로세스 시작 후 한 번만 확인합니다.
     */
    @Scheduled(
            initialDelayString = "${receipt.images.cleanup.initial-delay-ms:300000}",
            fixedDelayString = "${receipt.images.cleanup.delay-ms:3600000}")
    void retryProcessedReceiptImageCleanup() {
        try {
            var pending = db.collection("receipt_verifications")
                    .whereEqualTo("imageCleanupStatus", "PENDING")
                    .limit(RECEIPT_CLEANUP_BATCH)
                    .get().get().getDocuments();
            for (DocumentSnapshot document : pending) {
                retryReceiptCleanup(document);
            }
            if (!legacyReceiptCleanupSwept) {
                var processed = db.collection("receipt_verifications")
                        .whereIn("status", List.of("APPROVED", "REJECTED"))
                        .limit(adminListLimit())
                        .get().get().getDocuments();
                for (DocumentSnapshot document : processed) {
                    if (document.getString("imageCleanupStatus") != null) continue;
                    if (stringList(document.get("imageUrls")).isEmpty()) continue;
                    retryReceiptCleanup(document);
                }
                legacyReceiptCleanupSwept = true;
            }
        } catch (IllegalStateException e) {
            log.debug("영수증 이미지 저장소가 설정되지 않아 정리 재시도를 건너뜁니다.");
        } catch (Exception e) {
            log.warn("처리된 영수증 이미지 정리 재시도 중 오류가 발생했습니다.", e);
        }
    }

    private void retryReceiptCleanup(DocumentSnapshot document) {
        List<String> imageUrls = stringList(document.get("imageUrls"));
        if (imageUrls.isEmpty()) {
            try {
                document.getReference().update(Map.of("imageCleanupStatus", "DELETED")).get();
            } catch (Exception e) {
                log.warn("빈 영수증 정리 상태를 갱신하지 못했습니다. receiptId={}", document.getId());
            }
            return;
        }
        cleanupProcessedReceiptImages(document.getReference(), document.getString("userId"), imageUrls);
    }

    private int adminListLimit() {
        return Math.max(1, Math.min(adminListMaxItems, 1000));
    }

    public int deleteReportImages(String reporterUid, List<String> imageUrls) throws Exception {
        if (reporterUid == null || reporterUid.isBlank()) {
            throw new SecurityException("로그인이 필요합니다.");
        }
        if (imageUrls == null || imageUrls.isEmpty()) return 0;
        if (imageUrls.size() > REPORT_IMAGE_MAX_COUNT) {
            throw new IllegalArgumentException("한 번에 최대 3장의 사진만 정리할 수 있습니다.");
        }
        return reportImageStorage.deleteOwned(
                reporterUid, new LinkedHashSet<>(imageUrls));
    }

    private List<String> normalizeReportImageUrls(
            String reporterUid,
            List<String> imageUrls,
            Set<String> allowedExistingUrls) {
        if (imageUrls == null || imageUrls.isEmpty()) return List.of();
        LinkedHashSet<String> uniqueUrls = new LinkedHashSet<>();
        for (String imageUrl : imageUrls) {
            if (imageUrl == null || imageUrl.isBlank()) continue;
            boolean allowedExisting = allowedExistingUrls.contains(imageUrl)
                    && (imageUrl.startsWith("http://") || imageUrl.startsWith("https://"));
            if (!allowedExisting
                    && !isOwnedReportImageUrl(reporterUid, imageUrl)) {
                throw new IllegalArgumentException("유효하지 않은 제보 이미지 URL이 포함되어 있습니다.");
            }
            uniqueUrls.add(imageUrl);
        }
        if (uniqueUrls.size() > REPORT_IMAGE_MAX_COUNT) {
            throw new IllegalArgumentException("사진은 최대 3장까지 첨부할 수 있습니다.");
        }
        return List.copyOf(uniqueUrls);
    }

    private boolean isOwnedReportImageUrl(String reporterUid, String imageUrl) {
        return reportImageStorage.isOwnedBy(reporterUid, imageUrl);
    }

    String detectReportImageContentType(byte[] bytes) {
        if (bytes == null) return null;
        if (bytes.length >= 3
                && (bytes[0] & 0xFF) == 0xFF
                && (bytes[1] & 0xFF) == 0xD8
                && (bytes[2] & 0xFF) == 0xFF) {
            return "image/jpeg";
        }
        if (bytes.length >= 8
                && (bytes[0] & 0xFF) == 0x89
                && bytes[1] == 0x50
                && bytes[2] == 0x4E
                && bytes[3] == 0x47
                && bytes[4] == 0x0D
                && bytes[5] == 0x0A
                && bytes[6] == 0x1A
                && bytes[7] == 0x0A) {
            return "image/png";
        }
        if (bytes.length >= 12
                && bytes[0] == 0x52
                && bytes[1] == 0x49
                && bytes[2] == 0x46
                && bytes[3] == 0x46
                && bytes[8] == 0x57
                && bytes[9] == 0x45
                && bytes[10] == 0x42
                && bytes[11] == 0x50) {
            return "image/webp";
        }
        return null;
    }

    private List<String> stringList(Object value) {
        if (!(value instanceof List<?> list)) return List.of();
        return list.stream()
                .filter(item -> item != null && !item.toString().isBlank())
                .map(Object::toString)
                .toList();
    }

    // 💡 사용자의 제보 목록 조회 (내 제보 현황은 실시간성이 중요하므로 Firestore 유지, 소량).
    // 계약 C4: 복합 인덱스 없이 메모리에서 createdAt 내림차순(최신순)으로 정렬합니다.
    public List<Map<String, Object>> getUserReports(String firebaseUid) throws Exception {
        return db.collection("stores_user")
                .whereEqualTo("reporterId", firebaseUid)
                .get().get().getDocuments().stream()
                .map(doc -> UserReportResponsePolicy.ownerView(doc.getId(), doc.getData()))
                .sorted(Comparator.comparing(
                        (Map<String, Object> report) -> report.get("createdAt") == null
                                ? "" : report.get("createdAt").toString(),
                        Comparator.reverseOrder()))
                .toList();
    }

    // 💡 [어드민] 제보 목록 조회 (status가 null이면 전체, 아니면 PENDING/APPROVED/REJECTED 필터, 최신순)
    public List<Map<String, Object>> getAllReports(String status) throws Exception {
        com.google.cloud.firestore.Query query = db.collection("stores_user");
        if (status != null && !status.isBlank()) {
            query = query.whereEqualTo("status", status);
        }
        return query.get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    Map<String, Object> currentStore = getStoreById(strOrNull(data.get("storeId")));
                    if (currentStore != null) data.put("currentStore", currentStore);
                    return data;
                })
                .sorted((a, b) -> String.valueOf(b.getOrDefault("createdAt", ""))
                        .compareTo(String.valueOf(a.getOrDefault("createdAt", ""))))
                .limit(adminListLimit())
                .toList();
    }

    /** Correct a report classification without changing its review status. */
    public void updateReportIndustryAsAdmin(String reportId, String industry) throws Exception {
        DocumentReference document = db.collection("stores_user").document(reportId);
        if (!document.get().get().exists()) throw new NoSuchElementException("제보를 찾을 수 없습니다.");
        document.update("industry", industry).get();
        updateReportCache(reportId, Map.of("industry", industry));
    }

    // 💡 [어드민] 제보 승인 — status를 APPROVED로 변경 (승인 매장의 공식 stores 반영은 별도 작업)
    public void approveReport(String reportId) throws Exception {
        approveReport(reportId, null);
    }

    public void approveReport(String reportId, com.howmuch.dto.ReportApprovalRequest approval) throws Exception {
        DocumentReference reportRef = db.collection("stores_user").document(reportId);
        ApprovalCommit committed;
        try {
            committed = db.runTransaction(transaction -> {
                DocumentSnapshot snapshot = transaction.get(reportRef).get();
                if (!snapshot.exists()) throw new NoSuchElementException("제보를 찾을 수 없습니다.");
                Map<String, Object> report = new HashMap<>(snapshot.getData());
                String status = snapshot.getString("status");
                if (status != null && !status.isBlank() && !"PENDING".equalsIgnoreCase(status)) {
                    throw new IllegalStateException("이미 처리된 제보입니다.");
                }
                boolean correctionReport = StoreCorrectionPolicy.informationReport(report) || StoreCorrectionPolicy.priceReport(report);
                Map<String, Object> correction = null;
                Map<String, Object> updates = new HashMap<>();
                String processedAt = java.time.Instant.now().toString();
                updates.put("status", "APPROVED"); updates.put("processedAt", processedAt);
                String storeId = strOrNull(report.get("storeId"));
                if (correctionReport) {
                    Map<String, Object> base = findOriginalStore(storeId);
                    if (base == null) throw new IllegalArgumentException("신고 대상 매장을 찾을 수 없습니다.");
                    DocumentReference correctionRef = db.collection(STORE_CORRECTIONS_COLLECTION).document(storeId);
                    DocumentSnapshot correctionSnapshot = transaction.get(correctionRef).get();
                    Map<String, Object> previous = correctionSnapshot.exists() ? correctionSnapshot.getData() : null;
                    Map<String, Object> current = applyStoreCorrection(base, previous);
                    long reportRevision = report.get("baseRevision") instanceof Number revision ? revision.longValue() : 0L;
                    if (!StoreCorrectionPolicy.informationReport(report)
                            && reportRevision != StoreCorrectionPolicy.revision(current)) {
                        throw new IllegalStateException("제보 후 매장 정보가 변경되었습니다. 새 정보를 확인한 뒤 다시 검토해주세요.");
                    }
                    StoreCorrectionPolicy.Decision decision = StoreCorrectionPolicy.decide(report, current, approval);
                    updates.put("resolution", decision.resolution()); updates.put("reviewReason", decision.reason());
                    updates.put("appliedFields", decision.fields());
                    updates.put("previousFields", correctionPreviousFields(current, decision.fields()));
                    if (!decision.fields().isEmpty()) {
                        correction = previous == null ? new HashMap<>() : new HashMap<>(previous);
                        Map<String, Object> fields = new HashMap<>();
                        if (correction.get("fields") instanceof Map<?, ?> oldFields) {
                            oldFields.forEach((key, value) -> fields.put(String.valueOf(key), value));
                        }
                        fields.putAll(decision.fields());
                        correction.put("fields", fields);
                        correction.put("revision", StoreCorrectionPolicy.revision(current) + 1);
                        correction.put("updatedAt", processedAt);
                        correction.put("lastReportId", reportId);
                        transaction.set(correctionRef, correction);
                    }
                } else {
                    StoreCorrectionPolicy.validateNewStorePrices(report);
                    updates.put("resolution", "NEW_STORE");
                }
                transaction.update(reportRef, updates);
                return new ApprovalCommit(storeId, correction, updates, strOrNull(report.get("storeName")),
                        strOrNull(report.get("changeType")), strOrNull(report.get("reporterId")));
            }).get();
        } catch (ExecutionException exception) {
            if (exception.getCause() instanceof RuntimeException failure) throw failure;
            throw exception;
        }
        if (committed.correction() != null) {
            synchronized (allStoresCacheLock) {
                Map<String, Map<String, Object>> corrections = new HashMap<>(cachedStoreCorrections);
                Map<String, Object> prior = corrections.get(committed.storeId());
                long priorRevision = correctionRevision(prior);
                if (correctionRevision(committed.correction()) >= priorRevision) {
                    corrections.put(committed.storeId(), immutableStoreCopy(committed.correction()));
                }
                cachedStoreCorrections = Map.copyOf(corrections);
            }
        }
        updateReportCache(reportId, committed.updates());
        notifyReporterOfReview(reportId, committed.reporterId(), committed.storeId(), committed.storeName(),
                true, strOrNull(committed.updates().get("resolution")), null,
                strOrNull(committed.updates().get("processedAt")));
        if ("PRICE".equals(committed.updates().get("resolution"))) {
            // BE-CORE-17: 알림 방향은 제보 유형 대신 실제 반영 전후 금액으로 정합니다. 변경이 없으면 보내지 않습니다.
            String direction = priceChangeDirection(
                    committed.updates().get("previousFields"), committed.updates().get("appliedFields"));
            if (direction != null) {
                try { notifyUsersOnPriceReportApproved(committed.storeName(), committed.storeId(), reportId, direction); }
                catch (Exception exception) { log.warn("가격 반영 후 알림을 보내지 못했습니다: {}", reportId); }
            }
        }
    }

    private record ApprovalCommit(String storeId, Map<String, Object> correction, Map<String, Object> updates,
                                  String storeName, String changeType, String reporterId) {}

    /**
     * 승인으로 바뀐 메뉴 칸의 전후 값을 비교해 가격 알림 방향(rise·drop·new·delete·change)을 돌려줍니다.
     * 반영된 변화가 없으면 null입니다. change는 복수 가격처럼 방향을 정할 수 없는 변경입니다.
     */
    static String priceChangeDirection(Object previousValue, Object appliedValue) {
        if (!(previousValue instanceof Map<?, ?> previous) || !(appliedValue instanceof Map<?, ?> applied)) return null;
        for (int slot = 1; slot <= 4; slot++) {
            String menuKey = "menu" + slot;
            String priceKey = "price" + slot;
            String freeKey = "free" + slot;
            if (!applied.containsKey(menuKey) && !applied.containsKey(priceKey) && !applied.containsKey(freeKey)) continue;
            String beforeMenu = blankToNull(previous.get(menuKey));
            String afterMenu = blankToNull(applied.containsKey(menuKey) ? applied.get(menuKey) : previous.get(menuKey));
            if (beforeMenu == null && afterMenu == null) continue;
            if (beforeMenu == null) return "new";
            if (afterMenu == null) return "delete";
            if (!beforeMenu.equals(afterMenu)) return "new";
            Object beforePriceRaw = previous.get(priceKey);
            Object afterPriceRaw = applied.containsKey(priceKey) ? applied.get(priceKey) : beforePriceRaw;
            var beforePrice = WonPrice.parse(beforePriceRaw);
            var afterPrice = WonPrice.parse(afterPriceRaw);
            if (beforePrice.isPresent() && afterPrice.isPresent()
                    && beforePrice.get().exact() && afterPrice.get().exact()) {
                long delta = afterPrice.get().minimum() - beforePrice.get().minimum();
                if (delta > 0) return "rise";
                if (delta < 0) return "drop";
                continue;
            }
            if (!java.util.Objects.equals(blankToNull(beforePriceRaw), blankToNull(afterPriceRaw))) return "change";
        }
        return null;
    }

    /**
     * 계약 C3: 제보 승인·반려를 제보자 알림함에 남기고 '제보 상태' 토글에 따라 푸시합니다.
     * (제보, 처리 결과, 처리 시각)으로 정한 문서 ID라 같은 처리에 알림이 두 번 생기지 않습니다.
     * 알림 실패는 이미 끝난 승인·반려를 되돌리지 않습니다.
     */
    private void notifyReporterOfReview(String reportId, String reporterId, String storeId, String storeName,
                                        boolean approved, String resolution, String rejectReason, String processedAt) {
        if (reporterId == null || reporterId.isBlank()) return;
        String type = approved ? "REPORT_APPROVED" : "REPORT_REJECTED";
        String name = storeName == null || storeName.isBlank() ? "매장" : "'" + storeName + "'";
        String title = approved ? "제보가 승인됐어요" : "제보가 반려됐어요";
        String body;
        if (!approved) {
            String reason = rejectReason == null ? "" : rejectReason.trim();
            if (reason.length() > 120) reason = reason.substring(0, 120) + "…";
            body = name + " 제보가 반려됐어요." + (reason.isEmpty() ? "" : " 사유: " + reason);
        } else if ("NEW_STORE".equals(resolution)) {
            body = name + " 제보가 승인되어 지도에 등록됐어요.";
        } else if ("NO_CHANGE".equals(resolution)) {
            body = name + " 제보를 확인했어요. 현재 정보가 맞아 변경 없이 처리했어요.";
        } else {
            body = name + " 제보가 승인되어 매장 정보에 반영됐어요.";
        }
        String reviewedAt = processedAt == null || processedAt.isBlank() ? java.time.Instant.now().toString() : processedAt;
        String notificationId = "report_" + (approved ? "approved_" : "rejected_")
                + sanitizeForDocId(reportId) + "_" + sha256Hex(reviewedAt).substring(0, 16);
        Map<String, Object> data = new HashMap<>();
        data.put("userId", reporterId);
        data.put("title", title);
        data.put("body", body);
        data.put("type", type);
        data.put("isRead", false);
        data.put("createdAt", reviewedAt);
        data.put("relatedReportId", reportId);
        data.put("storeId", storeId);
        try {
            db.collection("notifications").document(notificationId).create(data).get();
        } catch (Exception exception) {
            if (!isAlreadyExists(exception)) {
                log.warn("제보 처리 알림을 저장하지 못했습니다: reportId={}", reportId);
            }
            return;
        }
        dispatchPushNotification(reporterId, notificationId, title, body, type);
    }

    private static long correctionRevision(Map<String, Object> correction) {
        return correction != null && correction.get("revision") instanceof Number revision ? revision.longValue() : 0L;
    }

    private Map<String, Object> correctionPreviousFields(Map<String, Object> current, Map<String, Object> changes) {
        Map<String, Object> previous = new HashMap<>();
        for (String key : changes.keySet()) previous.put(key, current.getOrDefault(key, ""));
        return previous;
    }

    private Map<String, Object> findOriginalStore(String storeId) {
        for (Map<String, Object> raw : cachedStores) {
            Map<String, Object> store = withStableStoreId(raw);
            if (java.util.Objects.equals(storeId, store.get("storeId"))) { store.put("source", "GOV"); return store; }
        }
        for (Map<String, Object> raw : cachedUserStores) {
            if (!isPubliclyVisible(raw)) continue;
            Map<String, Object> store = withStableStoreId(raw);
            if (java.util.Objects.equals(storeId, store.get("storeId"))) { store.put("source", "USER"); return store; }
        }
        return null;
    }

    private void updateReportCache(String reportId, Map<String, Object> updates) {
        synchronized (allStoresCacheLock) {
            cachedUserStores = cachedUserStores.stream().map(item -> {
                if (!reportId.equals(item.get("id"))) return item;
                Map<String, Object> updated = new HashMap<>(item); updated.putAll(updates);
                return immutableStoreCopy(updated);
            }).toList();
            allStoresCache = null;
        }
        invalidateCommunityFeedCache();
    }

    // 💡 [어드민] 제보 반려 — status를 REJECTED로 변경 + 반려 사유 저장
    public void rejectReport(String reportId, String reason) throws Exception {
        updateReportStatus(reportId, "REJECTED", reason);
    }

    private void updateReportStatus(String reportId, String status, String rejectReason) throws Exception {
        DocumentReference docRef = db.collection("stores_user").document(reportId);
        Map<String, Object> updates = new HashMap<>();
        updates.put("status", status);
        String processedAt = java.time.Instant.now().toString();
        updates.put("processedAt", processedAt);
        if (rejectReason != null) {
            updates.put("rejectReason", rejectReason);
        }
        ReportStatusUpdate committed;
        try {
            committed = db.runTransaction(transaction -> {
                DocumentSnapshot snapshot = transaction.get(docRef).get();
                if (!snapshot.exists()) {
                    throw new IllegalArgumentException("제보를 찾을 수 없습니다: " + reportId);
                }
                String currentStatus = snapshot.getString("status");
                if (currentStatus != null && !"PENDING".equalsIgnoreCase(currentStatus)) {
                    throw new IllegalStateException("이미 처리된 제보입니다.");
                }
                transaction.update(docRef, updates);
                return new ReportStatusUpdate(
                        snapshot.getString("storeName"),
                        snapshot.getString("storeId"),
                        snapshot.getString("reporterId"));
            }).get();
        } catch (ExecutionException e) {
            if (e.getCause() instanceof RuntimeException reportFailure) {
                throw reportFailure;
            }
            throw e;
        }

        updateReportCache(reportId, updates);
        // 승인은 approveReport가 처리하므로 여기서는 반려만 다룹니다(BE-CORE-13: 쓰이지 않던 승인 분기 제거).
        if ("REJECTED".equals(status)) {
            notifyReporterOfReview(reportId, committed.reporterId(), committed.storeId(), committed.storeName(),
                    false, null, rejectReason, processedAt);
        }
    }

    private record ReportStatusUpdate(String storeName, String storeId, String reporterId) { }

    // 💡 매장 가격 변동 제보 승인 시 알림 생성 및 발송
    private void notifyUsersOnPriceReportApproved(
            String storeName,
            String storeId,
            String reportId,
            String changeType) throws Exception {
        // 1. 해당 매장을 찜한 사용자 목록 조회 (favorites 컬렉션 활용)
        var favoriteDocs = db.collection("favorites")
                .whereEqualTo("storeName", storeName)
                .get().get().getDocuments();

        List<Map<String, Object>> catalog = getAllStores();
        String targetId = storeId;
        if (targetId == null || targetId.isBlank() || !targetId.startsWith("store_")) {
            Map<String, Object> target = resolveReviewStore(storeName, catalog);
            if (target == null) return; // 이름만 있는 동명이점 제보는 지점을 추측하지 않습니다.
            targetId = strOrNull(target.get("storeId"));
        }
        String createdAt = java.time.Instant.now().toString();

        for (DocumentSnapshot favDoc : favoriteDocs) {
            String userId = favDoc.getString("userId");
            if (userId == null) continue;

            if (!matchesPriceAlertStore(favDoc.getData(), targetId, catalog)) continue;

            // 매장별 구독을 끈 사용자는 전체 가격 알림 설정이 켜져 있어도 제외합니다.
            if (!booleanOrDefault(favDoc.getData(), "priceAlertEnabled", true)) {
                continue;
            }

            // 2. 비활성화 사용자는 발송 대상에서 제외 (알림 설정 체크)
            NotificationSettingsDto settings = getNotificationSettings(userId);
            if (!Boolean.TRUE.equals(settings.getPrice())) {
                continue;
            }
            if (!shouldNotifyPriceChange(settings, changeType)) {
                continue;
            }

            // 3. 중복 알림 방지 (같은 제보로 이미 알림이 생성되었는지 확인)
            String docId = "price_alert_" + reportId + "_" + userId;
            DocumentReference notifRef = db.collection("notifications").document(docId);
            if (notifRef.get().get().exists()) {
                continue; // 이미 발송된 경우 스킵
            }

            // 4. 알림 생성 및 저장
            Map<String, Object> data = new HashMap<>();
            data.put("userId", userId);
            data.put("title", "관심 매장 가격 변동");
            data.put("body", "찜하신 '" + storeName + "' 매장의 가격 변동 제보가 승인되었습니다!");
            data.put("type", "PRICE_ALERT");
            data.put("isRead", false);
            data.put("createdAt", createdAt);
            data.put("relatedReportId", reportId);
            data.put("storeId", targetId);

            notifRef.set(data).get();

            // 5. 푸시 알림 발송 (기존 구조 재사용)
            dispatchPushNotification(userId, docId, (String) data.get("title"), (String) data.get("body"), "PRICE_ALERT");
        }
    }

    boolean matchesPriceAlertStore(Map<String, Object> favorite, String targetId,
                                   List<Map<String, Object>> catalog) {
        if (favorite == null || targetId == null) return false;
        String id = strOrNull(favorite.get("storeId"));
        if (id != null && id.startsWith("store_")) return targetId.equals(id);
        List<Map<String, Object>> matches = reviewStoresNamed(
                strOrNull(favorite.get("storeName")), catalog);
        String address = strOrNull(favorite.get("address"));
        if (address != null && !address.isBlank()) {
            matches = matches.stream().filter(store -> normalizeStoreIdentityPart(address)
                    .equals(normalizeStoreIdentityPart(strOrNull(store.get("address"))))).toList();
        }
        return matches.size() == 1 && targetId.equals(matches.getFirst().get("storeId"));
    }

    /**
     * 사용자의 가격 알림 조건을 적용합니다. 방향은 승인 전후 금액으로 계산한 값입니다.
     * 메뉴가 빠지거나 방향을 정할 수 없는 변경은 인상·인하 알림 중 하나라도 켠 사용자에게만 보냅니다.
     */
    private boolean shouldNotifyPriceChange(NotificationSettingsDto settings, String changeType) {
        if (changeType == null || changeType.isBlank()) {
            return false;
        }
        return switch (changeType.toLowerCase(java.util.Locale.ROOT)) {
            case "rise" -> Boolean.TRUE.equals(settings.getNotifyOnRise());
            case "drop" -> Boolean.TRUE.equals(settings.getNotifyOnDrop());
            case "new", "new_menu" -> Boolean.TRUE.equals(settings.getNotifyOnNewMenu());
            case "delete", "change" -> Boolean.TRUE.equals(settings.getNotifyOnRise())
                    || Boolean.TRUE.equals(settings.getNotifyOnDrop());
            default -> false;
        };
    }

    // 💡 [어드민] 컬렉션 문서 수 (count 집계 쿼리 — 최대 1000건당 읽기 1회라 쿼터 부담 적음)
    private long countCollection(String name) throws Exception {
        return db.collection(name).count().get().get().getCount();
    }

    // 💡 [어드민] 대시보드 개요 지표 (매장 수는 인메모리 캐시 사용 — Firestore 읽기 0)
    public Map<String, Object> getAdminOverview() throws Exception {
        long pending = 0, approved = 0, rejected = 0, legacy = 0;
        for (Map<String, Object> store : cachedUserStores) {
            switch (String.valueOf(store.getOrDefault("status", ""))) {
                case "PENDING" -> pending++;
                case "APPROVED" -> approved++;
                case "REJECTED" -> rejected++;
                default -> legacy++;
            }
        }
        Map<String, Object> userStores = new HashMap<>();
        userStores.put("pending", pending);
        userStores.put("approved", approved);
        userStores.put("rejected", rejected);
        userStores.put("legacy", legacy);
        userStores.put("total", cachedUserStores.size());

        Map<String, Object> overview = new HashMap<>();
        overview.put("users", countCollection("users"));
        overview.put("reviews", countCollection("reviews"));
        overview.put("visits", countCollection("visits"));
        overview.put("favorites", countCollection("favorites"));
        overview.put("govStores", cachedStores.size());
        overview.put("userStores", userStores);
        return overview;
    }

    // 💡 회원 삭제 — 승인 제보는 익명화해 공공 데이터로 보존하고, 나머지 개인 데이터는 삭제
    public Map<String, Object> deleteUser(String firebaseUid) throws Exception {
        Map<String, Object> result = new HashMap<>();
        // Keep ownership and receipt/report references until external deletion
        // succeeds. A failure must not acknowledge withdrawal or orphan images.
        result.put("reportImages", reportImageStorage.deleteAllOwned(firebaseUid));
        // 연관 컬렉션을 먼저 지워 중간 실패 시 계정을 남겨 재시도할 수 있게 합니다.
        result.put("reviews", deleteWhere("reviews", "authorUid", firebaseUid));
        ReportDeletionSummary reports = deleteReportsByUser(firebaseUid);
        result.put("reports", reports.deleted());
        result.put("anonymizedReports", reports.anonymized());
        result.put("visits", deleteWhere("visits", "userId", firebaseUid));
        result.put("receiptVerifications",
                deleteWhere("receipt_verifications", "userId", firebaseUid));
        result.put("favorites", deleteWhere("favorites", "userId", firebaseUid));
        result.put("inquiries", deleteWhere("inquiries", "userId", firebaseUid));
        // BE-CORE-3·WEB-ADM-9: 탈퇴자 댓글·좋아요가 있던 다른 글의 카운터를 다시 세고,
        // 탈퇴자 댓글에 달린 답글(부모가 사라져 볼 수 없는 고아 답글)도 함께 지웁니다.
        CommunityDeletion community = deleteCommunityActivity(firebaseUid, reports.deletedIds());
        result.put("comments", community.comments());
        result.put("orphanReplies", community.orphanReplies());
        result.put("feedLikes", community.likes());
        result.put("feedSubscriptions", deleteWhere("feed_notifications", "userId", firebaseUid));
        result.put("notifications", deleteWhere("notifications", "userId", firebaseUid));
        result.put("deviceTokens", deleteWhere("device_tokens", "userId", firebaseUid));
        db.collection("notification_settings").document(firebaseUid).delete().get();
        // BE-CORE-12: 같은 잠금 안에서 최신 캐시를 기준으로 바꿔 그 사이에 들어온 다른 제보를 잃지 않습니다.
        synchronized (allStoresCacheLock) {
            cachedUserStores = cachedUserStores.stream()
                    .filter(item -> !firebaseUid.equals(item.get("reporterId"))
                            || "APPROVED".equalsIgnoreCase(String.valueOf(item.get("status"))))
                    .map(item -> firebaseUid.equals(item.get("reporterId"))
                            ? immutableStoreCopy(anonymizeReportData(item))
                            : item)
                    .toList();
            allStoresCache = null;
        }
        db.collection("users").document(firebaseUid).delete().get();
        invalidateCommunityFeedCache();
        result.put("uid", firebaseUid);
        return result;
    }

    private record CommunityDeletion(int comments, int orphanReplies, int likes) { }

    private CommunityDeletion deleteCommunityActivity(String firebaseUid, Set<String> deletedPostIds) throws Exception {
        Set<String> affectedPosts = new LinkedHashSet<>();
        Set<String> affectedParents = new LinkedHashSet<>();
        Set<String> deletedCommentIds = new LinkedHashSet<>();
        int comments = 0;
        int orphanReplies = 0;
        for (DocumentSnapshot comment : db.collection("comments")
                .whereEqualTo("userId", firebaseUid).get().get().getDocuments()) {
            String postId = strOrNull(comment.get("postId"));
            String parentId = strOrNull(comment.get("parentId"));
            if (postId != null) affectedPosts.add(postId);
            if (parentId != null) {
                affectedParents.add(parentId);
            } else {
                for (DocumentSnapshot reply : db.collection("comments")
                        .whereEqualTo("parentId", comment.getId()).get().get().getDocuments()) {
                    if (firebaseUid.equals(strOrNull(reply.get("userId")))) continue; // 본인 답글은 이 반복에서 지웁니다.
                    reply.getReference().delete().get();
                    deletedCommentIds.add(reply.getId());
                    orphanReplies++;
                }
            }
            comment.getReference().delete().get();
            deletedCommentIds.add(comment.getId());
            comments++;
        }
        affectedParents.removeAll(deletedCommentIds);
        for (String parentId : affectedParents) recountReplies(parentId);

        int likes = 0;
        for (DocumentSnapshot like : db.collection("feed_likes")
                .whereEqualTo("userId", firebaseUid).get().get().getDocuments()) {
            String postId = strOrNull(like.get("postId"));
            if (postId != null) affectedPosts.add(postId);
            like.getReference().delete().get();
            likes++;
        }
        affectedPosts.removeAll(deletedPostIds);
        for (String postId : affectedPosts) syncFeedCounts(postId);
        deleteCommentNotifications(deletedCommentIds);
        return new CommunityDeletion(comments, orphanReplies, likes);
    }

    /** 부모 댓글의 답글 수를 실제 답글 개수로 다시 저장합니다. 부모가 없으면 건너뜁니다. */
    private void recountReplies(String parentId) {
        try {
            long count = db.collection("comments").whereEqualTo("parentId", parentId)
                    .count().get().get().getCount();
            db.collection("comments").document(parentId).update("replyCount", count).get();
        } catch (Exception e) {
            log.warn("답글 수를 다시 세지 못했습니다: commentId={}", parentId);
        }
    }

    /** BE-CORE-11: 지워진 댓글·답글을 가리키는 새 댓글 알림을 함께 지웁니다(in 조건은 30개씩). */
    private int deleteCommentNotifications(java.util.Collection<String> commentIds) {
        if (commentIds == null || commentIds.isEmpty()) return 0;
        List<String> ids = new ArrayList<>(commentIds);
        int deleted = 0;
        for (int start = 0; start < ids.size(); start += 30) {
            List<String> chunk = ids.subList(start, Math.min(ids.size(), start + 30));
            try {
                for (DocumentSnapshot notification : db.collection("notifications")
                        .whereIn("relatedCommentId", new ArrayList<>(chunk)).get().get().getDocuments()) {
                    notification.getReference().delete().get();
                    deleted++;
                }
            } catch (Exception e) {
                log.warn("삭제된 댓글의 알림을 정리하지 못했습니다: {}건", chunk.size());
            }
        }
        return deleted;
    }

    private ReportDeletionSummary deleteReportsByUser(String firebaseUid) throws Exception {
        var reports = db.collection("stores_user")
                .whereEqualTo("reporterId", firebaseUid)
                .get().get().getDocuments();
        int deleted = 0;
        int anonymized = 0;
        Set<String> deletedIds = new LinkedHashSet<>();
        for (DocumentSnapshot report : reports) {
            String reportId = report.getId();
            if ("APPROVED".equalsIgnoreCase(report.getString("status"))) {
                report.getReference().update(anonymizedReportFields()).get();
                anonymized++;
                continue;
            }
            deleteWhere("comments", "postId", reportId);
            deleteWhere("feed_likes", "postId", reportId);
            deleteWhere("feed_notifications", "postId", reportId);
            deleteWhere("notifications", "relatedReportId", reportId);
            deleteWhere("notifications", "relatedPostId", reportId);
            report.getReference().delete().get();
            deletedIds.add(reportId);
            deleted++;
        }
        return new ReportDeletionSummary(deleted, anonymized, deletedIds);
    }

    private static Map<String, Object> anonymizedReportFields() {
        return Map.of(
                "reporterId", "",
                "imageUrls", List.of(),
                "anonymizedAt", java.time.Instant.now().toString());
    }

    private static Map<String, Object> anonymizeReportData(Map<String, Object> source) {
        Map<String, Object> anonymized = new HashMap<>(source);
        anonymized.put("reporterId", "");
        anonymized.put("imageUrls", List.of());
        anonymized.put("anonymizedAt", java.time.Instant.now().toString());
        return anonymized;
    }

    private record ReportDeletionSummary(int deleted, int anonymized, Set<String> deletedIds) { }

    /** 컬렉션에서 field == value 인 문서 전부 삭제하고 삭제 건수 반환 */
    private int deleteWhere(String collection, String field, String value) throws Exception {
        var docs = db.collection(collection).whereEqualTo(field, value).get().get().getDocuments();
        int deleted = 0;
        for (DocumentSnapshot doc : docs) {
            doc.getReference().delete().get();
            deleted++;
        }
        return deleted;
    }

    // 💡 [어드민] 회원별 활동 요약 — 제보/리뷰/방문/찜 개수 (회원 목록 확장용)
    public Map<String, Object> getUserActivity(String firebaseUid) throws Exception {
        Map<String, Object> activity = new HashMap<>();
        activity.put("uid", firebaseUid);
        activity.put("reports", countWhere("stores_user", "reporterId", firebaseUid));
        activity.put("reviews", countWhere("reviews", "authorUid", firebaseUid));
        activity.put("visits", countWhere("visits", "userId", firebaseUid));
        activity.put("favorites", countWhere("favorites", "userId", firebaseUid));
        return activity;
    }

    /** 컬렉션에서 field == value 인 문서 수 (count 집계 쿼리 — 읽기 절약) */
    private long countWhere(String collection, String field, String value) throws Exception {
        return db.collection(collection).whereEqualTo(field, value)
                .count().get().get().getCount();
    }

    // 💡 [어드민] 회원 목록 조회 (가입 최신순, 소량 컬렉션)
    public List<Map<String, Object>> getAllUsers() throws Exception {
        // WEB-ADM-18: createdAt 정렬 쿼리는 그 필드가 없는 회원(예: 프로필 저장 전 목표만 저장)을 빼므로
        // 회원 문서를 읽은 뒤 메모리에서 최신순(가입일 없는 회원은 끝)으로 정렬합니다.
        return db.collection("users")
                .limit(MAX_ADMIN_USER_SCAN).get().get().getDocuments().stream()
                .sorted(Comparator.comparing(
                        (DocumentSnapshot doc) -> doc.getData() == null || doc.getData().get("createdAt") == null
                                ? "" : doc.getData().get("createdAt").toString(),
                        Comparator.reverseOrder()))
                .limit(adminListLimit())
                .map(doc -> {
                    Map<String, Object> source = doc.getData() == null ? Map.of() : doc.getData();
                    Map<String, Object> user = new HashMap<>();
                    user.put("id", doc.getId());
                    // 관리자 UI에 필요한 필드만 명시적으로 노출한다. 이후 users 문서에
                    // 민감한 내부 필드가 추가돼도 목록 API를 통해 자동 유출되지 않는다.
                    for (String field : List.of(
                            "nickname", "email", "region", "favoriteCategories",
                            "savingsGoalAmount", "createdAt")) {
                        if (source.containsKey(field)) {
                            user.put(field, source.get(field));
                        }
                    }
                    return user;
                })
                .toList();
    }

    /** 관리자 회원 목록이 한 번에 읽는 회원 문서 상한(정렬을 메모리에서 하므로 읽기량을 묶어 둡니다). */
    private static final int MAX_ADMIN_USER_SCAN = 5000;

    // 💡 매장명으로 업종 조회 (공공데이터 인메모리 캐시 사용 — Firestore 읽기 0)
    public String findIndustryByStoreName(String storeName) {
        if (storeName == null || storeName.isBlank()) return null;
        Map<String, Object> store = resolveReviewStore(storeName, getAllStores());
        return store == null ? null : strOrNull(store.get("industry"));
    }

    public String findAddressByStoreName(String storeName) {
        if (storeName == null || storeName.isBlank()) return null;
        Map<String, Object> store = resolveReviewStore(storeName, getAllStores());
        return store == null ? null : strOrNull(store.get("address"));
    }

    // 💡 방문 기록 저장 (절약 금액은 VisitController에서 서버 룰로 계산되어 주입됨)
    public String saveVisit(String firebaseUid, com.howmuch.dto.VisitRequest request, long savedAmount) throws Exception {
        if (isClosedStore(request.getStoreId(), request.getStoreName())) throw new IllegalArgumentException("폐업한 매장은 방문 인증할 수 없습니다.");
        if (request.getPrice() != null && request.getPrice() == 0
                && !isApprovedFreeMenu(request.getStoreId(), request.getStoreName(), request.getMenu())) {
            throw new IllegalArgumentException("승인된 무료 메뉴만 0원 방문 인증할 수 있습니다.");
        }
        boolean locationVerification = "LOCATION".equalsIgnoreCase(request.getVerificationMethod());
        DocumentReference docRef = locationVerification
                ? db.collection("visits").document(locationVisitDocumentId(
                        firebaseUid, request, LocalDate.now(ZoneId.of("Asia/Seoul"))))
                : db.collection("visits").document();
        Map<String, Object> data = buildVisitData(
                firebaseUid, request, savedAmount, java.time.Instant.now().toString());
        try {
            if (locationVerification) {
                docRef.create(data).get();
            } else {
                docRef.set(data).get();
            }
        } catch (ExecutionException e) {
            if (locationVerification && isAlreadyExists(e)) {
                throw new DuplicateVisitException("오늘 이미 이 매장의 방문 인증을 완료했습니다.");
            }
            throw e;
        }
        return docRef.getId();
    }

    String locationVisitDocumentId(
            String firebaseUid, com.howmuch.dto.VisitRequest request, LocalDate date) {
        String storeKey = request.getStoreId() != null && !request.getStoreId().isBlank()
                ? request.getStoreId().trim()
                : String.valueOf(request.getStoreName()).trim().toLowerCase(java.util.Locale.ROOT);
        return "location_" + sha256Hex(firebaseUid + "|" + storeKey + "|" + date);
    }

    /**
     * 위치 방문과 같은 체계의 하루 1회 방문 문서 ID입니다. 매장은 공개 목록의 정규 ID로 맞춰
     * 이름·옛 ID로 들어온 영수증도 같은 매장의 위치 방문과 같은 ID가 되게 합니다.
     */
    String dailyVisitDocumentId(String firebaseUid, String storeId, String storeName, LocalDate date) {
        String key = storeId != null && !storeId.isBlank() ? storeId : storeName;
        Map<String, Object> canonical = resolveReviewStore(key, getStoreCatalogEntry().stores());
        String canonicalId = canonical == null ? null : strOrNull(canonical.get("storeId"));
        com.howmuch.dto.VisitRequest identity = com.howmuch.dto.VisitRequest.builder()
                .storeId(canonicalId != null && !canonicalId.isBlank() ? canonicalId : storeId)
                .storeName(storeName)
                .build();
        return locationVisitDocumentId(firebaseUid, identity, date);
    }

    private String sha256Hex(String value) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8));
            return java.util.HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new IllegalStateException("식별자 해시를 생성하지 못했습니다.", e);
        }
    }

    private boolean isAlreadyExists(Throwable error) {
        Throwable current = error;
        while (current != null) {
            if (current instanceof com.google.api.gax.rpc.AlreadyExistsException) return true;
            current = current.getCause();
        }
        return false;
    }

    private Map<String, Object> buildVisitData(
            String firebaseUid,
            com.howmuch.dto.VisitRequest request,
            long savedAmount,
            String visitedAt) {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("storeId", request.getStoreId());
        data.put("storeName", request.getStoreName());
        String industry = request.getIndustry();
        if (industry == null || industry.isBlank()) {
            industry = findIndustryByStoreName(request.getStoreName());
        }
        data.put("industry", industry);
        data.put("menu", request.getMenu());
        data.put("price", request.getPrice());
        boolean free = request.getPrice() != null && request.getPrice() == 0
                && isApprovedFreeMenu(request.getStoreId(), request.getStoreName(), request.getMenu());
        data.put("isFree", free);
        data.put("savedAmount", free ? 0L : savedAmount);
        Map<String, Object> canonical = resolveReviewStore(request.getStoreId() != null ? request.getStoreId() : request.getStoreName(), getStoreCatalogEntry().stores());
        data.put("isGov", canonical != null && "GOV".equals(canonical.get("source")));
        data.put("verificationMethod", request.getVerificationMethod());
        data.put("verificationDistanceMeters", request.getVerificationDistanceMeters());
        data.put("visitedAt", visitedAt);
        return data;
    }

    public boolean isApprovedFreeMenu(String storeId, String storeName, String menu) {
        Map<String, Object> store = resolveReviewStore(storeId != null && !storeId.isBlank() ? storeId : storeName, getAllStores());
        if (store == null || menu == null || menu.isBlank()) return false;
        for (int i = 1; i <= 4; i++) if (menu.trim().equals(strOrNull(store.get("menu" + i)))) {
            return Boolean.TRUE.equals(store.get("free" + i))
                    && WonPrice.parse(store.get("price" + i)).filter(WonPrice.Value::exact)
                    .map(price -> price.minimum() == 0).orElse(false);
        }
        return false;
    }

    public boolean isClosedStore(String storeId, String storeName) {
        Map<String, Object> store = resolveReviewStore(storeId != null && !storeId.isBlank() ? storeId : storeName, getStoreCatalogEntry().stores());
        return store != null && Boolean.TRUE.equals(store.get("isClosed"));
    }

    // 💡 사용자의 방문 기록 목록 조회 (방문 일시, 매장명, 절약 금액 등 포함)
    public java.util.List<com.howmuch.dto.VisitResponseDto> getUserVisits(String firebaseUid) throws Exception {
        var documents = db.collection("visits")
                .whereEqualTo("userId", firebaseUid)
                .get().get().getDocuments();

        java.util.List<com.howmuch.dto.VisitResponseDto> visits = new ArrayList<>();
        for (DocumentSnapshot doc : documents) {
            Map<String, Object> data = doc.getData();
            if (data == null) continue;

            Long savedAmt = 0L;
            if (data.get("savedAmount") != null) {
                try {
                    savedAmt = Long.parseLong(data.get("savedAmount").toString());
                } catch (NumberFormatException ignored) {}
            }

            Long priceAmt = null;
            if (data.get("price") != null) {
                try {
                    priceAmt = Long.parseLong(data.get("price").toString());
                } catch (NumberFormatException ignored) {}
            }

            Boolean isGov = null;
            if (data.get("isGov") != null) {
                isGov = Boolean.parseBoolean(data.get("isGov").toString());
            }

            Double verificationDistanceMeters = null;
            if (data.get("verificationDistanceMeters") instanceof Number distance) {
                verificationDistanceMeters = distance.doubleValue();
            }

            com.howmuch.dto.VisitResponseDto dto = com.howmuch.dto.VisitResponseDto.builder()
                    .id(doc.getId())
                    .visitedAt(data.get("visitedAt") != null ? data.get("visitedAt").toString() : null)
                    .storeName(data.get("storeName") != null ? data.get("storeName").toString() : null)
                    .savedAmount(savedAmt)
                    .storeId(data.get("storeId") != null ? data.get("storeId").toString() : null)
                    .menu(data.get("menu") != null ? data.get("menu").toString() : null)
                    .price(priceAmt)
                    .isGov(isGov)
                    .verificationMethod(data.get("verificationMethod") != null
                            ? data.get("verificationMethod").toString() : null)
                    .verificationDistanceMeters(verificationDistanceMeters)
                    .build();

            visits.add(dto);
        }

        // 방문 일시 최신순 정렬
        visits.sort((a, b) -> {
            String aTime = a.getVisitedAt() != null ? a.getVisitedAt() : "";
            String bTime = b.getVisitedAt() != null ? b.getVisitedAt() : "";
            return bTime.compareTo(aTime);
        });

        return visits;
    }

    // 💡 리뷰 저장 (작성자 uid는 인증된 세션에서만 주입)
    public String saveReview(String authorUid, com.howmuch.dto.ReviewRequest request) throws Exception {
        return createReview(authorUid, request).reviewId();
    }

    /** 저장된 리뷰 ID와 서버가 정한 작성자 표시명입니다. */
    public record SavedReview(String reviewId, String authorName) { }

    /**
     * 리뷰를 저장합니다. 작성자 표시명은 요청 본문 값을 쓰지 않고 회원 정보로 정합니다(계약 C1).
     */
    public SavedReview createReview(String authorUid, com.howmuch.dto.ReviewRequest request) throws Exception {
        if (authorUid == null || authorUid.isBlank()) {
            throw new IllegalArgumentException("인증된 사용자만 리뷰를 저장할 수 있습니다.");
        }
        Map<String, Object> store = resolveReviewStore(request.getStoreId(), getAllStores());
        if (store == null || !normalizeStoreIdentityPart(request.getStoreName())
                .equals(normalizeStoreIdentityPart(strOrNull(store.get("storeName"))))) {
            throw new IllegalArgumentException("매장을 정확히 확인할 수 없습니다. 매장 상세에서 다시 작성해주세요.");
        }
        String authorName = resolveReviewAuthorName(authorUid);
        Map<String, Object> data = new HashMap<>();
        data.put("storeId", store.get("storeId"));
        data.put("storeName", store.get("storeName"));
        data.put("storeAddress", store.get("address"));
        data.put("authorUid", authorUid);
        data.put("authorName", authorName);
        data.put("menu", request.getMenu());
        data.put("price", request.getPrice());
        data.put("content", request.getContent());
        data.put("stars", request.getStars());
        data.put("likes", 0);
        data.put("ownerReply", null);
        data.put("createdAt", java.time.Instant.now().toString());

        DocumentReference docRef = db.collection("reviews").document();
        ApiFuture<WriteResult> future = docRef.set(data);
        future.get();
        return new SavedReview(docRef.getId(), authorName);
    }

    private static final String REVIEW_AUTHOR_ANONYMOUS = "익명";
    private static final String REVIEW_AUTHOR_DEFAULT = "사용자";

    /**
     * 공개 리뷰 응답(계약 C1). 작성자 uid·매장 주소 같은 내부 필드는 내보내지 않고,
     * 작성자명은 저장된 값 대신 현재 회원 정보로 다시 정해 공개 설정 변경과 위조를 함께 막습니다.
     */
    private Map<String, Object> publicReviewView(
            String id, Map<String, Object> data, Object storeId, Object storeName,
            Object storeSource, Map<String, String> authorNames) {
        Map<String, Object> view = new LinkedHashMap<>();
        view.put("id", id);
        view.put("storeId", storeId);
        view.put("storeName", storeName);
        view.put("storeSource", storeSource == null ? "UNKNOWN" : storeSource);
        view.put("authorName", reviewAuthorName(strOrNull(data.get("authorUid")), authorNames));
        view.put("menu", data.get("menu"));
        view.put("price", data.get("price"));
        view.put("content", data.get("content"));
        view.put("stars", data.get("stars"));
        view.put("likes", data.get("likes") == null ? 0 : data.get("likes"));
        view.put("ownerReply", data.get("ownerReply"));
        view.put("createdAt", data.get("createdAt"));
        return view;
    }

    private String reviewAuthorName(String authorUid, Map<String, String> authorNames) {
        if (authorUid == null || authorUid.isBlank()) return REVIEW_AUTHOR_DEFAULT;
        return authorNames.computeIfAbsent(authorUid, this::resolveReviewAuthorName);
    }

    /** 닉네임 비공개면 "익명", 회원 정보나 닉네임이 없으면 "사용자"입니다. 조회 실패도 "사용자"로 숨깁니다. */
    private String resolveReviewAuthorName(String authorUid) {
        try {
            UserProfileResponse user = getUserProfile(authorUid);
            if (user == null) return REVIEW_AUTHOR_DEFAULT;
            if (Boolean.FALSE.equals(user.getNicknamePublic())) return REVIEW_AUTHOR_ANONYMOUS;
            String nickname = user.getNickname();
            return nickname == null || nickname.isBlank() ? REVIEW_AUTHOR_DEFAULT : nickname.trim();
        } catch (Exception exception) {
            return REVIEW_AUTHOR_DEFAULT;
        }
    }

    // 💡 특정 매장의 리뷰 목록 조회 (최신순 정렬 포함)
    public List<Map<String, Object>> getReviews(String storeId) throws Exception {
        // 폐업 매장 상세에서도 기존 리뷰는 보여야 하므로 폐업 매장을 포함한 목록으로 해석합니다.
        List<Map<String, Object>> catalog = getStoreCatalogEntry().stores();
        Map<String, Object> store = resolveReviewStore(storeId, catalog);
        if (store == null) return List.of();
        String canonicalId = String.valueOf(store.get("storeId"));
        String storeName = String.valueOf(store.get("storeName")).trim();
        Set<String> lookupIds = new LinkedHashSet<>();
        lookupIds.add(canonicalId);
        // Keep old name-keyed reviews visible only when that name identifies a
        // single public store. Ambiguous records remain in my/admin reviews for
        // manual reconciliation; never guess a branch or rewrite data on GET.
        if (reviewStoresNamed(storeName, catalog).size() == 1) lookupIds.add(storeName);
        Map<String, Map<String, Object>> reviewsById = new LinkedHashMap<>();
        Map<String, String> authorNames = new HashMap<>();
        for (String lookupId : lookupIds) {
            for (DocumentSnapshot doc : db.collection("reviews")
                    .whereEqualTo("storeId", lookupId).get().get().getDocuments()) {
                Map<String, Object> data = doc.getData() == null ? Map.of() : doc.getData();
                Object reviewStoreName = data.get("storeName") != null ? data.get("storeName") : store.get("storeName");
                reviewsById.put(doc.getId(), publicReviewView(doc.getId(), data, canonicalId,
                        reviewStoreName, store.get("source"), authorNames));
            }
        }
        List<Map<String, Object>> reviews = new ArrayList<>(reviewsById.values());
        // 복합 인덱스 없이 동작하도록 메모리에서 최신순 정렬
        reviews.sort((a, b) -> {
            String aTime = String.valueOf(a.getOrDefault("createdAt", ""));
            String bTime = String.valueOf(b.getOrDefault("createdAt", ""));
            return bTime.compareTo(aTime);
        });
        return reviews;
    }

    private Map<String, Object> resolveReviewStore(String storeId, List<Map<String, Object>> catalog) {
        if (storeId == null || storeId.isBlank()) return null;
        String key = storeId.trim();
        for (Map<String, Object> store : catalog) {
            if (key.equals(store.get("storeId"))) return store;
        }
        List<Map<String, Object>> named = reviewStoresNamed(key, catalog);
        return named.size() == 1 ? named.getFirst() : null;
    }

    private List<Map<String, Object>> reviewStoresNamed(String name, List<Map<String, Object>> catalog) {
        String normalized = normalizeStoreIdentityPart(name);
        return catalog.stream()
                .filter(store -> normalized.equals(
                        normalizeStoreIdentityPart(strOrNull(store.get("storeName")))))
                .toList();
    }

    // 💡 [어드민] 전체 리뷰 목록 (최신순, 매장명/작성자명 포함 — 소량 컬렉션)
    public List<Map<String, Object>> getAllReviews() throws Exception {
        List<Map<String, Object>> reviews = new ArrayList<>(db.collection("reviews")
                .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.DESCENDING)
                .limit(adminListLimit()).get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    return data;
                })
                .toList());
        return reviews;
    }

    // 💡 [어드민] 리뷰 삭제
    public void deleteReview(String reviewId) throws Exception {
        DocumentReference docRef = db.collection("reviews").document(reviewId);
        if (!docRef.get().get().exists()) {
            throw new IllegalArgumentException("리뷰를 찾을 수 없습니다: " + reviewId);
        }
        docRef.delete().get();
    }

    // 💡 로그인한 사용자가 작성한 리뷰 목록 조회 (최신순 정렬 포함)
    public List<Map<String, Object>> getMyReviews(String authorUid) throws Exception {
        List<Map<String, Object>> catalog = getStoreCatalogEntry().stores();
        Map<String, String> authorNames = new HashMap<>();
        List<Map<String, Object>> reviews = new ArrayList<>(db.collection("reviews")
                .whereEqualTo("authorUid", authorUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = doc.getData() == null ? Map.of() : doc.getData();
                    Map<String, Object> store = resolveReviewStore(strOrNull(data.get("storeId")), catalog);
                    Object storeName = data.get("storeName") != null || store == null
                            ? data.get("storeName") : store.get("storeName");
                    return publicReviewView(doc.getId(), data,
                            store == null ? data.get("storeId") : store.get("storeId"), storeName,
                            store == null ? "UNKNOWN" : store.get("source"), authorNames);
                })
                .toList());
        // 복합 인덱스 없이 동작하도록 메모리에서 최신순 정렬
        reviews.sort((a, b) -> {
            String aTime = String.valueOf(a.getOrDefault("createdAt", ""));
            String bTime = String.valueOf(b.getOrDefault("createdAt", ""));
            return bTime.compareTo(aTime);
        });
        return reviews;
    }

    // 💡 사용자의 절약 내역 목록 조회 (visits 컬렉션 기반)
    public List<com.howmuch.dto.SavingsHistoryResponse> getSavingsHistory(String firebaseUid) throws Exception {
        var documents = db.collection("visits")
                .whereEqualTo("userId", firebaseUid)
                .get().get().getDocuments();

        List<com.howmuch.dto.SavingsHistoryResponse> historyList = new ArrayList<>();
        for (DocumentSnapshot doc : documents) {
            Map<String, Object> data = doc.getData();
            if (data == null) continue;

            Long savedAmt = parseLongSafely(data.get("savedAmount"));
            Long priceAmt = parseLongSafely(data.get("price"));
            Boolean isGov = parseBooleanSafely(data.get("isGov"));

            String visitedAtStr = data.get("visitedAt") != null ? data.get("visitedAt").toString() : null;
            String dateStr = data.get("date") != null ? data.get("date").toString() : visitedAtStr;
            String storeName = data.get("storeName") != null ? data.get("storeName").toString() : null;
            String industry = data.get("industry") != null ? data.get("industry").toString() : null;
            if (industry == null || industry.isBlank()) {
                industry = findIndustryByStoreName(storeName);
            }

            com.howmuch.dto.SavingsHistoryResponse dto = com.howmuch.dto.SavingsHistoryResponse.builder()
                    .id(doc.getId())
                    .storeId(data.get("storeId") != null ? data.get("storeId").toString() : null)
                    .storeName(storeName)
                    .category(industry)
                    .visitedAt(visitedAtStr)
                    .date(dateStr)
                    .menu(data.get("menu") != null ? data.get("menu").toString() : null)
                    .price(priceAmt)
                    .savedAmount(savedAmt != null ? savedAmt : 0L)
                    .isGov(isGov)
                    .isFree(Boolean.TRUE.equals(data.get("isFree")))
                    .build();

            historyList.add(dto);
        }

        // 방문/절약 일시 최신순 정렬
        historyList.sort((a, b) -> {
            String aTime = a.getVisitedAt() != null ? a.getVisitedAt() : (a.getDate() != null ? a.getDate() : "");
            String bTime = b.getVisitedAt() != null ? b.getVisitedAt() : (b.getDate() != null ? b.getDate() : "");
            return bTime.compareTo(aTime);
        });

        return historyList;
    }

    private Long parseLongSafely(Object obj) {
        if (obj == null) return null;
        if (obj instanceof Number num) {
            return num.longValue();
        }
        try {
            return (long) Double.parseDouble(obj.toString().trim());
        } catch (Exception e) {
            return null;
        }
    }

    private Boolean parseBooleanSafely(Object obj) {
        if (obj == null) return null;
        if (obj instanceof Boolean b) {
            return b;
        }
        String str = obj.toString().trim();
        if ("1".equals(str) || "true".equalsIgnoreCase(str)) {
            return true;
        }
        if ("0".equals(str) || "false".equalsIgnoreCase(str)) {
            return false;
        }
        return Boolean.parseBoolean(str);
    }

    // 💡 유저 프로필 저장
    public UserProfileResponse saveUserProfile(String firebaseUid, UserProfileRequest request) throws Exception {
        if (firebaseUid == null || firebaseUid.isBlank()) {
            throw new IllegalArgumentException("로그인이 필요합니다.");
        }
        DocumentReference document = db.collection("users").document(firebaseUid);
        DocumentSnapshot existing = document.get().get();
        Boolean existingNicknamePublic = existing.exists()
                ? parseBooleanSafely(existing.get("nicknamePublic"))
                : null;
        Boolean existingActivityPublic = existing.exists()
                ? parseBooleanSafely(existing.get("activityPublic"))
                : null;
        boolean nicknamePublic = request.getNicknamePublic() != null
                ? request.getNicknamePublic()
                : existingNicknamePublic == null || existingNicknamePublic;
        boolean activityPublic = request.getActivityPublic() != null
                ? request.getActivityPublic()
                : existingActivityPublic != null && existingActivityPublic;
        String resolvedEmail = resolveProfileEmail(
                request.getEmail(), existing.exists() ? existing.get("email") : null);
        String resolvedProfileImageUrl = resolveProfileImageUrl(
                request.getProfileImageUrl(),
                existing.exists() ? existing.get("profileImageUrl") : null);

        Map<String, Object> data = new HashMap<>();
        data.put("firebaseUid", firebaseUid);
        data.put("nickname", request.getNickname());
        data.put("email", resolvedEmail);
        data.put("region", request.getRegion());
        data.put("favoriteCategories", request.getFavoriteCategories());
        data.put("nicknamePublic", nicknamePublic);
        data.put("activityPublic", activityPublic);
        if (!resolvedProfileImageUrl.isBlank()) {
            data.put("profileImageUrl", resolvedProfileImageUrl);
        }
        data.put("updatedAt", java.time.Instant.now().toString());

        String createdAt = existing.exists() && existing.get("createdAt") != null
                ? existing.get("createdAt").toString()
                : java.time.Instant.now().toString();
        data.put("createdAt", createdAt);
        ApiFuture<WriteResult> future = document.set(data, SetOptions.merge());
        future.get();
        invalidateCommunityFeedCache();

        return UserProfileResponse.builder()
                .firebaseUid(firebaseUid)
                .nickname(request.getNickname())
                .email(resolvedEmail)
                .region(request.getRegion())
                .favoriteCategories(request.getFavoriteCategories())
                .createdAt(createdAt)
                .nicknamePublic((Boolean) data.get("nicknamePublic"))
                .activityPublic((Boolean) data.get("activityPublic"))
                .profileImageUrl(resolvedProfileImageUrl)
                .build();
    }

    /** No writes occur until every requested store is owned by this user. */
    public void savePriceAlertSettings(String uid, com.howmuch.dto.PriceAlertBatchRequest request)
            throws Exception {
        if (request == null || request.getStores() == null || request.getStores().size() > 400
                || request.getNotifyOnRise() == null || request.getNotifyOnDrop() == null
                || request.getNotifyOnNewMenu() == null) {
            throw new IllegalArgumentException("가격 알림 설정이 올바르지 않습니다.");
        }
        Map<String, List<DocumentReference>> owned = new HashMap<>();
        if (!request.getStores().isEmpty()) {
            for (DocumentSnapshot favorite : db.collection("favorites")
                    .whereEqualTo("userId", uid).get().get().getDocuments()) {
                owned.computeIfAbsent(canonicalStoreIdForFavorite(favorite.getData()),
                        key -> new ArrayList<>()).add(favorite.getReference());
            }
        }
        Map<DocumentReference, Boolean> updates = new HashMap<>();
        java.util.Set<String> seen = new java.util.HashSet<>();
        for (var preference : request.getStores()) {
            if (preference == null || preference.getStoreId() == null
                    || preference.getStoreId().isBlank() || preference.getEnabled() == null
                    || !seen.add(preference.getStoreId())) {
                throw new IllegalArgumentException("중복되거나 잘못된 매장 설정입니다.");
            }
            var references = owned.get(preference.getStoreId());
            if (references == null) throw new NoSuchElementException("찜한 매장을 찾을 수 없습니다.");
            for (var reference : references) updates.put(reference, preference.getEnabled());
        }
        if (updates.size() > 499) throw new IllegalArgumentException("한 번에 저장할 수 있는 매장 수를 초과했습니다.");
        var batch = db.batch();
        for (var update : updates.entrySet()) {
            batch.update(update.getKey(), "priceAlertEnabled", update.getValue());
        }
        batch.set(db.collection("notification_settings").document(uid), Map.of(
                "notifyOnRise", request.getNotifyOnRise(),
                "notifyOnDrop", request.getNotifyOnDrop(),
                "notifyOnNewMenu", request.getNotifyOnNewMenu(),
                "updatedAt", java.time.Instant.now().toString()), SetOptions.merge());
        batch.commit().get();
    }

    static String resolveProfileEmail(String requestedEmail, Object existingEmailValue) {
        String requested = requestedEmail == null ? "" : requestedEmail.trim();
        String existing = existingEmailValue == null ? "" : existingEmailValue.toString().trim();
        return requested.isBlank() && !existing.isBlank() ? existing : requested;
    }

    static String resolveProfileImageUrl(String requestedImageUrl, Object existingImageValue) {
        String requested = requestedImageUrl == null ? "" : requestedImageUrl.trim();
        String existing = existingImageValue == null ? "" : existingImageValue.toString().trim();
        return requested.isBlank() && !existing.isBlank() ? existing : requested;
    }

    // 💡 유저 프로필 조회
    public UserProfileResponse getUserProfile(String firebaseUid) throws Exception {
        DocumentReference docRef = db.collection("users").document(firebaseUid);
        ApiFuture<DocumentSnapshot> future = docRef.get();
        DocumentSnapshot document = future.get();

        if (!document.exists()) {
            return null;
        }

        Map<String, Object> data = document.getData();

        @SuppressWarnings("unchecked")
        List<String> favoriteCategories = (List<String>) data.get("favoriteCategories");

        return UserProfileResponse.builder()
                .firebaseUid(firebaseUid)
                .nickname((String) data.get("nickname"))
                .email((String) data.get("email"))
                .region((String) data.get("region"))
                .favoriteCategories(favoriteCategories)
                .createdAt((String) data.get("createdAt"))
                .nicknamePublic(data.get("nicknamePublic") == null || Boolean.parseBoolean(data.get("nicknamePublic").toString()))
                .activityPublic(data.get("activityPublic") != null && Boolean.parseBoolean(data.get("activityPublic").toString()))
                .profileImageUrl((String) data.get("profileImageUrl"))
                .build();
    }

    // ==================== 찜하기 (favorites) ====================

    /** 찜 문서 ID: 유저당 매장 1개 찜만 허용 (멱등 추가/삭제용) */
    private String favoriteDocId(String firebaseUid, String storeId) {
        return firebaseUid + "_" + sanitizeForDocId(storeId);
    }

    /**
     * Firestore 문서 ID에는 '/'를 쓸 수 없어 매장명에 슬래시가 있으면 찜이 실패함 (8/4 감사 #6).
     * '_' → '__', '/' → '_s' 순으로 이스케이프 (단사 함수라 서로 다른 매장명이 같은 ID로 충돌하지 않음).
     */
    private String sanitizeForDocId(String storeId) {
        if (storeId == null) return "";
        return storeId.replace("_", "__").replace("/", "_s");
    }

    /**
     * 매장명만으로는 동명이점이 충돌할 수 있으므로 주소·전화번호를 함께 해시한 식별자입니다.
     * 기존 데이터의 storeId(매장명)는 호환을 위해 조회 시 계속 지원합니다.
     */
    private String stableStoreId(String storeName, String address, String phoneNumber) {
        String canonical = String.join("|",
                normalizeStoreIdentityPart(storeName),
                normalizeStoreIdentityPart(address),
                normalizeStoreIdentityPart(phoneNumber));
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(canonical.getBytes(StandardCharsets.UTF_8));
            return "store_" + java.util.HexFormat.of().formatHex(hash, 0, 12);
        } catch (Exception e) {
            throw new IllegalStateException("매장 식별자를 만들지 못했습니다.", e);
        }
    }

    private String normalizeStoreIdentityPart(String value) {
        return value == null ? "" : value.trim().replaceAll("\\s+", " ").toLowerCase();
    }

    private String stableStoreIdForData(Map<String, Object> data) {
        if (data == null) return stableStoreId("", "", "");
        String storeName = strOrNull(data.get("storeName"));
        String address = strOrNull(data.get("address"));
        String phoneNumber = strOrNull(data.get("phoneNumber"));
        if (address == null || address.isBlank()) {
            Map<String, Object> govStore = findGovStoreByName(storeName);
            if (govStore != null) {
                address = strOrNull(govStore.get("address"));
                phoneNumber = phoneNumber == null || phoneNumber.isBlank()
                        ? strOrNull(govStore.get("phoneNumber"))
                        : phoneNumber;
            }
        }
        return stableStoreId(storeName, address, phoneNumber);
    }

    private Map<String, Object> withStableStoreId(Map<String, Object> data) {
        Map<String, Object> copy = new HashMap<>(data);
        Object existing = copy.get("storeId");
        if (existing == null || existing.toString().isBlank()) {
            copy.put("storeId", stableStoreIdForData(copy));
        }
        // Only the reviewed, separate catalog supplies hours; incoming snapshots cannot override it.
        copy.remove("openingHours");
        if (storeHoursCatalog != null) {
            Map<String, Object> hours = storeHoursCatalog.findFor(copy);
            if (hours != null) copy.put("openingHours", hours);
        }
        return copy;
    }

    /** 공공데이터 인메모리 캐시에서 매장명으로 매장 정보 조회 (Firestore 읽기 0). 없으면 null */
    private Map<String, Object> findGovStoreByName(String storeName) {
        if (storeName == null || storeName.isBlank()) return null;
        // This lookup is used while assigning IDs; never recurse into the canonical catalog.
        List<Map<String, Object>> matches = cachedStores.stream()
                .filter(store -> storeName.equals(String.valueOf(store.get("storeName")))).toList();
        return matches.size() == 1 ? matches.getFirst() : null;
    }

    /**
     * 방문 인증용 매장 좌표를 캐시에서 조회합니다.
     * storeId가 있으면 ID와 매장명이 모두 일치해야 합니다. ID가 없는 레거시
     * 클라이언트만 고유한 매장명으로 보완합니다.
     */
    public java.util.Optional<StoreCoordinates> findStoreCoordinates(String storeId, String storeName) {
        List<Map<String, Object>> stores = getAllStores();

        StoreCoordinates nameFallback = null;
        for (Map<String, Object> rawStore : stores) {
            Map<String, Object> store = rawStore;
            StoreCoordinates coordinates = toStoreCoordinates(store);
            if (coordinates == null) continue;
            String cachedId = strOrNull(store.get("storeId"));
            String cachedName = strOrNull(store.get("storeName"));
            if (storeId != null && !storeId.isBlank()) {
                if (storeId.equals(cachedId)) {
                    boolean nameMatches = storeName != null
                            && normalizeStoreIdentityPart(storeName)
                            .equals(normalizeStoreIdentityPart(cachedName));
                    return nameMatches
                            ? java.util.Optional.of(coordinates)
                            : java.util.Optional.empty();
                }
                continue;
            }
            if (storeName != null && !storeName.isBlank()
                    && normalizeStoreIdentityPart(storeName)
                    .equals(normalizeStoreIdentityPart(cachedName))) {
                if (nameFallback != null
                        && (!java.util.Objects.equals(nameFallback.storeId(), coordinates.storeId())
                        || nameFallback.latitude() != coordinates.latitude()
                        || nameFallback.longitude() != coordinates.longitude())) {
                    return java.util.Optional.empty();
                }
                nameFallback = coordinates;
            }
        }
        return java.util.Optional.ofNullable(nameFallback);
    }

    private StoreCoordinates toStoreCoordinates(Map<String, Object> store) {
        try {
            double latitude = Double.parseDouble(String.valueOf(store.get("latitude")));
            double longitude = Double.parseDouble(String.valueOf(store.get("longitude")));
            if (!Double.isFinite(latitude) || !Double.isFinite(longitude)
                    || latitude == 0 || longitude == 0
                    || Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
                return null;
            }
            return new StoreCoordinates(
                    latitude,
                    longitude,
                    strOrNull(store.get("storeId")),
                    strOrNull(store.get("storeName")),
                    strOrNull(store.get("industry")));
        } catch (Exception ignored) {
            return null;
        }
    }

    private static String strOrNull(Object value) {
        return value != null ? value.toString() : null;
    }

    // 💡 찜 추가 (멱등: 같은 매장 재추가 시 덮어쓰기, 중복 문서 생성 안 됨)
    public com.howmuch.dto.FavoriteResponse addFavorite(String firebaseUid, com.howmuch.dto.FavoriteRequest request) throws Exception {
        DocumentSnapshot existing = findFavoriteDocument(firebaseUid, request.getStoreId());
        String docId = existing != null
                ? existing.getId()
                : favoriteDocId(firebaseUid, request.getStoreId());
        String createdAt = existing != null && existing.getString("createdAt") != null
                ? existing.getString("createdAt")
                : java.time.Instant.now().toString();
        boolean priceAlertEnabled = existing == null
                || booleanOrDefault(existing.getData(), "priceAlertEnabled", true);

        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("storeId", request.getStoreId());
        data.put("storeName", request.getStoreName());
        data.put("createdAt", createdAt);
        data.put("priceAlertEnabled", priceAlertEnabled);

        db.collection("favorites").document(docId).set(data).get();

        // 서버의 공개 카탈로그는 이미 메모리에 있으므로, 상세 화면에 필요한
        // 정보도 함께 보낸다. 클라이언트가 전체 카탈로그를 다시 받을 필요가 없다.
        return favoriteResponse(docId, data);
    }

    // 💡 찜 해제 (존재하지 않아도 에러 없이 성공 처리 — 멱등)
    public void removeFavorite(String firebaseUid, String storeId) throws Exception {
        DocumentSnapshot favorite = findFavoriteDocument(firebaseUid, storeId);
        if (favorite != null) {
            favorite.getReference().delete().get();
        }
    }

    // 💡 내 찜 목록 조회 (최신순)
    public List<com.howmuch.dto.FavoriteResponse> getFavorites(String firebaseUid) throws Exception {
        // 한 번의 목록 응답 안에서 같은 공개 카탈로그를 찜 건수만큼 선형 탐색하지 않는다.
        Map<String, Map<String, Object>> publicStoresById = publicStoreIndex();
        List<com.howmuch.dto.FavoriteResponse> favorites = new ArrayList<>(db.collection("favorites")
                .whereEqualTo("userId", firebaseUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = doc.getData();
                    return favoriteResponseFromCatalog(doc.getId(), data, publicStoresById);
                })
                .toList());
        // 복합 인덱스 없이 동작하도록 메모리에서 최신순 정렬
        favorites.sort((a, b) -> {
            String aTime = a.getCreatedAt() != null ? a.getCreatedAt() : "";
            String bTime = b.getCreatedAt() != null ? b.getCreatedAt() : "";
            return bTime.compareTo(aTime);
        });
        return favorites;
    }

    /**
     * 찜 목록의 lightweight 문서와 공개 매장 카탈로그를 stable storeId로 결합한다.
     *
     * 이 경로는 서버에 이미 적재된 불변 카탈로그만 조회한다. 클라이언트에서
     * /api/stores/all을 다시 내려받거나, 동명이점의 이름만으로 잘못 매칭하지 않는다.
     * 매장이 삭제됐거나 비공개가 된 경우에는 찜 문서 정보만 반환한다.
     */
    com.howmuch.dto.FavoriteResponse favoriteResponse(
            String documentId, Map<String, Object> favorite) {
        return favoriteResponseFromCatalog(documentId, favorite, publicStoreIndex());
    }

    private com.howmuch.dto.FavoriteResponse favoriteResponseFromCatalog(
            String documentId,
            Map<String, Object> favorite,
            Map<String, Map<String, Object>> publicStoresById) {
        String storeId = canonicalStoreIdForFavorite(favorite);
        String storeName = strOrNull(favorite.get("storeName"));
        Map<String, Object> store = publicStoresById.get(storeId);

        return com.howmuch.dto.FavoriteResponse.builder()
                .id(documentId)
                .storeId(storeId)
                .storeName(storeName)
                .createdAt(strOrNull(favorite.get("createdAt")))
                .industry(store != null ? strOrNull(store.get("industry")) : null)
                .menu1(store != null ? strOrNull(store.get("menu1")) : null)
                .price1(store != null ? strOrNull(store.get("price1")) : null)
                .menu2(store != null ? strOrNull(store.get("menu2")) : null)
                .price2(store != null ? strOrNull(store.get("price2")) : null)
                .menu3(store != null ? strOrNull(store.get("menu3")) : null)
                .price3(store != null ? strOrNull(store.get("price3")) : null)
                .menu4(store != null ? strOrNull(store.get("menu4")) : null)
                .price4(store != null ? strOrNull(store.get("price4")) : null)
                .free1(store != null && Boolean.TRUE.equals(store.get("free1")))
                .free2(store != null && Boolean.TRUE.equals(store.get("free2")))
                .free3(store != null && Boolean.TRUE.equals(store.get("free3")))
                .free4(store != null && Boolean.TRUE.equals(store.get("free4")))
                .isClosed(store != null && Boolean.TRUE.equals(store.get("isClosed")))
                .correctionRevision(store != null ? StoreCorrectionPolicy.revision(store) : 0L)
                .address(store != null ? strOrNull(store.get("address")) : null)
                .phoneNumber(store != null ? strOrNull(store.get("phoneNumber")) : null)
                .latitude(store != null ? finiteNumberOrNull(store.get("latitude")) : null)
                .longitude(store != null ? finiteNumberOrNull(store.get("longitude")) : null)
                .source(store != null ? strOrNull(store.get("source")) : null)
                .build();
    }

    /** 공개 상태의 정부·사용자 제보 매장을 stable ID로 인덱싱한다. */
    private Map<String, Map<String, Object>> publicStoreIndex() {
        Map<String, Map<String, Object>> storesById = new HashMap<>();
        for (Map<String, Object> store : getStoreCatalogEntry().stores()) {
            String storeId = strOrNull(store.get("storeId"));
            if (storeId != null && !storeId.isBlank()) {
                storesById.putIfAbsent(storeId, store);
            }
        }
        return storesById;
    }

    private static Double finiteNumberOrNull(Object value) {
        if (value == null) return null;
        try {
            double parsed = Double.parseDouble(value.toString());
            return Double.isFinite(parsed) ? parsed : null;
        } catch (NumberFormatException ignored) {
            return null;
        }
    }

    private String canonicalStoreIdForFavorite(Map<String, Object> data) {
        String storedStoreId = strOrNull(data.get("storeId"));
        if (storedStoreId != null && storedStoreId.startsWith("store_")) {
            return storedStoreId;
        }
        return stableStoreIdForData(data);
    }

    /** 찜 문서의 기존 storeId 형식까지 포함해 매장을 찾습니다. */
    private DocumentSnapshot findFavoriteDocument(String firebaseUid, String storeId) throws Exception {
        if (storeId == null || storeId.isBlank()) return null;

        DocumentSnapshot direct = db.collection("favorites")
                .document(favoriteDocId(firebaseUid, storeId)).get().get();
        if (direct.exists() && firebaseUid.equals(direct.getString("userId"))) {
            return direct;
        }

        String legacyDocId = firebaseUid + "_" + storeId;
        if (!legacyDocId.equals(direct.getId())) {
            DocumentSnapshot legacy = db.collection("favorites").document(legacyDocId).get().get();
            if (legacy.exists() && firebaseUid.equals(legacy.getString("userId"))) {
                return legacy;
            }
        }

        // 기존 찜 문서가 매장명 기반 ID인 경우, 응답에 새 stable storeId를 사용해도 찾을 수 있게 합니다.
        for (DocumentSnapshot candidate : db.collection("favorites")
            .whereEqualTo("userId", firebaseUid).get().get().getDocuments()) {
            Map<String, Object> data = candidate.getData();
            String storedStoreId = strOrNull(data.get("storeId"));
            String storeName = strOrNull(data.get("storeName"));
            if (storeId.equals(storedStoreId)
                    || storeId.equals(storeName)
                    || storeId.equals(canonicalStoreIdForFavorite(data))) {
                return candidate;
            }
        }
        return null;
    }

    /** 매장별 가격 알림 화면에 필요한 찜 매장 목록 */
    public List<PriceAlertSubscriptionDto> getPriceAlertSubscriptions(String firebaseUid)
            throws Exception {
        List<PriceAlertSubscriptionDto> subscriptions = new ArrayList<>();
        NotificationSettingsDto settings = getNotificationSettings(firebaseUid);
        // BE-CORE-5: 승인된 보정이 반영된 공개 목록에서 대표 메뉴·가격을 읽습니다(원본 스냅샷 가격 아님).
        Map<String, Map<String, Object>> storesById = publicStoreIndex();
        for (DocumentSnapshot favorite : db.collection("favorites")
                .whereEqualTo("userId", firebaseUid).get().get().getDocuments()) {
            Map<String, Object> data = favorite.getData();
            String storeId = canonicalStoreIdForFavorite(data);
            Map<String, Object> store = storesById.get(storeId);
            String storeName = store != null && strOrNull(store.get("storeName")) != null
                    ? strOrNull(store.get("storeName")) : strOrNull(data.get("storeName"));
            String[] representative = representativeMenu(store);
            subscriptions.add(PriceAlertSubscriptionDto.builder()
                    .storeId(storeId)
                    .storeName(storeName != null && !storeName.isBlank() ? storeName : "매장명 없음")
                    .menuName(representative[0] != null ? representative[0] : "가격 변동 알림")
                    .price(representative[1])
                    .enabled(booleanOrDefault(data, "priceAlertEnabled", true))
                    .notifyOnRise(Boolean.TRUE.equals(settings.getNotifyOnRise()))
                    .notifyOnDrop(Boolean.TRUE.equals(settings.getNotifyOnDrop()))
                    .notifyOnNewMenu(Boolean.TRUE.equals(settings.getNotifyOnNewMenu()))
                    .build());
        }
        subscriptions.sort(Comparator.comparing(
                PriceAlertSubscriptionDto::getStoreName,
                String.CASE_INSENSITIVE_ORDER));
        return subscriptions;
    }

    /** 첫 번째로 등록된 메뉴와 그 가격입니다(보정으로 1번 메뉴가 빠졌으면 다음 메뉴). 없으면 둘 다 null입니다. */
    private static String[] representativeMenu(Map<String, Object> store) {
        if (store == null) return new String[]{null, null};
        for (int slot = 1; slot <= 4; slot++) {
            String menu = blankToNull(store.get("menu" + slot));
            if (menu != null) return new String[]{menu, blankToNull(store.get("price" + slot))};
        }
        return new String[]{null, null};
    }

    /** 찜한 매장에 대해서만 가격 알림 구독 상태를 변경합니다. */
    public PriceAlertSubscriptionDto savePriceAlertSubscription(
            String firebaseUid,
            PriceAlertSubscriptionRequest request) throws Exception {
        if (request == null || request.getStoreId() == null || request.getStoreId().isBlank()) {
            throw new IllegalArgumentException("storeId는 필수입니다.");
        }
        if (request.getEnabled() == null) {
            throw new IllegalArgumentException("enabled는 필수입니다.");
        }

        DocumentSnapshot favorite = findFavoriteDocument(firebaseUid, request.getStoreId());
        if (favorite == null) {
            throw new NoSuchElementException("찜한 매장을 찾을 수 없습니다.");
        }
        favorite.getReference().update("priceAlertEnabled", request.getEnabled()).get();

        if (request.getNotifyOnRise() != null
                || request.getNotifyOnDrop() != null
                || request.getNotifyOnNewMenu() != null) {
            Map<String, Object> conditionUpdates = new HashMap<>();
            if (request.getNotifyOnRise() != null) {
                conditionUpdates.put("notifyOnRise", request.getNotifyOnRise());
            }
            if (request.getNotifyOnDrop() != null) {
                conditionUpdates.put("notifyOnDrop", request.getNotifyOnDrop());
            }
            if (request.getNotifyOnNewMenu() != null) {
                conditionUpdates.put("notifyOnNewMenu", request.getNotifyOnNewMenu());
            }
            db.collection("notification_settings").document(firebaseUid)
                    .set(conditionUpdates, SetOptions.merge()).get();
        }

        Map<String, Object> data = new HashMap<>(favorite.getData());
        data.put("priceAlertEnabled", request.getEnabled());
        NotificationSettingsDto savedConditions = getNotificationSettings(firebaseUid);
        String storeId = canonicalStoreIdForFavorite(data);
        Map<String, Object> store = publicStoreIndex().get(storeId);
        String storeName = store != null && strOrNull(store.get("storeName")) != null
                ? strOrNull(store.get("storeName")) : strOrNull(data.get("storeName"));
        String[] representative = representativeMenu(store);
        return PriceAlertSubscriptionDto.builder()
                .storeId(storeId)
                .storeName(storeName != null ? storeName : "매장명 없음")
                .menuName(representative[0] != null ? representative[0] : "가격 변동 알림")
                .price(representative[1])
                .enabled(request.getEnabled())
                .notifyOnRise(Boolean.TRUE.equals(savedConditions.getNotifyOnRise()))
                .notifyOnDrop(Boolean.TRUE.equals(savedConditions.getNotifyOnDrop()))
                .notifyOnNewMenu(Boolean.TRUE.equals(savedConditions.getNotifyOnNewMenu()))
                .build();
    }

    // ==================== 절약 목표 (savings goal) ====================

    // 💡 절약 목표 설정 (users/{uid} 문서에 병합 저장 → 앱 재시작 후에도 유지)
    public com.howmuch.dto.SavingsGoalResponse saveSavingsGoal(String firebaseUid, Long goalAmount) throws Exception {
        String updatedAt = java.time.Instant.now().toString();

        Map<String, Object> data = new HashMap<>();
        data.put("savingsGoalAmount", goalAmount);
        data.put("savingsGoalUpdatedAt", updatedAt);

        // SetOptions.merge(): 프로필 등 다른 필드를 지우지 않고 목표 필드만 갱신
        db.collection("users").document(firebaseUid)
                .set(data, com.google.cloud.firestore.SetOptions.merge())
                .get();

        return com.howmuch.dto.SavingsGoalResponse.builder()
                .goalAmount(goalAmount)
                .updatedAt(updatedAt)
                .build();
    }

    // 💡 절약 목표 조회 (미설정 시 goalAmount=null)
    public com.howmuch.dto.SavingsGoalResponse getSavingsGoal(String firebaseUid) throws Exception {
        DocumentSnapshot document = db.collection("users").document(firebaseUid).get().get();

        if (!document.exists()) {
            return com.howmuch.dto.SavingsGoalResponse.builder()
                    .goalAmount(null)
                    .updatedAt(null)
                    .build();
        }

        Map<String, Object> data = document.getData();
        Long goalAmount = null;
        Object raw = data.get("savingsGoalAmount");
        if (raw instanceof Number num) {
            goalAmount = num.longValue();
        } else if (raw != null) {
            try {
                goalAmount = Long.parseLong(raw.toString());
            } catch (NumberFormatException ignored) {}
        }

        return com.howmuch.dto.SavingsGoalResponse.builder()
                .goalAmount(goalAmount)
                .updatedAt(data.get("savingsGoalUpdatedAt") != null ? data.get("savingsGoalUpdatedAt").toString() : null)
                .build();
    }

    // 💡 커뮤니티 피드 노출 여부 — 반려(REJECTED) 제보는 공개 피드에서 제외
    // (PENDING=검토 중, APPROVED=승인 완료, status 없음=승인제 이전 레거시는 노출)
    private boolean isFeedVisible(Map<String, Object> data) {
        if (StoreCorrectionPolicy.informationReport(data)) return false;
        Object status = data.get("status");
        if (status == null || status.toString().isBlank()) return true; // 레거시
        return !"REJECTED".equalsIgnoreCase(status.toString());
    }

    private void invalidateCommunityFeedCache() {
        synchronized (feedsCacheLock) {
            cachedFeeds = null;
            lastFeedsCacheTime = 0L;
        }
    }

    // 💡 커뮤니티 피드 목록 조회 (최신순, REJECTED 제외)
    // 60초 캐시와 단일 갱신 잠금으로 동시 만료 요청의 Firestore 중복 조회를 방지합니다.
    /**
     * 로그인 요청자는 자신이 좋아요한 글을 목록에서도 표시합니다(FE-COMM-18).
     * 공유 캐시는 바꾸지 않고, 요청자의 좋아요 문서만 한 번 조회해 해당 글의 복사본에 표시합니다.
     */
    public List<com.howmuch.dto.FeedResponseDto> getCommunityFeeds(String requesterUid) throws Exception {
        List<com.howmuch.dto.FeedResponseDto> feeds = getCommunityFeeds();
        if (requesterUid == null || requesterUid.isBlank() || feeds.isEmpty()) return feeds;
        Set<String> liked = likedFeedIds(requesterUid);
        if (liked.isEmpty()) return feeds;
        List<com.howmuch.dto.FeedResponseDto> personalized = new ArrayList<>(feeds.size());
        for (com.howmuch.dto.FeedResponseDto feed : feeds) {
            personalized.add(liked.contains(feed.getId()) ? feed.toBuilder().likedByMe(true).build() : feed);
        }
        return personalized;
    }

    private Set<String> likedFeedIds(String uid) {
        try {
            Set<String> ids = new HashSet<>();
            for (DocumentSnapshot like : db.collection("feed_likes")
                    .whereEqualTo("userId", uid).get().get().getDocuments()) {
                String postId = like.getString("postId");
                if (postId != null && !postId.isBlank()) ids.add(postId);
            }
            return ids;
        } catch (Exception e) {
            // 좋아요 표시는 보조 정보라, 조회 실패가 피드 목록 전체를 막지 않게 합니다.
            log.warn("피드 목록 좋아요 표시 조회 실패: {}", e.getMessage());
            return Set.of();
        }
    }

    public List<com.howmuch.dto.FeedResponseDto> getCommunityFeeds() throws Exception {
        long now = System.currentTimeMillis();
        List<com.howmuch.dto.FeedResponseDto> cached = cachedFeeds;
        if (cached != null && (now - lastFeedsCacheTime < FEEDS_CACHE_TTL_MS)) {
            return cached;
        }

        synchronized (feedsCacheLock) {
            now = System.currentTimeMillis();
            cached = cachedFeeds;
            if (cached != null && (now - lastFeedsCacheTime < FEEDS_CACHE_TTL_MS)) {
                return cached;
            }

            var documents = db.collection("stores_user")
                    .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.DESCENDING)
                    .limit(Math.max(1, Math.min(communityFeedMaxItems, 1000)))
                    .get().get().getDocuments();

            List<com.howmuch.dto.FeedResponseDto> feeds = new ArrayList<>();
            Map<String, AuthorSnapshot> authorCache = new HashMap<>();

            for (DocumentSnapshot doc : documents) {
                Map<String, Object> data = doc.getData();
                if (data == null) continue;
                if (!isFeedVisible(data)) continue; // REJECTED 제외

                AuthorSnapshot authorInfo = feedAuthor(data, authorCache);

                String storeName = (String) data.get("storeName");
                String menu1 = (String) data.get("menu1");
                String price1 = (String) data.get("price1");
                String title = (storeName != null ? storeName : "") + " " + (menu1 != null ? menu1 : "") + " " + (price1 != null ? price1 : "");

                String cityDistrict = (String) data.get("cityDistrict");
                String location = cityDistrict != null ? cityDistrict : "알 수 없음";

                String status = (String) data.get("status");
                if (status == null) status = "PENDING";

                String createdAt = (String) data.get("createdAt");
                if (createdAt == null) createdAt = "";

                @SuppressWarnings("unchecked")
                List<String> imageUrls = (List<String>) data.get("imageUrls");
                if (imageUrls == null) imageUrls = new ArrayList<>();

                com.howmuch.dto.FeedResponseDto dto = com.howmuch.dto.FeedResponseDto.builder()
                        .id(doc.getId())
                        .location(location)
                        .title(title.trim())
                        .author(authorInfo.nickname())
                        .authorProfileImageUrl(authorInfo.profileImageUrl())
                        .likes(data.get("likes") != null ? Integer.parseInt(data.get("likes").toString()) : 0)
                        .comments(data.get("comments") != null ? Integer.parseInt(data.get("comments").toString()) : 0)
                        .status(status)
                        .imageUrls(imageUrls)
                        .createdAt(createdAt)
                        .storeName(storeName)
                        .menu(menu1)
                        .price(price1)
                        .free(Boolean.TRUE.equals(data.get("free1")))
                        .changeType(feedChangeType(data.get("changeType")))
                        .reportType(blankToNull(data.get("reportType")))
                        .cityProvince(blankToNull(data.get("cityProvince")))
                        .build();
                feeds.add(dto);
            }

            // 응답 순서를 방어적으로 한 번 더 보장합니다.
            feeds.sort((a, b) -> b.getCreatedAt().compareTo(a.getCreatedAt()));
            cachedFeeds = List.copyOf(feeds);
            lastFeedsCacheTime = System.currentTimeMillis();
            return cachedFeeds;
        }
    }

    // 💡 커뮤니티 피드 상세 조회 (REJECTED는 404, rejectReason 비공개)
    public com.howmuch.dto.FeedDetailResponseDto getCommunityFeedDetail(String id) throws Exception {
        return getCommunityFeedDetail(id, null);
    }

    public com.howmuch.dto.FeedDetailResponseDto getCommunityFeedDetail(String id, String requesterUid) throws Exception {
        DocumentSnapshot doc = db.collection("stores_user").document(id).get().get();
        if (!doc.exists()) {
            return null;
        }

        Map<String, Object> data = doc.getData();
        if (data == null) return null;
        if (!isFeedVisible(data)) return null; // REJECTED는 상세도 비공개

        AuthorSnapshot authorInfo = feedAuthor(data, new HashMap<>());

        String storeName = (String) data.get("storeName");
        String menu1 = (String) data.get("menu1");
        String price1 = (String) data.get("price1");
        String title = (storeName != null ? storeName : "") + " " + (menu1 != null ? menu1 : "") + " " + (price1 != null ? price1 : "");

        String cityDistrict = (String) data.get("cityDistrict");
        String location = cityDistrict != null ? cityDistrict : "알 수 없음";

        String status = (String) data.get("status");
        if (status == null) status = "PENDING";

        String createdAt = (String) data.get("createdAt");
        if (createdAt == null) createdAt = "";

        @SuppressWarnings("unchecked")
        List<String> imageUrls = (List<String>) data.get("imageUrls");
        if (imageUrls == null) imageUrls = new ArrayList<>();

        return com.howmuch.dto.FeedDetailResponseDto.builder()
                .id(doc.getId())
                .location(location)
                .title(title.trim())
                .author(authorInfo.nickname())
                .authorProfileImageUrl(authorInfo.profileImageUrl())
                .likes(data.get("likes") != null ? Integer.parseInt(data.get("likes").toString()) : 0)
                .comments(data.get("comments") != null ? Integer.parseInt(data.get("comments").toString()) : 0)
                .likedByMe(isFeedLikedBy(id, requesterUid))
                .notificationEnabled(isFeedNotificationEnabled(id, requesterUid))
                .status(status)
                .imageUrls(imageUrls)
                .createdAt(createdAt)
                .storeName(storeName != null ? storeName : "")
                .address(data.get("address") != null ? (String) data.get("address") : "")
                .phoneNumber(data.get("phoneNumber") != null ? (String) data.get("phoneNumber") : "")
                .industry(data.get("industry") != null ? (String) data.get("industry") : "")
                .menu1(menu1 != null ? menu1 : "")
                .price1(price1 != null ? price1 : "")
                .menu2(data.get("menu2") != null ? (String) data.get("menu2") : "")
                .price2(data.get("price2") != null ? (String) data.get("price2") : "")
                .menu3(data.get("menu3") != null ? (String) data.get("menu3") : "")
                .price3(data.get("price3") != null ? (String) data.get("price3") : "")
                .menu4(data.get("menu4") != null ? (String) data.get("menu4") : "")
                .price4(data.get("price4") != null ? (String) data.get("price4") : "")
                .free1(Boolean.TRUE.equals(data.get("free1")))
                .free2(Boolean.TRUE.equals(data.get("free2")))
                .free3(Boolean.TRUE.equals(data.get("free3")))
                .free4(Boolean.TRUE.equals(data.get("free4")))
                .visitedRecently(data.get("visitedRecently") != null && Boolean.parseBoolean(data.get("visitedRecently").toString()))
                .checkedMenuPrice(data.get("checkedMenuPrice") != null && Boolean.parseBoolean(data.get("checkedMenuPrice").toString()))
                .changeType(feedChangeType(data.get("changeType")))
                .reportType(blankToNull(data.get("reportType")))
                .cityProvince(blankToNull(data.get("cityProvince")))
                .build();
    }

    // ==================== 문의 (inquiries) ====================

    /**
     * 문의 등록 — Firestore inquiries 컬렉션에 저장.
     * userId(세션 uid), title, content, category, status(기본 PENDING), createdAt 포함.
     */
    public Map<String, Object> createInquiry(String firebaseUid, com.howmuch.dto.InquiryRequest request) throws Exception {
        String createdAt = java.time.Instant.now().toString();
        List<String> imageUrls = normalizeReportImageUrls(
                firebaseUid,
                request.getImageUrls(),
                Set.of());
        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("title", request.getTitle().trim());
        data.put("content", request.getContent().trim());
        data.put("category", request.getCategory() != null ? request.getCategory().trim() : "일반");
        data.put("status", "PENDING");
        data.put("createdAt", createdAt);
        data.put("imageUrls", imageUrls);

        DocumentReference docRef = db.collection("inquiries").document();
        docRef.set(data).get();

        Map<String, Object> result = new HashMap<>();
        result.put("id", docRef.getId());
        result.put("status", "PENDING");
        result.put("createdAt", createdAt);
        return result;
    }

    /** 내 문의 목록 조회 (최신순) — 마이페이지 문의 내역용 */
    public List<Map<String, Object>> getMyInquiries(String firebaseUid) throws Exception {
        List<Map<String, Object>> inquiries = new ArrayList<>(db.collection("inquiries")
                .whereEqualTo("userId", firebaseUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = doc.getData();
                    Map<String, Object> item = new HashMap<>();
                    item.put("id", doc.getId());
                    item.put("title", data.get("title"));
                    item.put("content", data.get("content"));
                    item.put("category", data.get("category"));
                    item.put("status", data.get("status"));
                    item.put("answer", data.get("answer"));
                    item.put("createdAt", data.get("createdAt"));
                    item.put("answeredAt", data.get("answeredAt"));
                    item.put("imageUrls", stringList(data.get("imageUrls")));
                    return item;
                })
                .toList());
        inquiries.sort((a, b) -> {
            String aTime = a.get("createdAt") != null ? a.get("createdAt").toString() : "";
            String bTime = b.get("createdAt") != null ? b.get("createdAt").toString() : "";
            return bTime.compareTo(aTime);
        });
        return inquiries;
    }

    /** 어드민: 전체 문의 목록 조회 (최신순) — /api/admin/inquiries */
    public List<Map<String, Object>> getAllInquiries() throws Exception {
        List<Map<String, Object>> inquiries = new ArrayList<>(db.collection("inquiries")
                .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.DESCENDING)
                .limit(adminListLimit()).get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = doc.getData();
                    Map<String, Object> item = new HashMap<>();
                    item.put("id", doc.getId());
                    item.put("userId", data.get("userId"));
                    item.put("title", data.get("title"));
                    item.put("content", data.get("content"));
                    item.put("category", data.get("category"));
                    item.put("status", data.get("status"));
                    item.put("answer", data.get("answer"));
                    item.put("createdAt", data.get("createdAt"));
                    item.put("answeredAt", data.get("answeredAt"));
                    item.put("imageUrls", stringList(data.get("imageUrls")));
                    return item;
                })
                .toList());
        return inquiries;
    }

    /**
     * WEB-ADM-15: 첨부 사진 작성자를 알 수 없어 사진을 안전하게 지울 수 없는 문의입니다.
     * 저장소 장애(503)와 구분해 관리자에게 정확한 이유를 알립니다.
     */
    public static class InquiryImageOwnerUnknownException extends IllegalStateException {
        public InquiryImageOwnerUnknownException(String message) {
            super(message);
        }
    }

    /** 어드민: 문의와 첨부 이미지, 답변 알림을 한 건 단위로 정리합니다. */
    public Map<String, Object> deleteInquiryAsAdmin(String inquiryId) throws Exception {
        if (inquiryId == null || inquiryId.isBlank()) {
            throw new IllegalArgumentException("삭제할 문의 ID가 필요합니다.");
        }

        DocumentReference inquiryRef = db.collection("inquiries").document(inquiryId);
        DocumentSnapshot inquiry = inquiryRef.get().get();
        if (!inquiry.exists()) {
            throw new NoSuchElementException("문의를 찾을 수 없습니다.");
        }

        String ownerUid = inquiry.getString("userId");
        List<String> imageUrls = stringList(inquiry.get("imageUrls"));
        if (!imageUrls.isEmpty() && (ownerUid == null || ownerUid.isBlank())) {
            throw new InquiryImageOwnerUnknownException("첨부 이미지 소유자 정보를 확인할 수 없습니다.");
        }
        List<String> ownedImageUrls = imageUrls.stream()
                        .filter(url -> reportImageStorage.isOwnedBy(ownerUid, url))
                        .toList();
        int deletedImages = ownedImageUrls.isEmpty()
                ? 0
                : reportImageStorage.deleteOwned(ownerUid, ownedImageUrls);

        DocumentReference answerNotificationRef = db.collection("notifications")
                .document("inquiry_answer_" + sanitizeForDocId(inquiryId));
        WriteBatch cleanupBatch = db.batch();
        cleanupBatch.delete(answerNotificationRef);
        cleanupBatch.delete(inquiryRef);
        cleanupBatch.commit().get();

        return Map.of(
                "success", true,
                "id", inquiryId,
                "deletedImages", deletedImages);
    }

    /** 어드민 문의 답변 등록 및 사용자 알림 생성 */
    public Map<String, Object> answerInquiry(String inquiryId, String answer) throws Exception {
        if (inquiryId == null || inquiryId.isBlank()) {
            throw new IllegalArgumentException("문의 ID가 필요합니다.");
        }
        if (answer == null || answer.isBlank() || answer.trim().length() > 2000) {
            throw new IllegalArgumentException("답변은 1자 이상 2000자 이내여야 합니다.");
        }
        DocumentReference inquiryRef = db.collection("inquiries").document(inquiryId);
        DocumentReference notificationRef = db.collection("notifications")
                .document("inquiry_answer_" + sanitizeForDocId(inquiryId));
        InquiryAnswerResult committed;
        try {
            committed = db.runTransaction(transaction -> {
                DocumentSnapshot inquiry = transaction.get(inquiryRef).get();
                if (!inquiry.exists()) {
                    throw new IllegalArgumentException("문의를 찾을 수 없습니다.");
                }

                String userId = inquiry.getString("userId");
                if (userId == null || userId.isBlank()) {
                    throw new IllegalArgumentException("문의 작성자 정보를 찾을 수 없습니다.");
                }

                String answeredAt = java.time.Instant.now().toString();
                String inquiryTitle = inquiry.getString("title");
                String notificationBody = (inquiryTitle == null || inquiryTitle.isBlank())
                        ? "등록한 문의에 답변이 등록되었습니다."
                        : "'" + inquiryTitle + "' 문의에 답변이 등록되었습니다.";

                transaction.update(inquiryRef, Map.of(
                        "answer", answer.trim(),
                        "answeredAt", answeredAt,
                        "status", "ANSWERED"
                ));
                transaction.set(notificationRef, Map.of(
                        "userId", userId,
                        "title", "문의 답변이 도착했어요",
                        "body", notificationBody,
                        "type", "INQUIRY_ANSWER",
                        "relatedInquiryId", inquiryId,
                        "isRead", false,
                        "createdAt", answeredAt
                ));
                return new InquiryAnswerResult(userId, answeredAt, notificationBody);
            }).get();
        } catch (ExecutionException e) {
            if (e.getCause() instanceof IllegalArgumentException invalidInquiry) {
                throw invalidInquiry;
            }
            throw e;
        }

        dispatchPushNotification(
                committed.userId(), notificationRef.getId(),
                "문의 답변이 도착했어요", committed.notificationBody(), "INQUIRY_ANSWER");
        return Map.of(
                "success", true,
                "id", inquiryId,
                "status", "ANSWERED",
                "answeredAt", committed.answeredAt());
    }

    private record InquiryAnswerResult(
            String userId, String answeredAt, String notificationBody) { }

    // ==================== 오늘의 픽 (todays pick) ====================

    /** 추천 대상 요식업 업종 (공공데이터의 미용업·이용업·세탁업·숙박업·목욕업·기타비요식업 제외) */
    private static final Set<String> FOOD_INDUSTRIES =
            Set.of("한식", "중식", "일식", "양식", "기타요식업", "카페", "제과점", "제과업", "휴게음식점");

    private static final List<String> DESSERT_KEYWORDS = List.of(
            "카페", "커피", "아메리카노", "라떼", "에이드", "주스", "스무디", "녹차", "홍차", "밀크티",
            "디저트", "베이커리", "제과", "빵", "케이크", "쿠키", "도넛", "꽈배기",
            "크로플", "와플", "아이스크림", "빙수", "마카롱", "샌드위치");

    /** 최종 추천 개수 */
    private static final int MAX_PICKS = 3;

   /** 위치 기반 후보군 크기 (이 안에서 날짜 시드 셔플로 최대 3곳 선정) */
   private static final int CANDIDATE_POOL_SIZE = 20;

    /**
     * 추천 허용 기본 최대 반경 (미터).
     * 가까운 동네 추천에 원거리 매장이 혼입되는 것을 방지한다.
     */
    public static final double MAX_RECOMMENDATION_RADIUS_METERS = 3000.0;

   /**
     * 오늘의 픽 추천 — 날씨 기반 추천 룰 + 공공데이터 인메모리 캐시에서 매장 선별.
     * Firestore 읽기 0 (cachedStores만 사용).
     *
     * @param weather 날씨 요약 (맑음/구름많음/흐림/비/눈/소나기/알 수 없음)
     * @param temp    기온 (섭씨, null 가능)
     * @param lat     사용자 위도 (거리 계산용, null 가능)
     * @param lng     사용자 경도 (거리 계산용, null 가능)
     * @return 추천 매장 리스트 (최대 3개)
     */
    public List<Map<String, Object>> getTodaysPicks(String weather, Integer temp, Double lat, Double lng) {
        return getTodaysPicks(weather, temp, lat, lng, 3000);
    }

    public List<Map<String, Object>> getTodaysPicks(String weather, Integer temp, Double lat, Double lng, int radiusMeters) {
        validateRecommendationRadius(radiusMeters);
        boolean locationAvailable = isValidCoordinate(lat, lng);
        if (!locationAvailable) return List.of();
        final Double effectiveLat = locationAvailable ? lat : null;
        final Double effectiveLng = locationAvailable ? lng : null;
        List<PickTheme> themes = weatherThemes(weather, temp);
        PickTheme mainTheme = themes.get(0);
        PickTheme altTheme = themes.size() > 1 ? themes.get(1) : null;

        // 💡 식당(요식업)만 추천 대상 — 공공데이터엔 미용업·세탁업·목욕업 등 비요식업이 섞여 있어
        //    매칭 실패 폼백에서 미용실이 추천되던 문제 방지
        List<Map<String, Object>> foodStores = new ArrayList<>();
        for (Map<String, Object> store : getAllStores()) {
            String industry = strOrNull(store.get("industry"));
            if (industry != null && FOOD_INDUSTRIES.contains(industry)
                    && hasValidStoreCoordinate(store) && firstPricedMenu(store) != null) {
                foodStores.add(store);
            }
        }

        // 테마별 매칭 (매장 → 실제 매칭된 메뉴 추적). 대안 테마는 메인과 겹치지 않게 제외.
        long dailySeed = java.time.LocalDate.now(ZoneId.of("Asia/Seoul")).toEpochDay();
        Map<String, String> matchedMenuByStore = new HashMap<>();
        Map<String, String> themeByStore = new HashMap<>();
        Map<String, String> reasonByStore = new HashMap<>();

        List<Map<String, Object>> mainMatched = matchTheme(foodStores, mainTheme,
                matchedMenuByStore, themeByStore, reasonByStore, Set.of());
        List<Map<String, Object>> altMatched = altTheme != null
                ? matchTheme(foodStores, altTheme,
                        matchedMenuByStore, themeByStore, reasonByStore,
                        Set.copyOf(themeByStore.keySet()))
                : List.of();

        // 메인이 0건이면 식당 전체 풀을 메인으로 사용 (폼백도 식당만)
        List<Map<String, Object>> mainPool = mainMatched.isEmpty() ? foodStores : mainMatched;

       // 위치가 있으면 가까운 순으로 후보를 유지한다. 예전에는 상위 20곳을
       // 다시 섞어 10km 이상 먼 매장이 앞 순위에 올라가는 문제가 있었다.
       List<Map<String, Object>> mainCandidates = nearestShuffled(
                mainPool, effectiveLat, effectiveLng, CANDIDATE_POOL_SIZE, dailySeed, radiusMeters);
       List<Map<String, Object>> altCandidates = nearestShuffled(
                altMatched, effectiveLat, effectiveLng, ALT_CANDIDATE_POOL_SIZE, dailySeed + 1, radiusMeters);

       // 날씨 테마 후보를 먼저 유지하되, 3km 안에서 식사 2곳 + 디저트/카페 1곳을
       // 우선 구성한다. 한쪽이 부족하면 다른 쪽으로만 채우고, 먼 매장까지 범위를
       // 확장하지 않는다.
       List<Map<String, Object>> nearbyFood = nearestShuffled(
               foodStores, effectiveLat, effectiveLng, CANDIDATE_POOL_SIZE,
               dailySeed + 2, radiusMeters);
       List<Map<String, Object>> preferred = new ArrayList<>();
       Set<String> preferredNames = new HashSet<>();
       addUnique(preferred, mainCandidates, CANDIDATE_POOL_SIZE, preferredNames);
       addUnique(preferred, altCandidates, CANDIDATE_POOL_SIZE, preferredNames);
       addUnique(preferred, nearbyFood, CANDIDATE_POOL_SIZE, preferredNames);

       List<Map<String, Object>> mealCandidates = preferred.stream()
               .filter(store -> !isDessertStore(store))
               .toList();
       List<Map<String, Object>> dessertCandidates = preferred.stream()
               .filter(this::isDessertStore)
               .toList();

       Set<String> seenNames = new HashSet<>();
       List<Map<String, Object>> chosen = new ArrayList<>();
       addUnique(chosen, mealCandidates, Math.min(2, MAX_PICKS), seenNames);
       addUnique(chosen, dessertCandidates, MAX_PICKS - chosen.size(), seenNames);
       addUnique(chosen, preferred, MAX_PICKS - chosen.size(), seenNames);

       if (locationAvailable) {
           chosen.sort(java.util.Comparator.comparingDouble(
                   store -> haversine(effectiveLat, effectiveLng, parseLat(store), parseLng(store))));
       }

       List<Map<String, Object>> picks = new ArrayList<>();
       for (Map<String, Object> store : chosen) {
           String name = strOrNull(store.get("storeName"));
           Map<String, Object> pick = new HashMap<>();
           pick.put("storeName", name);
           pick.put("industry", strOrNull(store.get("industry")));
           pick.put("menu1", strOrNull(store.get("menu1")));
           pick.put("price1", strOrNull(store.get("price1")));
           for (int menuIndex = 1; menuIndex <= 4; menuIndex++) pick.put("free" + menuIndex, Boolean.TRUE.equals(store.get("free" + menuIndex)));
           for (int menuIndex = 2; menuIndex <= 4; menuIndex++) {
               pick.put("menu" + menuIndex, strOrNull(store.get("menu" + menuIndex)));
               pick.put("price" + menuIndex, strOrNull(store.get("price" + menuIndex)));
           }
           pick.put("source", store.get("source"));
           pick.put("storeId", store.get("storeId"));
           pick.put("phoneNumber", store.get("phoneNumber"));
           pick.put("address", strOrNull(store.get("address")));
           pick.put("latitude", store.get("latitude"));
           pick.put("longitude", store.get("longitude"));
           if (locationAvailable) {
               pick.put("distanceMeters", (int) Math.round(
                       haversine(effectiveLat, effectiveLng, parseLat(store), parseLng(store))));
           }
            // 추천 근거: 실제 매칭된 메뉴 + 테마 + 이유 멘트 (폼백 매장도 4번째 추천 이유가 누락되지 않도록 메인 테마로 보정)
            String identity = String.valueOf(store.get("storeId"));
            String matchedMenu = matchedMenuByStore.get(identity);
            if (matchedMenu == null || matchedMenu.isBlank()) {
                matchedMenu = firstPricedMenu(store);
            }
            String theme = themeByStore.get(identity);
            if (theme == null || theme.isBlank()) {
                theme = "주변 매장";
            }
            String reason = reasonByStore.get(identity);
            if (reason == null || reason.isBlank()) {
                reason = "선택한 거리 안에서 가까운 매장이에요.";
            }
            pick.put("matchedMenu", matchedMenu);
            for (int slot = 1; slot <= 4; slot++) if (java.util.Objects.equals(matchedMenu, store.get("menu" + slot))) {
                pick.put("matchedFree", Boolean.TRUE.equals(store.get("free" + slot)));
            }
            pick.put("theme", theme);
            pick.put("reason", reason);
           picks.add(pick);
       }
       return picks;
    }

    /** 대안 테마 후보군 크기 */
    private static final int ALT_CANDIDATE_POOL_SIZE = 10;

    /**
     * FE-STORE-13: 추천 루트는 출발지에서 모든 매장을 한 번씩 들르는 총거리가 가장 짧은 순서로 정렬합니다.
     * 추천 매장은 최대 몇 곳뿐이라 모든 순서를 비교합니다. 위치나 매장 좌표가 없으면 원래 순서를 유지합니다.
     */
    public List<Map<String, Object>> orderRouteStops(List<Map<String, Object>> picks, Double lat, Double lng) {
        if (picks == null || picks.size() < 2 || picks.size() > 6
                || lat == null || lng == null || !isValidCoordinate(lat, lng)) {
            return picks;
        }
        int size = picks.size();
        double[][] points = new double[size][2];
        for (int i = 0; i < size; i++) {
            double pointLat = parseLat(picks.get(i));
            double pointLng = parseLng(picks.get(i));
            if (!isValidCoordinate(pointLat, pointLng)) return picks;
            points[i][0] = pointLat;
            points[i][1] = pointLng;
        }
        int[] order = java.util.stream.IntStream.range(0, size).toArray();
        int[] best = order.clone();
        double bestDistance = routeDistance(order, points, lat, lng);
        while (nextPermutation(order)) {
            double distance = routeDistance(order, points, lat, lng);
            if (distance + 1e-6 < bestDistance) {
                bestDistance = distance;
                best = order.clone();
            }
        }
        List<Map<String, Object>> ordered = new ArrayList<>(size);
        for (int index : best) ordered.add(picks.get(index));
        return ordered;
    }

    private double routeDistance(int[] order, double[][] points, double startLat, double startLng) {
        double total = 0;
        double currentLat = startLat;
        double currentLng = startLng;
        for (int index : order) {
            total += haversine(currentLat, currentLng, points[index][0], points[index][1]);
            currentLat = points[index][0];
            currentLng = points[index][1];
        }
        return total;
    }

    /** 사전순 다음 순열로 바꿉니다. 마지막 순열이면 false입니다. */
    private static boolean nextPermutation(int[] values) {
        int pivot = values.length - 2;
        while (pivot >= 0 && values[pivot] >= values[pivot + 1]) pivot--;
        if (pivot < 0) return false;
        int successor = values.length - 1;
        while (values[successor] <= values[pivot]) successor--;
        int swap = values[pivot]; values[pivot] = values[successor]; values[successor] = swap;
        for (int left = pivot + 1, right = values.length - 1; left < right; left++, right--) {
            swap = values[left]; values[left] = values[right]; values[right] = swap;
        }
        return true;
    }

    private boolean isDessertStore(Map<String, Object> store) {
        StringBuilder searchable = new StringBuilder();
        for (String key : new String[]{"industry", "storeName", "menu1", "menu2", "menu3", "menu4"}) {
            String value = strOrNull(store.get(key));
            if (value != null) searchable.append(' ').append(value.toLowerCase(java.util.Locale.ROOT));
        }
        String text = searchable.toString();
        return DESSERT_KEYWORDS.stream().anyMatch(text::contains);
    }

    /** 추천 테마 — 라벨(칩 표시용) + 이유 멘트 + 매칭 키워드 */
    private record PickTheme(String label, String reason, List<String> keywords) { }

    /**
     * 날씨/기온 기반 추천 테마 (메인 1개 + 대안 1개).
     * "덥다고 냉멸만" 같은 단조로움을 피하기 위해 대안 테마를 섞는다
     * (예: 폭염에도 '이열치열' 삼계탕, 비 오면 국물 + 파전).
     */
    private List<PickTheme> weatherThemes(String weather, Integer temp) {
        if (weather == null) weather = "알 수 없음";
        boolean hot = temp != null && temp >= 28;
        boolean cold = temp != null && temp <= 5;
        switch (weather) {
            case "비", "비/눈", "눈", "소나기" -> {
                return List.of(
                        new PickTheme("따뜻한 국물", "비 오는 날엔 뜨끈한 국물이 최고예요 🍜",
                                List.of("국밥", "칼국수", "국수", "찌개", "설렁탕", "갈비탕", "곰탕",
                                        "전골", "순두부", "우동", "수제비", "라면")),
                        // "전" 단독은 전골 등과 오매칭이라 구체 전 메뉴로 한정
                        new PickTheme("비 오면 파전", "비 오는 날엔 파전도 빼놓을 수 없죠 🥞",
                                List.of("파전", "부침개", "김치전", "핼물전", "모둠전")));
            }
            case "맑음", "구름많음", "흐림" -> {
                if (hot) {
                    return List.of(
                            new PickTheme("시원한 메뉴", "더운 날엔 시원한 한 끼 어때요? 🧊",
                                    List.of("냉면", "콩국수", "메밀", "빙수", "아이스크림", "샐러드", "주스")),
                            new PickTheme("이열치열", "이열치열! 뜨끈한 한 그릇도 별미예요 🔥",
                                    List.of("삼계탕", "국밥", "설렁탕", "갈비탕", "곰탕")));
                }
                if (cold) {
                    return List.of(
                            new PickTheme("따뜻한 메뉴", "추운 날엔 따뜻한 국물이 생각나요 🍲",
                                    List.of("국밥", "찌개", "설렁탕", "갈비탕", "곰탕", "전골", "우동", "칼국수", "수제비")),
                            new PickTheme("매콤하게", "매운 맛으로 추위를 날려보세요 🌶️",
                                    List.of("떡볶이", "마라탕", "매운")));
                }
                return List.of(
                        new PickTheme("든든한 한 끼", "오늘 같은 날엔 든든한 한 끼 어때요 ✨",
                                List.of("김밥", "분식", "국수", "덮밥")),
                        new PickTheme("색다른 한 끼", "가끔은 색다른 메뉴로 기분 전환 🍽️",
                                List.of("돈가스", "초밥", "족발", "보쌈")));
            }
            default -> {
                if (hot) {
                    return List.of(
                            new PickTheme("시원한 메뉴", "더운 날엔 시원한 한 끼 어때요? 🧊",
                                    List.of("냉면", "콩국수", "메밀")),
                            new PickTheme("이열치열", "이열치열! 뜨끈한 한 그릇도 별미예요 🔥",
                                    List.of("삼계탕", "국밥")));
                }
                if (cold) {
                    return List.of(
                            new PickTheme("따뜻한 메뉴", "추운 날엔 따뜻한 국물이 생각나요 🍲",
                                    List.of("국밥", "찌개", "전골")),
                            new PickTheme("매콤하게", "매운 맛으로 추위를 날려보세요 🌶️",
                                    List.of("떡볶이", "마라탕")));
                }
                return List.of(
                        new PickTheme("든든한 한 끼", "오늘 같은 날엔 든든한 한 끼 어때요 ✨",
                                List.of("김밥", "분식", "국수", "덮밥")),
                        new PickTheme("색다른 한 끼", "가끔은 색다른 메뉴로 기분 전환 🍽️",
                                List.of("돈가스", "초밥", "족발", "보쌈")));
            }
        }
    }

    /** 테마 키워드와 매칭되는 매장 수집 + 매장별 매칭 메뉴/테마/이유 기록 (제외 매장명 스킵) */
    private List<Map<String, Object>> matchTheme(List<Map<String, Object>> foodStores, PickTheme theme,
                                                 Map<String, String> matchedMenuByStore,
                                                 Map<String, String> themeByStore,
                                                 Map<String, String> reasonByStore,
                                                 Set<String> excludeNames) {
        List<Map<String, Object>> matched = new ArrayList<>();
        for (Map<String, Object> store : foodStores) {
            String identity = String.valueOf(store.get("storeId"));
            if (excludeNames.contains(identity)) continue;
            String matchedMenu = findMatchedMenu(store, theme);
            if (matchedMenu != null) {
                matched.add(store);
                matchedMenuByStore.put(identity, matchedMenu);
                themeByStore.put(identity, theme.label());
                reasonByStore.put(identity, theme.reason());
            }
        }
        return matched;
    }

    /** 가까운 순 상위 limit개를 반환한다. 위치가 있을 때는 maxRadiusMeters 이내 매장만 필터링한다. */
   private List<Map<String, Object>> nearestShuffled(List<Map<String, Object>> pool,
                                                      Double lat, Double lng, int limit, long seed,
                                                      double maxRadiusMeters) {
        List<Map<String, Object>> scored = new ArrayList<>();
       if (lat != null && lng != null) {
            for (Map<String, Object> store : pool) {
                double distance = haversine(lat, lng, parseLat(store), parseLng(store));
                if (Double.isFinite(distance) && distance <= maxRadiusMeters) {
                    scored.add(store);
                }
            }
           scored.sort((a, b) -> Double.compare(
                   haversine(lat, lng, parseLat(a), parseLng(a)),
                   haversine(lat, lng, parseLat(b), parseLng(b))));
       }
        else {
            scored.addAll(pool);
        }
       if (scored.size() > limit) {
            scored = new ArrayList<>(scored.subList(0, limit));
        }
        if (lat == null || lng == null) {
            Collections.shuffle(scored, new Random(seed));
        }
        return scored;
    }

    /** 중복 매장명 없이 후보에서 최대 count개 추가 */
    private void addUnique(List<Map<String, Object>> chosen, List<Map<String, Object>> candidates,
                           int count, Set<String> seenNames) {
        int added = 0;
        for (Map<String, Object> store : candidates) {
            if (added >= count) break;
            String identity = strOrNull(store.get("storeId"));
            if (identity == null || !seenNames.add(identity)) continue;
            chosen.add(store);
            added++;
        }
    }

    /**
     * 매장의 메뉴(menu1~menu4) 중 추천 키워드를 포함하는 "첫 번째 실제 메뉴"를 반환.
     * 없으면 null. 카드에는 menu1 대신 이 매칭된 메뉴를 보여줘 추천 근거와 일치시킨다.
     */
    private String findMatchedMenu(Map<String, Object> store, PickTheme theme) {
        boolean warm = theme.label().contains("따뜻") || theme.label().equals("이열치열");
        for (int slot = 1; slot <= 4; slot++) {
            String menu = strOrNull(store.get("menu" + slot));
            if (menu == null || menu.isBlank() || WonPrice.menuMinimum(store.get("price" + slot),
                    Boolean.TRUE.equals(store.get("free" + slot))) == null) continue;
            if (warm && List.of("비빔", "냉", "볶음", "김밥").stream().anyMatch(menu::contains)) continue;
            for (String kw : theme.keywords()) {
                if (menu.contains(kw)) {
                    return menu;
                }
            }
        }
        return null;
    }

    private String firstPricedMenu(Map<String, Object> store) {
        for (int slot = 1; slot <= 4; slot++) {
            String menu = strOrNull(store.get("menu" + slot));
            if (menu != null && !menu.isBlank() && WonPrice.menuMinimum(store.get("price" + slot),
                    Boolean.TRUE.equals(store.get("free" + slot))) != null) return menu;
        }
        return null;
    }

    /** 하버사인 거리 (미터) */
    private double haversine(double lat1, double lng1, double lat2, double lng2) {
        double R = 6371000;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLng = Math.toRadians(lng2 - lng1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                * Math.sin(dLng / 2) * Math.sin(dLng / 2);
        return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    }

    private double parseLat(Map<String, Object> store) {
        try {
            return Double.parseDouble(String.valueOf(store.get("latitude")));
        } catch (Exception e) {
            return Double.NaN;
        }
    }

    private double parseLng(Map<String, Object> store) {
        try {
            return Double.parseDouble(String.valueOf(store.get("longitude")));
        } catch (Exception e) {
            return Double.NaN;
        }
    }

    private boolean hasValidStoreCoordinate(Map<String, Object> store) {
        return isValidCoordinate(parseLat(store), parseLng(store));
    }

    private boolean isValidCoordinate(Double lat, Double lng) {
        return lat != null && lng != null
                && Double.isFinite(lat) && Double.isFinite(lng)
                && lat >= -90 && lat <= 90
                && lng >= -180 && lng <= 180;
    }

    // ==================== 커뮤니티 댓글/좋아요/알림 (comments, feed_likes, feed_notifications) ====================

    /** 제보(게시글)가 존재하고 공개 가능한지 확인. 없거나 REJECTED면 false */
    public boolean feedExists(String postId) {
        try {
            DocumentSnapshot doc = db.collection("stores_user").document(postId).get().get();
            if (!doc.exists()) return false;
            Map<String, Object> data = doc.getData();
            return data != null && isFeedVisible(data);
        } catch (Exception e) {
            return false;
        }
    }

    /** 게시글의 comments/likes 카운터를 실제 컬렉션 기준으로 다시 계산해 저장 (요청 #6 최신화) */
    private void syncFeedCounts(String postId) {
        boolean cacheUpdated = false;
        try {
            long commentCount = db.collection("comments")
                    .whereEqualTo("postId", postId).count().get().get().getCount();
            long likeCount = db.collection("feed_likes")
                    .whereEqualTo("postId", postId).count().get().get().getCount();
            Map<String, Object> updates = new HashMap<>();
            updates.put("comments", Math.toIntExact(commentCount));
            updates.put("likes", Math.toIntExact(likeCount));
            db.collection("stores_user").document(postId).update(updates).get();
            cacheUpdated = updateCachedFeedCounts(postId, Math.toIntExact(likeCount), Math.toIntExact(commentCount));
        } catch (Exception e) {
            log.warn("커뮤니티 카운터 동기화 실패: postId={}", postId, e);
        } finally {
            // 숫자를 확정하지 못했을 때만 캐시 전체를 버립니다.
            if (!cacheUpdated) invalidateCommunityFeedCache();
        }
    }

    /**
     * 좋아요·댓글 수만 바뀐 경우 피드 캐시 전체를 버리지 않고 그 글의 숫자만 고칩니다(BE-CORE-16).
     * 캐시를 버리면 다음 피드 조회가 최대 수백 건의 제보와 작성자 정보를 다시 읽기 때문입니다.
     */
    private boolean updateCachedFeedCounts(String postId, int likes, int comments) {
        synchronized (feedsCacheLock) {
            List<com.howmuch.dto.FeedResponseDto> cached = cachedFeeds;
            if (cached == null) return true;
            List<com.howmuch.dto.FeedResponseDto> next = new ArrayList<>(cached.size());
            for (com.howmuch.dto.FeedResponseDto feed : cached) {
                next.add(postId.equals(feed.getId())
                        ? feed.toBuilder().likes(likes).comments(comments).build()
                        : feed);
            }
            cachedFeeds = List.copyOf(next);
            return true;
        }
    }

    private static final String COMMUNITY_AUTHOR_UNKNOWN = "알 수 없음";
    private static final String COMMUNITY_AUTHOR_ANONYMOUS = "익명";

    /** publicProfile은 닉네임 공개 회원이라 프로필 사진을 보여도 되는지를 뜻합니다. */
    private record AuthorSnapshot(String nickname, String profileImageUrl, boolean publicProfile) {
        static AuthorSnapshot unknown() { return new AuthorSnapshot(COMMUNITY_AUTHOR_UNKNOWN, null, false); }
    }

    /**
     * 계약 C8: 닉네임 비공개(nicknamePublic=false) 회원은 커뮤니티 글·댓글·답글에서 "익명"으로,
     * 프로필 사진 없이 보입니다. 회원 정보가 없거나 조회에 실패하면 "알 수 없음"입니다.
     */
    private AuthorSnapshot resolveAuthorSnapshot(String uid) {
        if (uid == null || uid.isBlank()) return AuthorSnapshot.unknown();
        try {
            com.howmuch.dto.UserProfileResponse user = getUserProfile(uid);
            if (user != null) {
                if (Boolean.FALSE.equals(user.getNicknamePublic())) {
                    return new AuthorSnapshot(COMMUNITY_AUTHOR_ANONYMOUS, null, false);
                }
                String nickname = (user.getNickname() != null && !user.getNickname().isBlank())
                        ? user.getNickname()
                        : COMMUNITY_AUTHOR_UNKNOWN;
                String img = (user.getProfileImageUrl() != null && !user.getProfileImageUrl().isBlank())
                        ? user.getProfileImageUrl()
                        : null;
                return new AuthorSnapshot(nickname, img, true);
            }
        } catch (Exception e) {
            // ignore
        }
        return AuthorSnapshot.unknown();
    }

    /** 피드 작성자 표시. 공개 회원이 프로필 사진이 없을 때만 예전 제보에 남은 사진을 씁니다. */
    private AuthorSnapshot feedAuthor(Map<String, Object> data, Map<String, AuthorSnapshot> authorCache) {
        String reporterId = strOrNull(data.get("reporterId"));
        AuthorSnapshot author = reporterId == null || reporterId.isBlank()
                ? AuthorSnapshot.unknown()
                : authorCache.computeIfAbsent(reporterId, this::resolveAuthorSnapshot);
        if (author.publicProfile() && author.profileImageUrl() == null) {
            String legacyImage = strOrNull(data.get("reporterProfileImageUrl"));
            if (legacyImage != null && !legacyImage.isBlank()) {
                return new AuthorSnapshot(author.nickname(), legacyImage, true);
            }
        }
        return author;
    }

    /** 계약 C2: 피드 가격 변동 유형은 rise·drop·new·delete만 내보내고 나머지는 null입니다. */
    private static String feedChangeType(Object value) {
        String changeType = blankToNull(value);
        if (changeType == null) return null;
        String normalized = changeType.toLowerCase(java.util.Locale.ROOT);
        return List.of("rise", "drop", "new", "delete").contains(normalized) ? normalized : null;
    }

    /** 문서 스냅샷 → CommentResponse 변환 */
    private com.howmuch.dto.CommentResponse toCommentResponse(
            DocumentSnapshot doc,
            String requesterUid,
            Map<String, AuthorSnapshot> authorCache) {
        Map<String, Object> data = doc.getData();
        if (data == null) data = new HashMap<>();
        String uid = data.get("userId") != null ? data.get("userId").toString() : null;
        String content = data.get("content") != null ? data.get("content").toString() : "";
        String createdAt = data.get("createdAt") != null ? data.get("createdAt").toString() : "";
        boolean isMine = requesterUid != null && requesterUid.equals(uid);
        int replyCount = 0;
        Object rc = data.get("replyCount");
        if (rc != null) {
            try { replyCount = Integer.parseInt(rc.toString()); } catch (NumberFormatException ignored) {}
        }
        AuthorSnapshot authorInfo = uid == null
                ? AuthorSnapshot.unknown()
                : authorCache.computeIfAbsent(uid, this::resolveAuthorSnapshot);
        return com.howmuch.dto.CommentResponse.builder()
                .id(doc.getId())
                .author(authorInfo.nickname())
                .authorProfileImageUrl(authorInfo.profileImageUrl())
                .content(content)
                .createdAt(createdAt)
                .isMine(isMine)
                .replyCount(replyCount)
                .build();
    }

    // 💡 댓글 목록 조회 (최상위 댓글만, parentId 없음). 오래된순
    public List<com.howmuch.dto.CommentResponse> getComments(String postId, String requesterUid) throws Exception {
        List<DocumentSnapshot> docs = new ArrayList<>(db.collection("comments")
                .whereEqualTo("postId", postId)
                .whereEqualTo("parentId", null)
                .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.ASCENDING)
                .limit(MAX_COMMUNITY_COMMENTS)
                .get().get().getDocuments());
        List<com.howmuch.dto.CommentResponse> result = new ArrayList<>();
        Map<String, AuthorSnapshot> authorCache = new HashMap<>();
        for (DocumentSnapshot doc : docs) {
            result.add(toCommentResponse(doc, requesterUid, authorCache));
        }
        return result;
    }

    // 💡 댓글 작성
    public com.howmuch.dto.CommentResponse createComment(String postId, String requesterUid, String content) throws Exception {
        DocumentReference docRef = db.collection("comments").document();
        String createdAt = java.time.Instant.now().toString();
        Map<String, Object> data = new HashMap<>();
        data.put("postId", postId);
        data.put("userId", requesterUid);
        data.put("content", content);
        data.put("createdAt", createdAt);
        data.put("replyCount", 0);
        data.put("parentId", null);
        docRef.set(data).get();
        syncFeedCounts(postId);
        notifyFeedCommentSubscribers(postId, docRef.getId(), requesterUid, false);
        AuthorSnapshot authorInfo = resolveAuthorSnapshot(requesterUid);
        return com.howmuch.dto.CommentResponse.builder()
                .id(docRef.getId())
                .author(authorInfo.nickname())
                .authorProfileImageUrl(authorInfo.profileImageUrl())
                .content(content)
                .createdAt(createdAt)
                .isMine(true)
                .replyCount(0)
                .build();
    }

    // 💡 답글 목록 조회 (오래된순)
    public List<com.howmuch.dto.CommentResponse> getReplies(String commentId, String requesterUid) throws Exception {
        List<DocumentSnapshot> docs = new ArrayList<>(db.collection("comments")
                .whereEqualTo("parentId", commentId)
                .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.ASCENDING)
                .limit(MAX_COMMUNITY_REPLIES)
                .get().get().getDocuments());
        List<com.howmuch.dto.CommentResponse> result = new ArrayList<>();
        Map<String, AuthorSnapshot> authorCache = new HashMap<>();
        for (DocumentSnapshot doc : docs) {
            result.add(toCommentResponse(doc, requesterUid, authorCache));
        }
        return result;
    }

    /** 답글 조회·작성 전에 부모 댓글과 공개 게시글의 연결을 확인합니다. */
    public boolean commentBelongsToVisibleFeed(String commentId) throws Exception {
        if (commentId == null || commentId.isBlank()) return false;
        DocumentSnapshot comment = db.collection("comments").document(commentId).get().get();
        if (!comment.exists()) return false;
        Map<String, Object> data = comment.getData();
        if (data == null || data.get("parentId") != null) return false;
        Object postId = data.get("postId");
        return postId != null && feedExists(postId.toString());
    }

    // 💡 답글 작성 (부모 댓글 replyCount 증가 + 게시글 comments 갱신)
    public com.howmuch.dto.CommentResponse createReply(String commentId, String requesterUid, String content) throws Exception {
        DocumentSnapshot parent = db.collection("comments").document(commentId).get().get();
        if (!parent.exists()) return null;
        Map<String, Object> parentData = parent.getData();
        if (parentData == null || parentData.get("parentId") != null) return null;
        String postId = parentData != null && parentData.get("postId") != null ? parentData.get("postId").toString() : null;
        if (postId == null || !feedExists(postId)) return null;

        DocumentReference docRef = db.collection("comments").document();
        String createdAt = java.time.Instant.now().toString();
        Map<String, Object> data = new HashMap<>();
        data.put("postId", postId);
        data.put("userId", requesterUid);
        data.put("content", content);
        data.put("createdAt", createdAt);
        data.put("parentId", commentId);
        data.put("replyCount", 0);
        // Save the reply and increment its parent's count atomically. Concurrent
        // replies must not overwrite each other's counts or leave orphan writes.
        var batch = db.batch();
        batch.set(docRef, data);
        batch.update(db.collection("comments").document(commentId),
                "replyCount", com.google.cloud.firestore.FieldValue.increment(1L));
        batch.commit().get();

        if (postId != null) syncFeedCounts(postId);
        notifyFeedCommentSubscribers(postId, docRef.getId(), requesterUid, true);

        AuthorSnapshot authorInfo = resolveAuthorSnapshot(requesterUid);
        return com.howmuch.dto.CommentResponse.builder()
                .id(docRef.getId())
                .author(authorInfo.nickname())
                .authorProfileImageUrl(authorInfo.profileImageUrl())
                .content(content)
                .createdAt(createdAt)
                .isMine(true)
                .replyCount(0)
                .build();
    }

    // 💡 좋아요 추가 (멱등: uid_postId docId로 중복 방지). 최신 likes/likedByMe 반환
    public Map<String, Object> likeFeed(String postId, String uid) throws Exception {
        String docId = uid + "_" + sanitizeForDocId(postId);
        Map<String, Object> data = new HashMap<>();
        data.put("userId", uid);
        data.put("postId", postId);
        data.put("createdAt", java.time.Instant.now().toString());
        db.collection("feed_likes").document(docId).set(data).get();
        syncFeedCounts(postId);
        int likes = getLikeCount(postId);
        Map<String, Object> result = new HashMap<>();
        result.put("likes", likes);
        result.put("likedByMe", true);
        return result;
    }

    // 💡 좋아요 취소 (멱등). 최신 likes/likedByMe 반환
    public Map<String, Object> unlikeFeed(String postId, String uid) throws Exception {
        String docId = uid + "_" + sanitizeForDocId(postId);
        db.collection("feed_likes").document(docId).delete().get();
        syncFeedCounts(postId);
        int likes = getLikeCount(postId);
        Map<String, Object> result = new HashMap<>();
        result.put("likes", likes);
        result.put("likedByMe", false);
        return result;
    }

    private int getLikeCount(String postId) throws Exception {
        long count = db.collection("feed_likes").whereEqualTo("postId", postId)
                .count().get().get().getCount();
        return Math.toIntExact(count);
    }

    /** 게시글 작성자와 알림 구독자에게 새 댓글/답글 알림을 남깁니다. */
    private void notifyFeedCommentSubscribers(
            String postId,
            String commentId,
            String actorUid,
            boolean reply) {
        try {
            DocumentSnapshot post = db.collection("stores_user").document(postId).get().get();
            Map<String, Object> postData = post.getData();
            if (!post.exists() || postData == null || !isFeedVisible(postData)) return;

            Set<String> recipients = new LinkedHashSet<>();
            String reporterId = post.getString("reporterId");
            if (reporterId != null && !reporterId.isBlank()) recipients.add(reporterId);
            for (DocumentSnapshot subscription : db.collection("feed_notifications")
                    .whereEqualTo("postId", postId).get().get().getDocuments()) {
                String userId = subscription.getString("userId");
                if (userId != null && !userId.isBlank()) recipients.add(userId);
            }
            recipients.remove(actorUid);

            String createdAt = java.time.Instant.now().toString();
            String title = reply ? "새로운 답글" : "새로운 댓글";
            String body = reply
                    ? "알림 설정한 게시글에 새로운 답글이 달렸습니다."
                    : "알림 설정한 게시글에 새로운 댓글이 달렸습니다.";
            for (String userId : recipients) {
                String notificationId = "feed_comment_"
                        + sanitizeForDocId(commentId) + "_" + sanitizeForDocId(userId);
                DocumentReference notification = db.collection("notifications").document(notificationId);
                if (notification.get().get().exists()) continue;
                Map<String, Object> data = new HashMap<>();
                data.put("userId", userId);
                data.put("title", title);
                data.put("body", body);
                data.put("type", "FEED_COMMENT");
                data.put("isRead", false);
                data.put("createdAt", createdAt);
                data.put("relatedPostId", postId);
                data.put("relatedCommentId", commentId);
                notification.set(data).get();
                dispatchPushNotification(userId, notificationId, title, body, "FEED_COMMENT");
            }
        } catch (Exception e) {
            // 댓글 저장은 이미 완료됐으므로 알림 장애로 작성 요청을 실패시키지 않습니다.
            log.warn("커뮤니티 댓글 알림 생성 실패: postId={}, commentId={}", postId, commentId, e);
        }
    }

    private boolean isFeedLikedBy(String postId, String uid) throws Exception {
        if (uid == null || uid.isBlank()) return false;
        String docId = uid + "_" + sanitizeForDocId(postId);
        return db.collection("feed_likes").document(docId).get().get().exists();
    }

    private boolean isFeedNotificationEnabled(String postId, String uid) throws Exception {
        if (uid == null || uid.isBlank()) return false;
        String docId = uid + "_" + sanitizeForDocId(postId);
        return db.collection("feed_notifications").document(docId).get().get().exists();
    }

    // 💡 게시글 알림 구독 (멱등)
    public Map<String, Object> subscribeFeedNotification(String postId, String uid) throws Exception {
        String docId = uid + "_" + sanitizeForDocId(postId);
        Map<String, Object> data = new HashMap<>();
        data.put("userId", uid);
        data.put("postId", postId);
        data.put("createdAt", java.time.Instant.now().toString());
        db.collection("feed_notifications").document(docId).set(data).get();
        Map<String, Object> result = new HashMap<>();
        result.put("notificationEnabled", true);
        return result;
    }

    // 💡 게시글 알림 구독 해제 (멱등)
    public Map<String, Object> unsubscribeFeedNotification(String postId, String uid) throws Exception {
        String docId = uid + "_" + sanitizeForDocId(postId);
        db.collection("feed_notifications").document(docId).delete().get();
        Map<String, Object> result = new HashMap<>();
        result.put("notificationEnabled", false);
        return result;
    }

    // ==================== 알림함 (notifications) — 지환 5주차 과제 선별 이식 ====================

    // 💡 내 알림 목록 조회 (최신순)
    public List<com.howmuch.dto.NotificationResponseDto> getNotifications(String firebaseUid) throws Exception {
        var documents = db.collection("notifications")
                .whereEqualTo("userId", firebaseUid)
                .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.DESCENDING)
                .limit(MAX_NOTIFICATION_RESULTS)
                .get().get().getDocuments();

        List<com.howmuch.dto.NotificationResponseDto> notifications = new ArrayList<>();
        for (DocumentSnapshot doc : documents) {
            Map<String, Object> data = doc.getData();
            if (data == null) continue;

            Boolean isRead = parseBooleanSafely(data.get("isRead"));

            notifications.add(com.howmuch.dto.NotificationResponseDto.builder()
                    .id(doc.getId())
                    .title(data.get("title") != null ? data.get("title").toString() : "")
                    .body(data.get("body") != null ? data.get("body").toString() : "")
                    .type(data.get("type") != null ? data.get("type").toString() : "")
                    .isRead(isRead != null ? isRead : false)
                    .createdAt(data.get("createdAt") != null ? data.get("createdAt").toString() : "")
                    .relatedPostId(blankToNull(data.get("relatedPostId")))
                    .relatedReportId(blankToNull(data.get("relatedReportId")))
                    .storeId(blankToNull(data.get("storeId")))
                    .build());
        }

        // 방어적으로 정렬·상한을 한 번 더 적용해 emulator/mock 결과도 동일하게 유지합니다.
        notifications.sort((a, b) -> {
            String aTime = a.getCreatedAt() != null ? a.getCreatedAt() : "";
            String bTime = b.getCreatedAt() != null ? b.getCreatedAt() : "";
            return bTime.compareTo(aTime);
        });
        return notifications.size() <= MAX_NOTIFICATION_RESULTS
                ? notifications
                : List.copyOf(notifications.subList(0, MAX_NOTIFICATION_RESULTS));
    }

    // 💡 알림 읽음 처리 (본인 알림만 가능 — 다른 유저 알림이면 거부)
    public void markNotificationAsRead(String notificationId, String firebaseUid) throws Exception {
        if (notificationId == null || notificationId.isBlank()
                || notificationId.length() > 512 || notificationId.contains("/")) {
            throw new IllegalArgumentException("알림 ID 형식이 올바르지 않습니다.");
        }
        if (firebaseUid == null || firebaseUid.isBlank()) {
            throw new IllegalArgumentException("인증 정보가 유효하지 않습니다.");
        }
        DocumentReference docRef = db.collection("notifications").document(notificationId);
        DocumentSnapshot document = docRef.get().get();

        if (!document.exists()) {
            throw new IllegalArgumentException("알림이 존재하지 않습니다: " + notificationId);
        }
        String ownerId = document.getString("userId");
        if (!firebaseUid.equals(ownerId)) {
            throw new IllegalArgumentException("본인 알림만 읽음 처리할 수 있습니다.");
        }
        docRef.update("isRead", true).get();
    }

    private static final int MAX_MARK_ALL_READ = 500;

    /**
     * 계약 C3: 본인의 읽지 않은 알림을 한 번에 읽음 처리합니다(한 번에 최대 500건, 단일 배치).
     * 남은 알림이 있으면 앱이 다시 호출하면 됩니다.
     */
    public int markAllNotificationsAsRead(String firebaseUid) throws Exception {
        if (firebaseUid == null || firebaseUid.isBlank()) {
            throw new IllegalArgumentException("인증 정보가 유효하지 않습니다.");
        }
        var unread = db.collection("notifications")
                .whereEqualTo("userId", firebaseUid)
                .whereEqualTo("isRead", false)
                .limit(MAX_MARK_ALL_READ)
                .get().get().getDocuments();
        if (unread.isEmpty()) return 0;
        WriteBatch batch = db.batch();
        int updated = 0;
        for (DocumentSnapshot notification : unread) {
            // 쿼리 결과라도 소유자를 다시 확인해 다른 사용자의 알림은 건드리지 않습니다.
            if (!firebaseUid.equals(notification.getString("userId"))) continue;
            batch.update(notification.getReference(), "isRead", true);
            updated++;
        }
        if (updated > 0) batch.commit().get();
        return updated;
    }

    /** 로그인한 기기의 FCM 토큰을 사용자에게 연결합니다. 토큰은 SHA-256 문서 ID로 저장합니다. */
    public void registerDeviceToken(String firebaseUid, String token, String platform) throws Exception {
        if (token == null || token.isBlank() || token.length() > 4096) {
            throw new IllegalArgumentException("기기 토큰 형식이 올바르지 않습니다.");
        }
        if (!"android".equals(platform) && !"ios".equals(platform)) {
            throw new IllegalArgumentException("지원하지 않는 기기 종류입니다.");
        }

        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("token", token);
        data.put("platform", platform);
        data.put("updatedAt", java.time.Instant.now().toString());
        db.collection("device_tokens").document(deviceTokenDocumentId(token)).set(data).get();
    }

    /** 로그아웃 시 본인에게 속한 현재 기기 토큰만 해제합니다. */
    public void unregisterDeviceToken(String firebaseUid, String token) throws Exception {
        if (token == null || token.isBlank()) return;

        DocumentReference reference = db.collection("device_tokens")
                .document(deviceTokenDocumentId(token));
        DocumentSnapshot document = reference.get().get();
        if (document.exists() && firebaseUid.equals(document.getString("userId"))) {
            reference.delete().get();
        }
    }

    public NotificationSettingsDto getNotificationSettings(String firebaseUid) throws Exception {
        DocumentSnapshot document = db.collection("notification_settings")
                .document(firebaseUid)
                .get().get();
        if (!document.exists()) {
            return defaultNotificationSettings();
        }

        Map<String, Object> data = document.getData();
        NotificationSettingsDto defaults = defaultNotificationSettings();
        return NotificationSettingsDto.builder()
                .all(booleanOrDefault(data, "all", defaults.getAll()))
                .review(booleanOrDefault(data, "review", defaults.getReview()))
                .report(booleanOrDefault(data, "report", defaults.getReport()))
                .price(booleanOrDefault(data, "price", defaults.getPrice()))
                .todayPick(booleanOrDefault(data, "todayPick", defaults.getTodayPick()))
                .notifyOnRise(booleanOrDefault(data, "notifyOnRise",
                        Boolean.TRUE.equals(defaults.getNotifyOnRise())))
                .notifyOnDrop(booleanOrDefault(data, "notifyOnDrop",
                        Boolean.TRUE.equals(defaults.getNotifyOnDrop())))
                .notifyOnNewMenu(booleanOrDefault(data, "notifyOnNewMenu",
                        Boolean.TRUE.equals(defaults.getNotifyOnNewMenu())))
                .quietHours(booleanOrDefault(data, "quietHours", defaults.getQuietHours()))
                .quietStart(stringOrDefault(data, "quietStart", defaults.getQuietStart()))
                .quietEnd(stringOrDefault(data, "quietEnd", defaults.getQuietEnd()))
                .build();
    }

    public NotificationSettingsDto saveNotificationSettings(
            String firebaseUid,
            NotificationSettingsDto requested) throws Exception {
        DocumentSnapshot existing = db.collection("notification_settings")
                .document(firebaseUid).get().get();
        NotificationSettingsDto defaults = defaultNotificationSettings();
        boolean allEnabled = Boolean.TRUE.equals(requested.getReview())
                && Boolean.TRUE.equals(requested.getReport())
                && Boolean.TRUE.equals(requested.getPrice())
                && Boolean.TRUE.equals(requested.getTodayPick());
        NotificationSettingsDto normalized = NotificationSettingsDto.builder()
                .all(allEnabled)
                .review(requested.getReview())
                .report(requested.getReport())
                .price(requested.getPrice())
                .todayPick(requested.getTodayPick())
                .notifyOnRise(requested.getNotifyOnRise() != null
                        ? requested.getNotifyOnRise()
                        : booleanOrDefault(existing.getData(), "notifyOnRise",
                                Boolean.TRUE.equals(defaults.getNotifyOnRise())))
                .notifyOnDrop(requested.getNotifyOnDrop() != null
                        ? requested.getNotifyOnDrop()
                        : booleanOrDefault(existing.getData(), "notifyOnDrop",
                                Boolean.TRUE.equals(defaults.getNotifyOnDrop())))
                .notifyOnNewMenu(requested.getNotifyOnNewMenu() != null
                        ? requested.getNotifyOnNewMenu()
                        : booleanOrDefault(existing.getData(), "notifyOnNewMenu",
                                Boolean.TRUE.equals(defaults.getNotifyOnNewMenu())))
                .quietHours(requested.getQuietHours())
                .quietStart(requested.getQuietStart())
                .quietEnd(requested.getQuietEnd())
                .build();

        Map<String, Object> data = new HashMap<>();
        data.put("all", normalized.getAll());
        data.put("review", normalized.getReview());
        data.put("report", normalized.getReport());
        data.put("price", normalized.getPrice());
        data.put("todayPick", normalized.getTodayPick());
        if (requested.getNotifyOnRise() != null) data.put("notifyOnRise", normalized.getNotifyOnRise());
        if (requested.getNotifyOnDrop() != null) data.put("notifyOnDrop", normalized.getNotifyOnDrop());
        if (requested.getNotifyOnNewMenu() != null) data.put("notifyOnNewMenu", normalized.getNotifyOnNewMenu());
        data.put("quietHours", normalized.getQuietHours());
        data.put("quietStart", normalized.getQuietStart());
        data.put("quietEnd", normalized.getQuietEnd());
        data.put("updatedAt", java.time.Instant.now().toString());
        db.collection("notification_settings").document(firebaseUid).set(data, SetOptions.merge()).get();
        return normalized;
    }

    private NotificationSettingsDto defaultNotificationSettings() {
        return NotificationSettingsDto.builder()
                .all(true)
                .review(true)
                .report(true)
                .price(true)
                .todayPick(true)
                .notifyOnRise(true)
                .notifyOnDrop(true)
                .notifyOnNewMenu(false)
                .quietHours(false)
                .quietStart("22:00")
                .quietEnd("08:00")
                .build();
    }

    private boolean booleanOrDefault(
            Map<String, Object> data,
            String key,
            boolean defaultValue) {
        Boolean value = parseBooleanSafely(data != null ? data.get(key) : null);
        return value != null ? value : defaultValue;
    }

    private String stringOrDefault(
            Map<String, Object> data,
            String key,
            String defaultValue) {
        Object value = data != null ? data.get(key) : null;
        return value != null && !value.toString().isBlank()
                ? value.toString()
                : defaultValue;
    }

    // ==================== 어드민: 댓글·알림·통계 ====================

    // 💡 [어드민] 전체 댓글/답글 목록 (최신순) — 부적절 댓글 모더레이션용
    public List<Map<String, Object>> getAllComments() throws Exception {
        List<Map<String, Object>> comments = new ArrayList<>(db.collection("comments")
                .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.DESCENDING)
                .limit(adminListLimit()).get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = doc.getData();
                    Map<String, Object> item = new HashMap<>();
                    item.put("id", doc.getId());
                    item.put("postId", data.get("postId"));
                    item.put("userId", data.get("userId"));
                    item.put("content", data.get("content"));
                    item.put("createdAt", data.get("createdAt"));
                    item.put("parentId", data.get("parentId"));
                    item.put("isReply", data.get("parentId") != null);
                    return item;
                })
                .toList());
        return comments;
    }

    // 💡 [어드민] 댓글/답글 삭제 — 답글이면 부모 댓글 replyCount 감소, 댓글이면 답글도 함께 삭제 + 게시글 카운터 갱신
    public void deleteComment(String commentId) throws Exception {
        DocumentReference docRef = db.collection("comments").document(commentId);
        DocumentSnapshot doc = docRef.get().get();
        if (!doc.exists()) {
            throw new IllegalArgumentException("댓글을 찾을 수 없습니다: " + commentId);
        }
        Map<String, Object> data = doc.getData();
        String postId = data != null && data.get("postId") != null ? data.get("postId").toString() : null;
        Object parentId = data != null ? data.get("parentId") : null;

        // 댓글이면 소속 답글 전부 삭제
        List<String> deletedCommentIds = new ArrayList<>();
        deletedCommentIds.add(commentId);
        if (parentId == null) {
            var replies = db.collection("comments").whereEqualTo("parentId", commentId).get().get().getDocuments();
            for (DocumentSnapshot reply : replies) {
                reply.getReference().delete().get();
                deletedCommentIds.add(reply.getId());
            }
        }
        docRef.delete().get();

        // BE-CORE-11: 답글이면 부모 댓글 답글 수를 읽고-쓰기 대신 실제 개수로 다시 세어 동시 작성과 경쟁하지 않게 합니다.
        if (parentId != null) recountReplies(parentId.toString());
        deleteCommentNotifications(deletedCommentIds);
        // 게시글 comments/likes 카운터 갱신
        if (postId != null) syncFeedCounts(postId);
    }

    // 💡 [어드민] 알림 발송 — 특정 유저 1명 또는 전체 유저에게 notifications 문서 생성
    public Map<String, Object> sendAdminNotification(String targetUid, String title, String body, String type) throws Exception {
        return sendAdminNotification(targetUid, title, body, type, null);
    }

    /** requestId가 있으면 같은 요청을 다시 보내도 회원마다 한 번만 알림이 생깁니다(WEB-ADM-2). */
    public Map<String, Object> sendAdminNotification(
            String targetUid, String title, String body, String type, String requestId) throws Exception {
        return sendAdminMessage(targetUid, title, body,
                type != null && !type.isBlank() ? type : "general", true, requestId);
    }

    // 공지는 전체 회원의 알림함/웹 접속 팝업에만 등록하고 기기 푸시는 보내지 않습니다.
    public Map<String, Object> publishAdminNotice(String title, String body) throws Exception {
        return publishAdminNotice(title, body, null);
    }

    public Map<String, Object> publishAdminNotice(String title, String body, String requestId) throws Exception {
        return sendAdminMessage(null, title, body, "notice", false, requestId);
    }

    /** 관리자 발송 요청 ID 형식(재시도 시 같은 값을 다시 보냅니다). */
    public static boolean isValidAdminRequestId(String requestId) {
        return requestId != null && requestId.matches("[A-Za-z0-9_-]{8,64}");
    }

    private Map<String, Object> sendAdminMessage(
            String targetUid,
            String title,
            String body,
            String type,
            boolean deliverPush,
            String requestId) throws Exception {
        if (requestId != null && !isValidAdminRequestId(requestId)) {
            throw new IllegalArgumentException("요청 ID 형식이 올바르지 않습니다.");
        }
        String createdAt = java.time.Instant.now().toString();
        int sent = 0;
        int skipped = 0;
        List<String> targetUids = new ArrayList<>();
        if (targetUid != null && !targetUid.isBlank()) {
            String normalizedTargetUid = targetUid.trim();
            DocumentSnapshot targetUser = db.collection("users")
                    .document(normalizedTargetUid)
                    .get().get();
            if (!targetUser.exists()) {
                throw new IllegalArgumentException("대상 회원을 찾을 수 없습니다.");
            }
            targetUids.add(normalizedTargetUid);
        } else {
            // 전체 발송: users 전체
            for (DocumentSnapshot u : db.collection("users").get().get().getDocuments()) {
                targetUids.add(u.getId());
            }
        }
        for (String uid : targetUids) {
            if (requestId == null) {
                createNotificationForUser(uid, title, body, type, createdAt, deliverPush);
                sent++;
                continue;
            }
            // BE-CORE-23: 요청 ID와 회원으로 정한 문서 ID라 시간 초과 뒤 재요청해도 이미 받은 회원은 건너뜁니다.
            String notificationId = "admin_" + requestId + "_" + sha256Hex(uid).substring(0, 24);
            if (createNotificationIfAbsent(notificationId, uid, title, body, type, createdAt, deliverPush)) sent++;
            else skipped++;
        }
        Map<String, Object> result = new HashMap<>();
        result.put("sent", sent);
        result.put("skipped", skipped);
        result.put("broadcast", targetUid == null || targetUid.isBlank());
        if (requestId != null) result.put("requestId", requestId);
        return result;
    }

    /** 결정적 문서 ID로 알림을 한 번만 만듭니다. 이미 있으면 false입니다. */
    private boolean createNotificationIfAbsent(
            String notificationId,
            String userId,
            String title,
            String body,
            String type,
            String createdAt,
            boolean deliverPush) throws Exception {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", userId);
        data.put("title", title);
        data.put("body", body);
        data.put("type", type);
        data.put("isRead", false);
        data.put("createdAt", createdAt);
        try {
            db.collection("notifications").document(notificationId).create(data).get();
        } catch (ExecutionException exception) {
            if (isAlreadyExists(exception)) return false;
            throw exception;
        }
        if (deliverPush) dispatchPushNotification(userId, notificationId, title, body, type);
        return true;
    }

    private void createNotificationForUser(
            String userId,
            String title,
            String body,
            String type,
            String createdAt,
            boolean deliverPush) throws Exception {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", userId);
        data.put("title", title);
        data.put("body", body);
        data.put("type", type);
        data.put("isRead", false);
        data.put("createdAt", createdAt);
        DocumentReference notification = db.collection("notifications").document();
        notification.set(data).get();
        if (deliverPush) {
            dispatchPushNotification(userId, notification.getId(), title, body, type);
        }
    }

    /**
     * Firestore 알림 저장 후 FCM을 별도 전송합니다. 네트워크·APNs 오류는 알림함
     * 기록이나 문의 답변 같은 원래 작업을 실패시키지 않습니다.
     */
    private void dispatchPushNotification(
            String userId,
            String notificationId,
            String title,
            String body,
            String type) {
        try {
            if (!shouldDeliverPush(userId, type)) {
                return;
            }
            var devices = db.collection("device_tokens")
                    .whereEqualTo("userId", userId)
                    .get().get().getDocuments();
            for (DocumentSnapshot device : devices) {
                String token = device.getString("token");
                if (token == null || token.isBlank()) continue;

                Message message = Message.builder()
                        .setToken(token)
                        .setNotification(Notification.builder()
                                .setTitle(title)
                                .setBody(body)
                                .build())
                        .putData("notificationId", notificationId)
                        .putData("type", type)
                        .putData("route", "/notifications")
                        .setAndroidConfig(AndroidConfig.builder()
                                .setPriority(AndroidConfig.Priority.HIGH)
                                .setNotification(AndroidNotification.builder()
                                        .setChannelId("howmuch_notifications")
                                        .setSound("default")
                                        .build())
                                .build())
                        .setApnsConfig(ApnsConfig.builder()
                                .setAps(Aps.builder().setSound("default").build())
                                .build())
                        .build();
                try {
                    FirebaseMessaging.getInstance().send(message);
                } catch (FirebaseMessagingException e) {
                    if (e.getMessagingErrorCode() == MessagingErrorCode.UNREGISTERED
                            || e.getMessagingErrorCode() == MessagingErrorCode.INVALID_ARGUMENT) {
                        device.getReference().delete();
                    }
                    log.warn("FCM 발송 실패: code={}", e.getMessagingErrorCode());
                }
            }
        } catch (Exception e) {
            log.warn("FCM 기기 조회 또는 발송 실패", e);
        }
    }

    /** 알림 설정과 방해 금지 시간을 푸시에도 동일하게 적용합니다. */
    private boolean shouldDeliverPush(String userId, String type) throws Exception {
        NotificationSettingsDto settings = getNotificationSettings(userId);
        if (!isPushTypeEnabled(settings, type)) {
            return false;
        }
        return !isQuietHoursNow(userId, settings);
    }

    private boolean isPushTypeEnabled(NotificationSettingsDto settings, String type) {
        String normalizedType = type == null ? "" : type.toUpperCase();
        // 계약 C3: 댓글·답글(FEED_COMMENT)과 리뷰 반응은 '리뷰 반응' 토글을 따릅니다.
        if (normalizedType.contains("FEED") || normalizedType.contains("COMMENT")
                || normalizedType.contains("REVIEW")) {
            return Boolean.TRUE.equals(settings.getReview());
        }
        // 제보 승인·반려(REPORT_*)와 문의 답변(INQUIRY_ANSWER)은 '제보 상태' 토글을 따릅니다.
        if (normalizedType.contains("REPORT") || normalizedType.contains("INQUIRY")) {
            return Boolean.TRUE.equals(settings.getReport());
        }
        if (normalizedType.contains("PRICE")) {
            return Boolean.TRUE.equals(settings.getPrice());
        }
        if (normalizedType.contains("TODAY")) {
            return Boolean.TRUE.equals(settings.getTodayPick());
        }
        // 운영 공지와 새 유형은 사용자가 모든 카테고리를 껐을 때만 막습니다.
        return Boolean.TRUE.equals(settings.getReview())
                || Boolean.TRUE.equals(settings.getReport())
                || Boolean.TRUE.equals(settings.getPrice())
                || Boolean.TRUE.equals(settings.getTodayPick());
    }

    private boolean isQuietHoursNow(String userId, NotificationSettingsDto settings) {
        if (!Boolean.TRUE.equals(settings.getQuietHours())) {
            return false;
        }
        try {
            LocalTime start = LocalTime.parse(settings.getQuietStart());
            LocalTime end = LocalTime.parse(settings.getQuietEnd());
            if (start.equals(end)) {
                return false;
            }
            LocalTime now = LocalTime.now(ZoneId.of("Asia/Seoul"));
            return start.isBefore(end)
                    ? !now.isBefore(start) && now.isBefore(end)
                    : !now.isBefore(start) || now.isBefore(end);
        } catch (Exception e) {
            log.warn("방해 금지 시간 형식이 올바르지 않아 푸시를 계속 전송합니다.");
            return false;
        }
    }

    private String deviceTokenDocumentId(String token) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(StandardCharsets.UTF_8));
            return java.util.HexFormat.of().formatHex(hash);
        } catch (Exception e) {
            throw new IllegalStateException("기기 토큰 식별자를 만들지 못했습니다.", e);
        }
    }

    // 💡 [어드민] 커뮤니티 활동 지표 — 댓글/좋아요/알림 수 (대시보드 확장용)
    public Map<String, Object> getCommunityStats() throws Exception {
        Map<String, Object> stats = new HashMap<>();
        stats.put("comments", countCollection("comments"));
        stats.put("feedLikes", countCollection("feed_likes"));
        stats.put("feedNotifications", countCollection("feed_notifications"));
        stats.put("notifications", countCollection("notifications"));
        return stats;
    }
}
