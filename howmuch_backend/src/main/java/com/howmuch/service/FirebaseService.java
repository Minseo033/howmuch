package com.howmuch.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.SetOptions;
import com.google.cloud.firestore.WriteResult;
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
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import jakarta.annotation.PostConstruct;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Random;
import java.util.Set;

@Slf4j
@Service
public class FirebaseService {

    private final Firestore db;
    private final ReportImageStorage reportImageStorage;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 착한가격업소(공공데이터) 인메모리 캐시.
     * Firestore 일일 읽기 한도(무료 5만) 보호를 위해 요청마다 읽지 않습니다.
     * volatile 참조 교체 방식이라 조회 중에도 안전합니다.
     */
    private volatile List<Map<String, Object>> cachedStores = List.of();

    /** 사용자 제보 매장 인메모리 캐시 (bounds 조회 시 Firestore 실시간 조회 제거) */
    private volatile List<Map<String, Object>> cachedUserStores = List.of();

    private static final int REPORT_IMAGE_MAX_COUNT = 3;
    private static final long REPORT_IMAGE_MAX_BYTES = 5L * 1024L * 1024L;

    /** 공공데이터 마지막 갱신 성공 시각 (24시간 가드: 1시간 주기 실행되지만 성공 후 24시간 내엔 Firestore 미호출) */
    private volatile long lastGovRefreshSuccessMillis = 0L;

    /** 스냅샷 파일 경로 (기본: 작업 디렉터리 data/stores-snapshot.json) */
    @Value("${stores.snapshot.path:data/stores-snapshot.json}")
    private String snapshotPath;

    public FirebaseService(Firestore db, ReportImageStorage reportImageStorage) {
        this.db = db;
        this.reportImageStorage = reportImageStorage;
    }

    @PostConstruct
    public void initAllStores() {
        // 1순위: 디스크 스냅샷 (같은 인스턴스 재시작 시 Firestore 읽기 0)
        if (loadGovStoresFromDisk()) {
            System.out.println("[캐시] 디스크 스냅샷에서 매장 " + cachedStores.size() + "개 로드");
        // 2순위: 리포지토리에 커밋된 classpath 스냅샷 (신규 인스턴스 콜드스타트 대비)
        } else if (loadGovStoresFromClasspath()) {
            System.out.println("[캐시] classpath 스냅샷에서 매장 " + cachedStores.size() + "개 로드");
        // 3순위: Firestore 로드 후 디스크에 영속화 (하루 1회 갱신 주기 내 최초 1회)
        } else {
            refreshGovStores();
        }
        // 사용자 제보 매장은 소량이므로 부팅 시 로드
        loadUserStoresFromFirestore();
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
                    System.out.println("[캐시] 메타 문서 기준 24시간 내 갱신 이력 있음 — 전량 갱신 건너뜀 (읽기 절약)");
                    return;
                }
            }
        } catch (Exception e) {
            // 메타 조회 실패(쿼터 초과 등) 시 전량 갱신 대신 이번 주기는 건너뜀 — 기존 캐시 유지
            System.err.println("[캐시] 갱신 메타 조회 실패, 이번 주기 갱신 건너뜀: " + e.getMessage());
            return;
        }
        try {
            System.out.println("[캐시] Firestore에서 공공데이터 매장 갱신 시도...");
            List<Map<String, Object>> stores = db.collection("stores")
                    .get().get().getDocuments().stream()
                    .map(DocumentSnapshot::getData)
                    .toList();
            if (!stores.isEmpty()) {
                cachedStores = List.copyOf(stores);
                lastGovRefreshSuccessMillis = System.currentTimeMillis();
                persistGovStoresSnapshot(stores);
                try {
                    db.collection(GOV_META_COLLECTION).document(GOV_META_DOC)
                            .set(Map.of("lastRefreshAt", lastGovRefreshSuccessMillis)).get();
                } catch (Exception metaEx) {
                    System.err.println("[캐시] 갱신 메타 저장 실패(무시 가능): " + metaEx.getMessage());
                }
                System.out.println("[캐시] 공공데이터 매장 갱신 완료: " + stores.size() + "개");
            } else {
                System.out.println("[캐시] Firestore 결과가 비어 있어 기존 캐시 유지");
            }
        } catch (Exception e) {
            // 쿼터 초과 등 실패 시 기존 캐시 유지 (서비스 무중단)
            System.err.println("[캐시] 공공데이터 매장 갱신 실패, 기존 캐시 유지: " + e.getMessage());
        }
    }

    /** 사용자 제보 매장 갱신: 시작 5분 후 + 10분 주기 (소량 컬렉션) */
    @Scheduled(initialDelayString = "${stores.user.refresh.initial-delay-ms:300000}",
            fixedDelayString = "${stores.user.refresh.delay-ms:600000}")
    public void refreshUserStores() {
        loadUserStoresFromFirestore();
    }

    private void loadUserStoresFromFirestore() {
        try {
            List<Map<String, Object>> userStores = db.collection("stores_user")
                    .get().get().getDocuments().stream()
                    .map(doc -> {
                        Map<String, Object> data = new HashMap<>(doc.getData());
                        data.put("id", doc.getId());
                        return data;
                    })
                    .toList();
            cachedUserStores = List.copyOf(userStores);
            System.out.println("[캐시] 사용자 제보 매장 로드 완료: " + userStores.size() + "개");
        } catch (Exception e) {
            System.err.println("[캐시] 사용자 제보 매장 로드 실패, 기존 캐시 유지: " + e.getMessage());
        }
    }

    private boolean loadGovStoresFromDisk() {
        try {
            Path path = Path.of(snapshotPath);
            if (!Files.exists(path) || Files.size(path) < 2) return false;
            List<Map<String, Object>> stores = readStoresJson(Files.newInputStream(path));
            if (stores.isEmpty()) return false;
            cachedStores = List.copyOf(stores);
            return true;
        } catch (Exception e) {
            System.err.println("[캐시] 디스크 스냅샷 로드 실패: " + e.getMessage());
            return false;
        }
    }

    private boolean loadGovStoresFromClasspath() {
        try {
            ClassPathResource resource = new ClassPathResource("stores-snapshot.json");
            if (!resource.exists()) return false;
            List<Map<String, Object>> stores = readStoresJson(resource.getInputStream());
            if (stores.isEmpty()) return false;
            cachedStores = List.copyOf(stores);
            return true;
        } catch (Exception e) {
            System.err.println("[캐시] classpath 스냅샷 로드 실패: " + e.getMessage());
            return false;
        }
    }

    @SuppressWarnings("unchecked")
    private List<Map<String, Object>> readStoresJson(InputStream in) throws Exception {
        try (in) {
            return objectMapper.readValue(in, List.class);
        }
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
            System.out.println("[캐시] 스냅샷 저장 완료: " + path.toAbsolutePath());
        } catch (Exception e) {
            System.err.println("[캐시] 스냅샷 저장 실패(읽기 전용 FS 등): " + e.getMessage());
        }
    }

    public List<Map<String, Object>> getAllStores() {
        return cachedStores.stream().map(this::withStableStoreId).toList();
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
        return cachedStores.stream()
                .<Map<String, Object>>map(HashMap::new)
                .sorted(stableOrder)
                .toList();
    }

    // 💡 화면 범위(Bounds) 기반 업소 조회 (정부 데이터 + 사용자 제보 통합, 전량 인메모리)
    public List<Map<String, Object>> getStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) {
        // 1. 정부 인증 업소 (Blue) - 메모리 캐시
        List<Map<String, Object>> govStores = cachedStores.stream()
                .filter(data -> isInBounds(data, minLat, maxLat, minLng, maxLng))
                .map(data -> {
                    Map<String, Object> map = withStableStoreId(data);
                    map.put("source", "GOV");
                    return map;
                })
                .limit(1000)
                .toList();

        // 2. 사용자 제보 업소 (Orange) - 메모리 캐시 (Firestore 실시간 조회 제거)
        // 💡 어드민 승인(APPROVED)된 제변이나, 승인제 도입 이전의 레거시 제보(status 없음)만 지도에 노출.
        //    PENDING(검토 중)·REJECTED(반려)는 공개 지도에서 제외합니다.
        List<Map<String, Object>> userStores = cachedUserStores.stream()
                .filter(this::isPubliclyVisible)
                .filter(data -> isInBounds(data, minLat, maxLat, minLng, maxLng))
                .map(data -> {
                    Map<String, Object> map = withStableStoreId(data);
                    map.put("source", "USER");
                    return map;
                })
                .limit(200)
                .toList();

        // 3. 통합 리스트 반환
        List<Map<String, Object>> combined = new ArrayList<>();
        combined.addAll(govStores);
        combined.addAll(userStores);
        return combined;
    }

    /**
     * 사용자 제보 매장이 공개 지도에 노출 가능한지 판별.
     * APPROVED(어드민 승인) 또는 status 필드가 없는 레거시 제볼만 true.
     */
    private boolean isPubliclyVisible(Map<String, Object> data) {
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
        if (report.getStoreId() == null || report.getStoreId().isBlank()) {
            report.setStoreId(stableStoreId(
                    report.getStoreName(), report.getAddress(), report.getPhoneNumber()));
        }
        report.setImageUrls(normalizeReportImageUrls(
                report.getReporterId(), report.getImageUrls(), Set.of()));

        DocumentReference docRef = db.collection("stores_user").document();
        @SuppressWarnings("unchecked")
        Map<String, Object> data = objectMapper.convertValue(report, Map.class);
        ApiFuture<WriteResult> future = docRef.set(report);
        future.get();

        data.put("id", docRef.getId());
        List<Map<String, Object>> updated = new ArrayList<>(cachedUserStores);
        updated.add(data);
        cachedUserStores = List.copyOf(updated);

        return docRef.getId();
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

        List<String> existingImageUrls = stringList(existing.get("imageUrls"));
        report.setReporterId(reporterUid);
        report.setStatus("PENDING");
        if (report.getStoreId() == null || report.getStoreId().isBlank()) {
            report.setStoreId(stableStoreId(
                    report.getStoreName(), report.getAddress(), report.getPhoneNumber()));
        }
        report.setCreatedAt(stringOrDefault(
                existing.getData(), "createdAt", java.time.Instant.now().toString()));
        report.setRejectReason(null);
        report.setImageUrls(normalizeReportImageUrls(
                reporterUid,
                report.getImageUrls(),
                Set.copyOf(existingImageUrls)));

        @SuppressWarnings("unchecked")
        Map<String, Object> data = objectMapper.convertValue(report, Map.class);
        docRef.update(data).get();

        Map<String, Object> mergedData = new HashMap<>(existing.getData());
        mergedData.putAll(data);
        mergedData.put("id", reportId);
        cachedUserStores = cachedUserStores.stream()
                .map(item -> reportId.equals(item.get("id")) ? mergedData : item)
                .toList();

        List<String> removedImages = existingImageUrls.stream()
                .filter(url -> !report.getImageUrls().contains(url))
                .toList();
        try {
            deleteReportImages(reporterUid, removedImages);
        } catch (Exception e) {
            log.warn("수정 후 제거된 제보 사진 정리에 실패했습니다. reportId={}", reportId, e);
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
        docRef.delete().get();
        cachedUserStores = cachedUserStores.stream()
                .filter(item -> !reportId.equals(item.get("id")))
                .toList();

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("id", reportId);
        result.put("deletedImages", deletedImages);
        result.put("deletedComments", deletedComments);
        result.put("deletedLikes", deletedLikes);
        result.put("deletedSubscriptions", deletedSubscriptions);
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
                log.warn("부분 업로드된 제보 사진 정리에 실패했습니다. uid={}",
                        reporterUid, cleanupError);
            }
            throw e;
        }
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

    // 💡 사용자의 제보 목록 조회 (내 제보 현황은 실시간성이 중요하므로 Firestore 유지, 소량)
    public List<Map<String, Object>> getUserReports(String firebaseUid) throws Exception {
        return db.collection("stores_user")
                .whereEqualTo("reporterId", firebaseUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    return data;
                })
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
                    return data;
                })
                .sorted((a, b) -> String.valueOf(b.getOrDefault("createdAt", ""))
                        .compareTo(String.valueOf(a.getOrDefault("createdAt", ""))))
                .toList();
    }

    // 💡 [어드민] 제보 승인 — status를 APPROVED로 변경 (승인 매장의 공식 stores 반영은 별도 작업)
    public void approveReport(String reportId) throws Exception {
        updateReportStatus(reportId, "APPROVED", null);
    }

    // 💡 [어드민] 제보 반려 — status를 REJECTED로 변경 + 반려 사유 저장
    public void rejectReport(String reportId, String reason) throws Exception {
        updateReportStatus(reportId, "REJECTED", reason);
    }

    private void updateReportStatus(String reportId, String status, String rejectReason) throws Exception {
        DocumentReference docRef = db.collection("stores_user").document(reportId);
        DocumentSnapshot snapshot = docRef.get().get();
        if (!snapshot.exists()) {
            throw new IllegalArgumentException("제보를 찾을 수 없습니다: " + reportId);
        }

        Map<String, Object> updates = new HashMap<>();
        updates.put("status", status);
        if (rejectReason != null) {
            updates.put("rejectReason", rejectReason);
        }
        docRef.update(updates).get();

        // 💡 가격 변동 제보 승인 시 찜한 사용자에게 알림 발송
        if ("APPROVED".equals(status)) {
            String storeName = snapshot.getString("storeName");
            if (storeName != null && !storeName.isBlank()) {
                try {
                    notifyUsersOnPriceReportApproved(
                            storeName,
                            snapshot.getString("storeId"),
                            reportId,
                            snapshot.getString("changeType"));
                } catch (Exception e) {
                    // 승인 상태 변경은 완료됐으므로 부가 알림 실패가 관리자 승인 결과를 실패로 만들지 않게 합니다.
                    log.warn("가격 변동 알림 발송 실패: reportId={}, storeName={}", reportId, storeName, e);
                }
            }
        }

        // 인메모리 캐시에도 즉시 반영 (bounds 조회 캐시와 상태 일치)
        List<Map<String, Object>> updated = cachedUserStores.stream()
                .map(item -> {
                    if (reportId.equals(item.get("id"))) {
                        Map<String, Object> copy = new HashMap<>(item);
                        copy.putAll(updates);
                        return copy;
                    }
                    return item;
                })
                .toList();
        cachedUserStores = List.copyOf(updated);
    }

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

        String createdAt = java.time.Instant.now().toString();

        for (DocumentSnapshot favDoc : favoriteDocs) {
            String userId = favDoc.getString("userId");
            if (userId == null) continue;

            if (storeId != null && !storeId.isBlank()) {
                String favoriteStoreId = canonicalStoreIdForFavorite(favDoc.getData());
                String favoriteStoreName = favDoc.getString("storeName");
                if (!storeId.equals(favoriteStoreId)
                        && !storeName.equals(favoriteStoreName)) {
                    continue;
                }
            }

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

            notifRef.set(data).get();

            // 5. 푸시 알림 발송 (기존 구조 재사용)
            dispatchPushNotification(userId, docId, (String) data.get("title"), (String) data.get("body"), "PRICE_ALERT");
        }
    }

    private boolean shouldNotifyPriceChange(NotificationSettingsDto settings, String changeType) {
        if (changeType == null || changeType.isBlank()) {
            return true;
        }
        return switch (changeType.toLowerCase()) {
            case "rise" -> Boolean.TRUE.equals(settings.getNotifyOnRise());
            case "drop" -> Boolean.TRUE.equals(settings.getNotifyOnDrop());
            case "new", "new_menu" -> Boolean.TRUE.equals(settings.getNotifyOnNewMenu());
            default -> true;
        };
    }

    // 💡 [어드민] 컬렉션 문서 수 (count 집계 쿼리 — 최대 1000건당 읽기 1회라 쿼터 부담 적음)
    private long countCollection(String name) throws Exception {
        return db.collection(name).count().get().get().getCount();
    }

    // 💡 [어드민] 대시보드 개요 지표 (매장 수는 인메모리 캐시 사용 — Firestore 읽기 0)
    public Map<String, Object> getAdminOverview() throws Exception {
        long pending = 0, approved = 0, rejected = 0;
        for (Map<String, Object> store : cachedUserStores) {
            switch (String.valueOf(store.getOrDefault("status", ""))) {
                case "PENDING" -> pending++;
                case "APPROVED" -> approved++;
                case "REJECTED" -> rejected++;
                default -> { }
            }
        }
        Map<String, Object> userStores = new HashMap<>();
        userStores.put("pending", pending);
        userStores.put("approved", approved);
        userStores.put("rejected", rejected);
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

    // 💡 [어드민] 회원 삭제 — 프로필과 모든 사용자 생성 데이터를 삭제
    public Map<String, Object> deleteUser(String firebaseUid) throws Exception {
        Map<String, Object> result = new HashMap<>();
        // 연관 컬렉션을 먼저 지워 중간 실패 시 계정을 남겨 재시도할 수 있게 합니다.
        result.put("reviews", deleteWhere("reviews", "authorUid", firebaseUid));
        result.put("reports", deleteReportsByUser(firebaseUid));
        result.put("visits", deleteWhere("visits", "userId", firebaseUid));
        result.put("favorites", deleteWhere("favorites", "userId", firebaseUid));
        result.put("inquiries", deleteWhere("inquiries", "userId", firebaseUid));
        result.put("comments", deleteWhere("comments", "userId", firebaseUid));
        result.put("feedLikes", deleteWhere("feed_likes", "userId", firebaseUid));
        result.put("feedSubscriptions", deleteWhere("feed_notifications", "userId", firebaseUid));
        result.put("notifications", deleteWhere("notifications", "userId", firebaseUid));
        result.put("deviceTokens", deleteWhere("device_tokens", "userId", firebaseUid));
        db.collection("notification_settings").document(firebaseUid).delete().get();
        result.put("reportImages", deleteReportImagePrefix(firebaseUid));
        cachedUserStores = cachedUserStores.stream()
                .filter(item -> !firebaseUid.equals(item.get("reporterId")))
                .toList();
        db.collection("users").document(firebaseUid).delete().get();
        result.put("uid", firebaseUid);
        return result;
    }

    private int deleteReportsByUser(String firebaseUid) throws Exception {
        var reports = db.collection("stores_user")
                .whereEqualTo("reporterId", firebaseUid)
                .get().get().getDocuments();
        for (DocumentSnapshot report : reports) {
            String reportId = report.getId();
            deleteWhere("comments", "postId", reportId);
            deleteWhere("feed_likes", "postId", reportId);
            deleteWhere("feed_notifications", "postId", reportId);
            report.getReference().delete().get();
        }
        return reports.size();
    }

    private int deleteReportImagePrefix(String firebaseUid) {
        try {
            return reportImageStorage.deleteAllOwned(firebaseUid);
        } catch (Exception e) {
            log.warn("회원 탈퇴 중 제보 이미지 정리에 실패했습니다. uid={}", firebaseUid, e);
            return 0;
        }
    }

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
        return db.collection("users")
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    return data;
                })
                .sorted((a, b) -> String.valueOf(b.getOrDefault("createdAt", ""))
                        .compareTo(String.valueOf(a.getOrDefault("createdAt", ""))))
                .toList();
    }

    // 💡 매장명으로 업종 조회 (공공데이터 인메모리 캐시 사용 — Firestore 읽기 0)
    public String findIndustryByStoreName(String storeName) {
        if (storeName == null || storeName.isBlank()) return null;
        return cachedStores.stream()
                .filter(s -> storeName.equals(String.valueOf(s.get("storeName"))))
                .map(s -> s.get("industry") != null ? s.get("industry").toString() : null)
                .filter(java.util.Objects::nonNull)
                .findFirst()
                .orElse(null);
    }

    // 💡 방문 기록 저장 (절약 금액은 VisitController에서 서버 룰로 계산되어 주입됨)
    public String saveVisit(String firebaseUid, com.howmuch.dto.VisitRequest request, long savedAmount) throws Exception {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("storeId", request.getStoreId());
        data.put("storeName", request.getStoreName());
        data.put("menu", request.getMenu());
        data.put("price", request.getPrice());
        data.put("savedAmount", savedAmount);
        data.put("isGov", findIndustryByStoreName(request.getStoreName()) != null);
        data.put("verificationMethod", request.getVerificationMethod());
        data.put("verificationDistanceMeters", request.getVerificationDistanceMeters());
        data.put("visitedAt", java.time.Instant.now().toString());

        DocumentReference docRef = db.collection("visits").document();
        docRef.set(data).get();
        return docRef.getId();
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
        if (authorUid == null || authorUid.isBlank()) {
            throw new IllegalArgumentException("인증된 사용자만 리뷰를 저장할 수 있습니다.");
        }
        Map<String, Object> data = new HashMap<>();
        data.put("storeId", request.getStoreId());
        data.put("storeName", request.getStoreName());
        data.put("authorUid", authorUid);
        data.put("authorName", request.getAuthorName());
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
        return docRef.getId();
    }

    // 💡 특정 매장의 리뷰 목록 조회 (최신순 정렬 포함)
    public List<Map<String, Object>> getReviews(String storeId) throws Exception {
        List<Map<String, Object>> reviews = new ArrayList<>(db.collection("reviews")
                .whereEqualTo("storeId", storeId)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    return data;
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

    // 💡 [어드민] 전체 리뷰 목록 (최신순, 매장명/작성자명 포함 — 소량 컬렉션)
    public List<Map<String, Object>> getAllReviews() throws Exception {
        List<Map<String, Object>> reviews = new ArrayList<>(db.collection("reviews")
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    return data;
                })
                .toList());
        reviews.sort((a, b) -> String.valueOf(b.getOrDefault("createdAt", ""))
                .compareTo(String.valueOf(a.getOrDefault("createdAt", ""))));
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
        List<Map<String, Object>> reviews = new ArrayList<>(db.collection("reviews")
                .whereEqualTo("authorUid", authorUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId());
                    return data;
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

            com.howmuch.dto.SavingsHistoryResponse dto = com.howmuch.dto.SavingsHistoryResponse.builder()
                    .id(doc.getId())
                    .storeId(data.get("storeId") != null ? data.get("storeId").toString() : null)
                    .storeName(data.get("storeName") != null ? data.get("storeName").toString() : null)
                    .visitedAt(visitedAtStr)
                    .date(dateStr)
                    .menu(data.get("menu") != null ? data.get("menu").toString() : null)
                    .price(priceAmt)
                    .savedAmount(savedAmt != null ? savedAmt : 0L)
                    .isGov(isGov)
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
        Map<String, Object> data = new HashMap<>();
        data.put("firebaseUid", firebaseUid);
        data.put("nickname", request.getNickname());
        data.put("email", request.getEmail());
        data.put("region", request.getRegion());
        data.put("favoriteCategories", request.getFavoriteCategories());
        data.put("createdAt", java.time.Instant.now().toString());

        ApiFuture<WriteResult> future = db.collection("users").document(firebaseUid).set(data);
        future.get();

        return UserProfileResponse.builder()
                .firebaseUid(firebaseUid)
                .nickname(request.getNickname())
                .email(request.getEmail())
                .region(request.getRegion())
                .favoriteCategories(request.getFavoriteCategories())
                .createdAt((String) data.get("createdAt"))
                .build();
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
        return copy;
    }

    /** 공공데이터 인메모리 캐시에서 매장명으로 매장 정보 조회 (Firestore 읽기 0). 없으면 null */
    private Map<String, Object> findGovStoreByName(String storeName) {
        if (storeName == null || storeName.isBlank()) return null;
        return cachedStores.stream()
                .filter(s -> storeName.equals(String.valueOf(s.get("storeName"))))
                .findFirst()
                .orElse(null);
    }

    /**
     * 방문 인증용 매장 좌표를 캐시에서 조회합니다.
     * storeId가 있으면 식별자를 우선하고, 레거시 클라이언트는 매장명으로 보완합니다.
     */
    public java.util.Optional<StoreCoordinates> findStoreCoordinates(String storeId, String storeName) {
        List<Map<String, Object>> stores = new ArrayList<>();
        stores.addAll(cachedStores);
        stores.addAll(cachedUserStores);

        return stores.stream()
                .map(this::withStableStoreId)
                .filter(store -> matchesStore(store, storeId, storeName))
                .map(this::toStoreCoordinates)
                .filter(java.util.Objects::nonNull)
                .findFirst();
    }

    private boolean matchesStore(Map<String, Object> store, String storeId, String storeName) {
        String cachedId = strOrNull(store.get("storeId"));
        String cachedName = strOrNull(store.get("storeName"));
        if (storeId != null && !storeId.isBlank() && storeId.equals(cachedId)) return true;
        return (storeId == null || storeId.isBlank())
                && storeName != null
                && !storeName.isBlank()
                && storeName.equals(cachedName);
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
            return new StoreCoordinates(latitude, longitude);
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

        // 공공데이터 캐시에 매장이 있으면 메타(업종/대표메뉴/가격/주소) 동봉 — 없으면 null (Firestore 읽기 0)
        Map<String, Object> store = findGovStoreByName(request.getStoreName());
        return com.howmuch.dto.FavoriteResponse.builder()
                .id(docId)
                .storeId(request.getStoreId())
                .storeName(request.getStoreName())
                .createdAt(createdAt)
                .industry(store != null ? strOrNull(store.get("industry")) : null)
                .menu1(store != null ? strOrNull(store.get("menu1")) : null)
                .price1(store != null ? strOrNull(store.get("price1")) : null)
                .address(store != null ? strOrNull(store.get("address")) : null)
                .build();
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
        List<com.howmuch.dto.FavoriteResponse> favorites = new ArrayList<>(db.collection("favorites")
                .whereEqualTo("userId", firebaseUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = doc.getData();
                    String storeName = data.get("storeName") != null ? data.get("storeName").toString() : null;
                    // 공공데이터 캐시 매장 메타 동봉 (Firestore 읽기 0) — 제보 매장 등 캐시에 없으면 null
                    Map<String, Object> store = findGovStoreByName(storeName);
                    return com.howmuch.dto.FavoriteResponse.builder()
                            .id(doc.getId())
                            .storeId(canonicalStoreIdForFavorite(data))
                            .storeName(storeName)
                            .createdAt(data.get("createdAt") != null ? data.get("createdAt").toString() : null)
                            .industry(store != null ? strOrNull(store.get("industry")) : null)
                            .menu1(store != null ? strOrNull(store.get("menu1")) : null)
                            .price1(store != null ? strOrNull(store.get("price1")) : null)
                            .address(store != null ? strOrNull(store.get("address")) : null)
                            .build();
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
        for (DocumentSnapshot favorite : db.collection("favorites")
                .whereEqualTo("userId", firebaseUid).get().get().getDocuments()) {
            Map<String, Object> data = favorite.getData();
            String storeName = strOrNull(data.get("storeName"));
            Map<String, Object> store = findGovStoreByName(storeName);
            String menuName = store != null ? strOrNull(store.get("menu1")) : null;
            String price = store != null ? strOrNull(store.get("price1")) : null;
            subscriptions.add(PriceAlertSubscriptionDto.builder()
                    .storeId(canonicalStoreIdForFavorite(data))
                    .storeName(storeName != null && !storeName.isBlank() ? storeName : "매장명 없음")
                    .menuName(menuName != null && !menuName.isBlank() ? menuName : "가격 변동 알림")
                    .price(price)
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
        String storeName = strOrNull(data.get("storeName"));
        Map<String, Object> store = findGovStoreByName(storeName);
        String menuName = store != null ? strOrNull(store.get("menu1")) : null;
        return PriceAlertSubscriptionDto.builder()
                .storeId(canonicalStoreIdForFavorite(data))
                .storeName(storeName != null ? storeName : "매장명 없음")
                .menuName(menuName != null && !menuName.isBlank() ? menuName : "가격 변동 알림")
                .price(store != null ? strOrNull(store.get("price1")) : null)
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
        Object status = data.get("status");
        if (status == null || status.toString().isBlank()) return true; // 레거시
        return !"REJECTED".equalsIgnoreCase(status.toString());
    }

    // 💡 커뮤니티 피드 목록 조회 (최신순, REJECTED 제외)
    // ⚠️ 쿼터: 호출마다 stores_user 전체 읽기 + 작성자당 users 1회 읽기.
    //    제보 수 증가 시 인메모리 캐시 패턴 필요 (PROJECT_STATUS 5-2 참조).
    public List<com.howmuch.dto.FeedResponseDto> getCommunityFeeds() throws Exception {
        var documents = db.collection("stores_user")
                .get().get().getDocuments();

        List<com.howmuch.dto.FeedResponseDto> feeds = new ArrayList<>();
        Map<String, String> authorCache = new HashMap<>();

        for (DocumentSnapshot doc : documents) {
            Map<String, Object> data = doc.getData();
            if (data == null) continue;
            if (!isFeedVisible(data)) continue; // REJECTED 제외

            String reporterId = (String) data.get("reporterId");
            String author = "알 수 없음";
            if (reporterId != null) {
                if (authorCache.containsKey(reporterId)) {
                    author = authorCache.get(reporterId);
                } else {
                    try {
                        com.howmuch.dto.UserProfileResponse user = getUserProfile(reporterId);
                        if (user != null && user.getNickname() != null) {
                            author = user.getNickname();
                        }
                    } catch (Exception e) {
                        // Ignore
                    }
                    authorCache.put(reporterId, author);
                }
            }

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
                    .author(author)
                    .likes(data.get("likes") != null ? Integer.parseInt(data.get("likes").toString()) : 0)
                    .comments(data.get("comments") != null ? Integer.parseInt(data.get("comments").toString()) : 0)
                    .status(status)
                    .imageUrls(imageUrls)
                    .createdAt(createdAt)
                    .build();
            feeds.add(dto);
        }

        // 최신순 정렬 (메모리 정렬 — Firestore 인덱스 불필요 + createdAt 없는 레거시 호환)
        feeds.sort((a, b) -> b.getCreatedAt().compareTo(a.getCreatedAt()));
        return feeds;
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

        String reporterId = (String) data.get("reporterId");
        String author = "알 수 없음";
        if (reporterId != null) {
            try {
                com.howmuch.dto.UserProfileResponse user = getUserProfile(reporterId);
                if (user != null && user.getNickname() != null) {
                    author = user.getNickname();
                }
            } catch (Exception e) {
                // Ignore
            }
        }

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
                .author(author)
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
                .visitedRecently(data.get("visitedRecently") != null && Boolean.parseBoolean(data.get("visitedRecently").toString()))
                .checkedMenuPrice(data.get("checkedMenuPrice") != null && Boolean.parseBoolean(data.get("checkedMenuPrice").toString()))
                .build();
    }

    // ==================== 문의 (inquiries) ====================

    /**
     * 문의 등록 — Firestore inquiries 컬렉션에 저장.
     * userId(세션 uid), title, content, category, status(기본 PENDING), createdAt 포함.
     */
    public Map<String, Object> createInquiry(String firebaseUid, com.howmuch.dto.InquiryRequest request) throws Exception {
        String createdAt = java.time.Instant.now().toString();
        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("title", request.getTitle().trim());
        data.put("content", request.getContent().trim());
        data.put("category", request.getCategory() != null ? request.getCategory().trim() : "일반");
        data.put("status", "PENDING");
        data.put("createdAt", createdAt);

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
                .get().get().getDocuments().stream()
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

    /** 어드민 문의 답변 등록 및 사용자 알림 생성 */
    public Map<String, Object> answerInquiry(String inquiryId, String answer) throws Exception {
        DocumentReference inquiryRef = db.collection("inquiries").document(inquiryId);
        DocumentSnapshot inquiry = inquiryRef.get().get();
        if (!inquiry.exists()) {
            throw new IllegalArgumentException("문의를 찾을 수 없습니다.");
        }

        String userId = inquiry.getString("userId");
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("문의 작성자 정보를 찾을 수 없습니다.");
        }

        String answeredAt = java.time.Instant.now().toString();
        Map<String, Object> update = new HashMap<>();
        update.put("answer", answer);
        update.put("answeredAt", answeredAt);
        update.put("status", "ANSWERED");
        inquiryRef.update(update).get();

        String inquiryTitle = inquiry.getString("title");
        createNotificationForUser(
                userId,
                "문의 답변이 도착했어요",
                (inquiryTitle == null || inquiryTitle.isBlank())
                        ? "등록한 문의에 답변이 등록되었습니다."
                        : "'" + inquiryTitle + "' 문의에 답변이 등록되었습니다.",
                "INQUIRY_ANSWER",
                answeredAt);

        Map<String, Object> result = new HashMap<>();
        result.put("success", true);
        result.put("id", inquiryId);
        result.put("status", "ANSWERED");
        result.put("answeredAt", answeredAt);
        return result;
    }

    // ==================== 오늘의 픽 (todays pick) ====================

    /** 추천 대상 요식업 업종 (공공데이터의 미용업·이용업·세탁업·숙박업·목욕업·기타비요식업 제외) */
    private static final Set<String> FOOD_INDUSTRIES =
            Set.of("한식", "중식", "일식", "양식", "기타요식업");

    /** 최종 추천 개수 */
    private static final int MAX_PICKS = 4;

    /** 위치 기반 후보군 크기 (이 안에서 날짜 시드 셔플로 4곳 선정) */
    private static final int CANDIDATE_POOL_SIZE = 20;

    /**
     * 오늘의 픽 추천 — 날씨 기반 추천 룰 + 공공데이터 인메모리 캐시에서 매장 선별.
     * Firestore 읽기 0 (cachedStores만 사용).
     *
     * @param weather 날씨 요약 (맑음/구름많음/흐림/비/눈/소나기/알 수 없음)
     * @param temp    기온 (섭씨, null 가능)
     * @param lat     사용자 위도 (거리 계산용, null 가능)
     * @param lng     사용자 경도 (거리 계산용, null 가능)
     * @return 추천 매장 리스트 (최대 4개)
     */
    public List<Map<String, Object>> getTodaysPicks(String weather, Integer temp, Double lat, Double lng) {
        List<PickTheme> themes = weatherThemes(weather, temp);
        PickTheme mainTheme = themes.get(0);
        PickTheme altTheme = themes.size() > 1 ? themes.get(1) : null;

        // 💡 식당(요식업)만 추천 대상 — 공공데이터엔 미용업·세탁업·목욕업 등 비요식업이 섞여 있어
        //    매칭 실패 폼백에서 미용실이 추천되던 문제 방지
        List<Map<String, Object>> foodStores = new ArrayList<>();
        for (Map<String, Object> store : cachedStores) {
            String industry = strOrNull(store.get("industry"));
            if (industry != null && FOOD_INDUSTRIES.contains(industry)) {
                foodStores.add(store);
            }
        }

        // 테마별 매칭 (매장 → 실제 매칭된 메뉴 추적). 대안 테마는 메인과 겹치지 않게 제외.
        long dailySeed = java.time.LocalDate.now().toEpochDay();
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
        List<Map<String, Object>> mainCandidates = nearestShuffled(mainPool, lat, lng, CANDIDATE_POOL_SIZE, dailySeed);
        List<Map<String, Object>> altCandidates = nearestShuffled(altMatched, lat, lng, ALT_CANDIDATE_POOL_SIZE, dailySeed + 1);

        // 메인 3곳 + 대안 테마 1곳 (대안이 없으면 메인으로 채움)
        Set<String> seenNames = new HashSet<>();
        List<Map<String, Object>> chosen = new ArrayList<>();
        addUnique(chosen, mainCandidates, MAIN_PICKS, seenNames);
        addUnique(chosen, altCandidates, ALT_PICKS, seenNames);
        if (chosen.size() < MAX_PICKS) {
            addUnique(chosen, mainCandidates, MAX_PICKS - chosen.size(), seenNames);
        }

        if (lat != null && lng != null) {
            chosen.sort(java.util.Comparator.comparingDouble(
                    store -> haversine(lat, lng, parseLat(store), parseLng(store))));
        }

        List<Map<String, Object>> picks = new ArrayList<>();
        for (Map<String, Object> store : chosen) {
            String name = strOrNull(store.get("storeName"));
            Map<String, Object> pick = new HashMap<>();
            pick.put("storeName", name);
            pick.put("industry", strOrNull(store.get("industry")));
            pick.put("menu1", strOrNull(store.get("menu1")));
            pick.put("price1", strOrNull(store.get("price1")));
            pick.put("address", strOrNull(store.get("address")));
            pick.put("latitude", store.get("latitude"));
            pick.put("longitude", store.get("longitude"));
            if (lat != null && lng != null) {
                pick.put("distanceMeters", (int) Math.round(haversine(lat, lng, parseLat(store), parseLng(store))));
            }
            // 추천 근거: 실제 매칭된 메뉴 + 테마 + 이유 멘트 (폼백 매장은 null → 프론트 기본 멘트)
            pick.put("matchedMenu", matchedMenuByStore.get(name));
            pick.put("theme", themeByStore.get(name));
            pick.put("reason", reasonByStore.get(name));
            picks.add(pick);
        }
        return picks;
    }

    /** 메인 테마 추천 개수 (나머지 1개는 대안 테마) */
    private static final int MAIN_PICKS = 3;

    /** 대안 테마 추천 개수 */
    private static final int ALT_PICKS = 1;

    /** 대안 테마 후보군 크기 */
    private static final int ALT_CANDIDATE_POOL_SIZE = 10;

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
            String name = String.valueOf(store.get("storeName"));
            if (excludeNames.contains(name)) continue;
            String matchedMenu = findMatchedMenu(store, theme.keywords());
            if (matchedMenu != null) {
                matched.add(store);
                matchedMenuByStore.put(name, matchedMenu);
                themeByStore.put(name, theme.label());
                reasonByStore.put(name, theme.reason());
            }
        }
        return matched;
    }

    /** 가까운 순 상위 limit개를 반환한다. 위치가 없을 때만 날짜 시드로 섞는다. */
    private List<Map<String, Object>> nearestShuffled(List<Map<String, Object>> pool,
                                                      Double lat, Double lng, int limit, long seed) {
        List<Map<String, Object>> scored = new ArrayList<>(pool);
        if (lat != null && lng != null) {
            scored.sort((a, b) -> Double.compare(
                    haversine(lat, lng, parseLat(a), parseLng(a)),
                    haversine(lat, lng, parseLat(b), parseLng(b))));
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
            String name = strOrNull(store.get("storeName"));
            if (name == null || !seenNames.add(name)) continue;
            chosen.add(store);
            added++;
        }
    }

    /**
     * 매장의 메뉴(menu1~menu4) 중 추천 키워드를 포함하는 "첫 번째 실제 메뉴"를 반환.
     * 없으면 null. 카드에는 menu1 대신 이 매칭된 메뉴를 보여줘 추천 근거와 일치시킨다.
     */
    private String findMatchedMenu(Map<String, Object> store, List<String> keywords) {
        for (String key : new String[]{"menu1", "menu2", "menu3", "menu4"}) {
            String menu = strOrNull(store.get(key));
            if (menu == null || menu.isBlank()) continue;
            for (String kw : keywords) {
                if (menu.contains(kw)) {
                    return menu;
                }
            }
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
            return 0;
        }
    }

    private double parseLng(Map<String, Object> store) {
        try {
            return Double.parseDouble(String.valueOf(store.get("longitude")));
        } catch (Exception e) {
            return 0;
        }
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

    /** 작성자 uid → 닉네임 해결 (실패 시 '알 수 없음') */
    private String resolveAuthor(String uid) {
        if (uid == null) return "알 수 없음";
        try {
            com.howmuch.dto.UserProfileResponse user = getUserProfile(uid);
            if (user != null && user.getNickname() != null && !user.getNickname().isBlank()) {
                return user.getNickname();
            }
        } catch (Exception e) {
            // ignore
        }
        return "알 수 없음";
    }

    /** 게시글의 comments/likes 카운터를 실제 컬렉션 기준으로 다시 계산해 저장 (요청 #6 최신화) */
    private void syncFeedCounts(String postId) {
        try {
            long commentCount = db.collection("comments")
                    .whereEqualTo("postId", postId).get().get().getDocuments().size();
            long likeCount = db.collection("feed_likes")
                    .whereEqualTo("postId", postId).get().get().getDocuments().size();
            Map<String, Object> updates = new HashMap<>();
            updates.put("comments", (int) commentCount);
            updates.put("likes", (int) likeCount);
            db.collection("stores_user").document(postId).update(updates).get();
        } catch (Exception e) {
            // 카운터 동기화 실패는 치명적이지 않으므로 로그만 (호출 흐름 유지)
        }
    }

    /** 문서 스냅샷 → CommentResponse 변환 */
    private com.howmuch.dto.CommentResponse toCommentResponse(DocumentSnapshot doc, String requesterUid) {
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
        return com.howmuch.dto.CommentResponse.builder()
                .id(doc.getId())
                .author(resolveAuthor(uid))
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
                .get().get().getDocuments());
        List<com.howmuch.dto.CommentResponse> result = new ArrayList<>();
        for (DocumentSnapshot doc : docs) {
            Map<String, Object> data = doc.getData();
            Object parentId = data != null ? data.get("parentId") : null;
            if (parentId == null) { // 최상위 댓글만
                result.add(toCommentResponse(doc, requesterUid));
            }
        }
        // 복합 인덱스 없이 메모리 정렬 (오래된순)
        result.sort(java.util.Comparator.comparing(com.howmuch.dto.CommentResponse::getCreatedAt));
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
        return com.howmuch.dto.CommentResponse.builder()
                .id(docRef.getId())
                .author(resolveAuthor(requesterUid))
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
                .get().get().getDocuments());
        List<com.howmuch.dto.CommentResponse> result = new ArrayList<>();
        for (DocumentSnapshot doc : docs) {
            result.add(toCommentResponse(doc, requesterUid));
        }
        result.sort(java.util.Comparator.comparing(com.howmuch.dto.CommentResponse::getCreatedAt));
        return result;
    }

    // 💡 답글 작성 (부모 댓글 replyCount 증가 + 게시글 comments 갱신)
    public com.howmuch.dto.CommentResponse createReply(String commentId, String requesterUid, String content) throws Exception {
        DocumentSnapshot parent = db.collection("comments").document(commentId).get().get();
        if (!parent.exists()) return null;
        Map<String, Object> parentData = parent.getData();
        String postId = parentData != null && parentData.get("postId") != null ? parentData.get("postId").toString() : null;

        DocumentReference docRef = db.collection("comments").document();
        String createdAt = java.time.Instant.now().toString();
        Map<String, Object> data = new HashMap<>();
        data.put("postId", postId);
        data.put("userId", requesterUid);
        data.put("content", content);
        data.put("createdAt", createdAt);
        data.put("parentId", commentId);
        data.put("replyCount", 0);
        docRef.set(data).get();

        // 부모 댓글 replyCount 갱신
        int parentReplyCount = 0;
        Object rc = parentData != null ? parentData.get("replyCount") : null;
        if (rc != null) {
            try { parentReplyCount = Integer.parseInt(rc.toString()); } catch (NumberFormatException ignored) {}
        }
        db.collection("comments").document(commentId).update("replyCount", parentReplyCount + 1).get();

        if (postId != null) syncFeedCounts(postId);

        return com.howmuch.dto.CommentResponse.builder()
                .id(docRef.getId())
                .author(resolveAuthor(requesterUid))
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
        return db.collection("feed_likes").whereEqualTo("postId", postId).get().get().getDocuments().size();
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
                    .build());
        }

        // 복합 인덱스 없이 메모리에서 최신순 정렬
        notifications.sort((a, b) -> {
            String aTime = a.getCreatedAt() != null ? a.getCreatedAt() : "";
            String bTime = b.getCreatedAt() != null ? b.getCreatedAt() : "";
            return bTime.compareTo(aTime);
        });
        return notifications;
    }

    // 💡 알림 읽음 처리 (본인 알림만 가능 — 다른 유저 알림이면 거부)
    public void markNotificationAsRead(String notificationId, String firebaseUid) throws Exception {
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
        data.put("notifyOnRise", normalized.getNotifyOnRise());
        data.put("notifyOnDrop", normalized.getNotifyOnDrop());
        data.put("notifyOnNewMenu", normalized.getNotifyOnNewMenu());
        data.put("quietHours", normalized.getQuietHours());
        data.put("quietStart", normalized.getQuietStart());
        data.put("quietEnd", normalized.getQuietEnd());
        data.put("updatedAt", java.time.Instant.now().toString());
        db.collection("notification_settings").document(firebaseUid).set(data).get();
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
                .get().get().getDocuments().stream()
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
        comments.sort((a, b) -> {
            String aTime = a.get("createdAt") != null ? a.get("createdAt").toString() : "";
            String bTime = b.get("createdAt") != null ? b.get("createdAt").toString() : "";
            return bTime.compareTo(aTime);
        });
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
        if (parentId == null) {
            var replies = db.collection("comments").whereEqualTo("parentId", commentId).get().get().getDocuments();
            for (DocumentSnapshot reply : replies) {
                reply.getReference().delete().get();
            }
        }
        docRef.delete().get();

        // 답글이면 부모 댓글 replyCount 감소
        if (parentId != null) {
            try {
                DocumentReference parentRef = db.collection("comments").document(parentId.toString());
                DocumentSnapshot parent = parentRef.get().get();
                if (parent.exists()) {
                    Object rc = parent.get("replyCount");
                    int count = 0;
                    if (rc != null) { try { count = Integer.parseInt(rc.toString()); } catch (NumberFormatException ignored) {} }
                    parentRef.update("replyCount", Math.max(0, count - 1)).get();
                }
            } catch (Exception e) { /* 카운터 감소 실패는 무시 */ }
        }
        // 게시글 comments/likes 카운터 갱신
        if (postId != null) syncFeedCounts(postId);
    }

    // 💡 [어드민] 알림 발송 — 특정 유저 1명 또는 전체 유저에게 notifications 문서 생성
    public Map<String, Object> sendAdminNotification(String targetUid, String title, String body, String type) throws Exception {
        String createdAt = java.time.Instant.now().toString();
        int sent = 0;
        List<String> targetUids = new ArrayList<>();
        if (targetUid != null && !targetUid.isBlank()) {
            targetUids.add(targetUid);
        } else {
            // 전체 발송: users 전체
            for (DocumentSnapshot u : db.collection("users").get().get().getDocuments()) {
                targetUids.add(u.getId());
            }
        }
        for (String uid : targetUids) {
            createNotificationForUser(
                    uid,
                    title,
                    body,
                    type != null && !type.isBlank() ? type : "admin",
                    createdAt);
            sent++;
        }
        Map<String, Object> result = new HashMap<>();
        result.put("sent", sent);
        result.put("broadcast", targetUid == null || targetUid.isBlank());
        return result;
    }

    private void createNotificationForUser(
            String userId,
            String title,
            String body,
            String type,
            String createdAt) throws Exception {
        Map<String, Object> data = new HashMap<>();
        data.put("userId", userId);
        data.put("title", title);
        data.put("body", body);
        data.put("type", type);
        data.put("isRead", false);
        data.put("createdAt", createdAt);
        DocumentReference notification = db.collection("notifications").document();
        notification.set(data).get();
        dispatchPushNotification(userId, notification.getId(), title, body, type);
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
                    log.warn("FCM 발송 실패: uid={}, code={}", userId, e.getMessagingErrorCode());
                }
            }
        } catch (Exception e) {
            log.warn("FCM 기기 조회 또는 발송 실패: uid={}", userId, e);
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
        if (normalizedType.contains("REVIEW")) {
            return Boolean.TRUE.equals(settings.getReview());
        }
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
            log.warn("방해 금지 시간 형식이 올바르지 않아 푸시를 계속 전송합니다. uid={}", userId);
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
