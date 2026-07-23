package com.howmuch.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.dto.UserProfileResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import jakarta.annotation.PostConstruct;

import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class FirebaseService {

    private final Firestore db;
    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 착한가격업소(공공데이터) 인메모리 캐시.
     * Firestore 일일 읽기 한도(무료 5만) 보호를 위해 요청마다 읽지 않습니다.
     * volatile 참조 교체 방식이라 조회 중에도 안전합니다.
     */
    private volatile List<Map<String, Object>> cachedStores = List.of();

    /** 사용자 제보 매장 인메모리 캐시 (bounds 조회 시 Firestore 실시간 조회 제거) */
    private volatile List<Map<String, Object>> cachedUserStores = List.of();

    /** 공공데이터 마지막 갱신 성공 시각 (24시간 가드: 1시간 주기 실행되지만 성공 후 24시간 내엔 Firestore 미호출) */
    private volatile long lastGovRefreshSuccessMillis = 0L;

    /** 스냅샷 파일 경로 (기본: 작업 디렉터리 data/stores-snapshot.json) */
    @Value("${stores.snapshot.path:data/stores-snapshot.json}")
    private String snapshotPath;

    public FirebaseService(Firestore db) {
        this.db = db;
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
    @Scheduled(initialDelayString = "${stores.refresh.initial-delay-ms:600000}",
            fixedDelayString = "${stores.refresh.delay-ms:3600000}")
    public void refreshGovStores() {
        if (System.currentTimeMillis() - lastGovRefreshSuccessMillis < 86_400_000L
                && !cachedStores.isEmpty()) {
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
        return cachedStores;
    }

    // 💡 화면 범위(Bounds) 기반 업소 조회 (정부 데이터 + 사용자 제보 통합, 전량 인메모리)
    public List<Map<String, Object>> getStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) {
        // 1. 정부 인증 업소 (Blue) - 메모리 캐시
        List<Map<String, Object>> govStores = cachedStores.stream()
                .filter(data -> isInBounds(data, minLat, maxLat, minLng, maxLng))
                .map(data -> {
                    Map<String, Object> map = new HashMap<>(data);
                    map.put("source", "GOV");
                    return map;
                })
                .limit(1000)
                .toList();

        // 2. 사용자 제보 업소 (Orange) - 메모리 캐시 (Firestore 실시간 조회 제거)
        List<Map<String, Object>> userStores = cachedUserStores.stream()
                .filter(data -> isInBounds(data, minLat, maxLat, minLng, maxLng))
                .map(data -> {
                    Map<String, Object> map = new HashMap<>(data);
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

        DocumentReference docRef = db.collection("stores_user").document();
        ApiFuture<WriteResult> future = docRef.set(report);
        future.get();

        @SuppressWarnings("unchecked")
        Map<String, Object> data = objectMapper.convertValue(report, Map.class);
        data.put("id", docRef.getId());
        List<Map<String, Object>> updated = new ArrayList<>(cachedUserStores);
        updated.add(data);
        cachedUserStores = List.copyOf(updated);

        return docRef.getId();
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

            com.howmuch.dto.VisitResponseDto dto = com.howmuch.dto.VisitResponseDto.builder()
                    .id(doc.getId())
                    .visitedAt(data.get("visitedAt") != null ? data.get("visitedAt").toString() : null)
                    .storeName(data.get("storeName") != null ? data.get("storeName").toString() : null)
                    .savedAmount(savedAmt)
                    .storeId(data.get("storeId") != null ? data.get("storeId").toString() : null)
                    .menu(data.get("menu") != null ? data.get("menu").toString() : null)
                    .price(priceAmt)
                    .isGov(isGov)
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
        Map<String, Object> data = new HashMap<>();
        data.put("storeId", request.getStoreId());
        data.put("storeName", request.getStoreName());
        data.put("authorUid", authorUid);
        data.put("authorName", request.getAuthorName());
        data.put("menu", request.getMenu());
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
}