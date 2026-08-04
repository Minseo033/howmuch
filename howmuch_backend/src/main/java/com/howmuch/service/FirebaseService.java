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
        // 💡 어드민 승인(APPROVED)된 제변이나, 승인제 도입 이전의 레거시 제보(status 없음)만 지도에 노출.
        //    PENDING(검토 중)·REJECTED(반려)는 공개 지도에서 제외합니다.
        List<Map<String, Object>> userStores = cachedUserStores.stream()
                .filter(this::isPubliclyVisible)
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
        if (!docRef.get().get().exists()) {
            throw new IllegalArgumentException("제보를 찾을 수 없습니다: " + reportId);
        }

        Map<String, Object> updates = new HashMap<>();
        updates.put("status", status);
        if (rejectReason != null) {
            updates.put("rejectReason", rejectReason);
        }
        docRef.update(updates).get();

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

    // 💡 [어드민] 회원 삭제 — users 문서 + 해당 유저의 리뷰/제보/방문/찜 전부 삭제
    public Map<String, Object> deleteUser(String firebaseUid) throws Exception {
        Map<String, Object> result = new HashMap<>();
        // users/{uid} 문서 삭제
        db.collection("users").document(firebaseUid).delete().get();
        // 연관 컬렉션 문서 전부 삭제 (각 컬렉션을 uid 필드로 조회)
        result.put("reviews", deleteWhere("reviews", "authorUid", firebaseUid));
        result.put("reports", deleteWhere("stores_user", "reporterId", firebaseUid));
        result.put("visits", deleteWhere("visits", "userId", firebaseUid));
        result.put("favorites", deleteWhere("favorites", "userId", firebaseUid));
        result.put("uid", firebaseUid);
        return result;
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
        return firebaseUid + "_" + storeId;
    }

    // 💡 찜 추가 (멱등: 같은 매장 재추가 시 덮어쓰기, 중복 문서 생성 안 됨)
    public com.howmuch.dto.FavoriteResponse addFavorite(String firebaseUid, com.howmuch.dto.FavoriteRequest request) throws Exception {
        String docId = favoriteDocId(firebaseUid, request.getStoreId());
        String createdAt = java.time.Instant.now().toString();

        Map<String, Object> data = new HashMap<>();
        data.put("userId", firebaseUid);
        data.put("storeId", request.getStoreId());
        data.put("storeName", request.getStoreName());
        data.put("createdAt", createdAt);

        db.collection("favorites").document(docId).set(data).get();

        return com.howmuch.dto.FavoriteResponse.builder()
                .id(docId)
                .storeId(request.getStoreId())
                .storeName(request.getStoreName())
                .createdAt(createdAt)
                .build();
    }

    // 💡 찜 해제 (존재하지 않아도 에러 없이 성공 처리 — 멱등)
    public void removeFavorite(String firebaseUid, String storeId) throws Exception {
        String docId = favoriteDocId(firebaseUid, storeId);
        db.collection("favorites").document(docId).delete().get();
    }

    // 💡 내 찜 목록 조회 (최신순)
    public List<com.howmuch.dto.FavoriteResponse> getFavorites(String firebaseUid) throws Exception {
        List<com.howmuch.dto.FavoriteResponse> favorites = new ArrayList<>(db.collection("favorites")
                .whereEqualTo("userId", firebaseUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = doc.getData();
                    return com.howmuch.dto.FavoriteResponse.builder()
                            .id(doc.getId())
                            .storeId(data.get("storeId") != null ? data.get("storeId").toString() : null)
                            .storeName(data.get("storeName") != null ? data.get("storeName").toString() : null)
                            .createdAt(data.get("createdAt") != null ? data.get("createdAt").toString() : null)
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
}
