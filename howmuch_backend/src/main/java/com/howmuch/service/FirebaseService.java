package com.howmuch.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Bucket;
import com.google.firebase.cloud.StorageClient;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.dto.UserProfileResponse;
import com.howmuch.dto.NotificationSettingsDto;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ClassPathResource;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import jakarta.annotation.PostConstruct;

import java.io.InputStream;
import java.net.URI;
import java.net.URLDecoder;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Random;
import java.util.Set;
import java.util.UUID;

@Slf4j
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

    private static final int REPORT_IMAGE_MAX_COUNT = 3;
    private static final long REPORT_IMAGE_MAX_BYTES = 5L * 1024L * 1024L;

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

        Bucket bucket = reportImageBucket();
        List<BlobId> uploadedBlobIds = new ArrayList<>();
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

                String token = UUID.randomUUID().toString();
                String objectName = "report-images/%s/%s%s".formatted(
                        sanitizeForObjectName(reporterUid),
                        UUID.randomUUID(),
                        extensionFromContentType(contentType));
                BlobId blobId = BlobId.of(bucket.getName(), objectName);
                BlobInfo blobInfo = BlobInfo.newBuilder(blobId)
                        .setContentType(contentType)
                        .setMetadata(Map.of("firebaseStorageDownloadTokens", token))
                        .build();
                bucket.getStorage().create(blobInfo, bytes);
                uploadedBlobIds.add(blobId);

                String encodedName = URLEncoder.encode(objectName, StandardCharsets.UTF_8)
                        .replace("+", "%20");
                imageUrls.add("https://firebasestorage.googleapis.com/v0/b/%s/o/%s?alt=media&token=%s"
                        .formatted(bucket.getName(), encodedName, token));
            }
            return List.copyOf(imageUrls);
        } catch (Exception e) {
            deleteBlobsQuietly(bucket, uploadedBlobIds);
            throw e;
        }
    }

    public int deleteReportImages(String reporterUid, List<String> imageUrls) {
        if (imageUrls == null || imageUrls.isEmpty()) return 0;
        if (imageUrls.size() > REPORT_IMAGE_MAX_COUNT) {
            throw new IllegalArgumentException("한 번에 최대 3장의 사진만 정리할 수 있습니다.");
        }
        Bucket bucket = reportImageBucket();
        int deleted = 0;
        for (String imageUrl : new LinkedHashSet<>(imageUrls)) {
            String objectName = reportImageObjectName(bucket, reporterUid, imageUrl);
            if (objectName == null) continue;
            if (bucket.getStorage().delete(BlobId.of(bucket.getName(), objectName))) {
                deleted++;
            }
        }
        return deleted;
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
        Bucket bucket = reportImageBucket();
        return reportImageObjectName(bucket, reporterUid, imageUrl) != null;
    }

    private String reportImageObjectName(
            Bucket bucket,
            String reporterUid,
            String imageUrl) {
        try {
            URI uri = URI.create(imageUrl);
            if (!"https".equalsIgnoreCase(uri.getScheme())
                    || !"firebasestorage.googleapis.com".equalsIgnoreCase(uri.getHost())) {
                return null;
            }
            String pathPrefix = "/v0/b/" + bucket.getName() + "/o/";
            String rawPath = uri.getRawPath();
            if (rawPath == null || !rawPath.startsWith(pathPrefix)) return null;
            String objectName = URLDecoder.decode(
                    rawPath.substring(pathPrefix.length()), StandardCharsets.UTF_8);
            String ownerPrefix = "report-images/" + sanitizeForObjectName(reporterUid) + "/";
            return objectName.startsWith(ownerPrefix) ? objectName : null;
        } catch (IllegalArgumentException e) {
            return null;
        }
    }

    private Bucket reportImageBucket() {
        try {
            Bucket bucket = StorageClient.getInstance().bucket();
            if (bucket == null || bucket.getName() == null || bucket.getName().isBlank()) {
                throw new IllegalStateException("Firebase Storage bucket is not configured.");
            }
            return bucket;
        } catch (IllegalArgumentException e) {
            throw new IllegalStateException("Firebase Storage bucket is not configured.", e);
        }
    }

    private void deleteBlobsQuietly(Bucket bucket, List<BlobId> blobIds) {
        for (BlobId blobId : blobIds) {
            try {
                bucket.getStorage().delete(blobId);
            } catch (Exception cleanupError) {
                log.warn("부분 업로드된 제보 사진 정리에 실패했습니다. object={}", blobId.getName(), cleanupError);
            }
        }
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

    private String extensionFromContentType(String contentType) {
        return switch (contentType) {
            case "image/png" -> ".png";
            case "image/webp" -> ".webp";
            default -> ".jpg";
        };
    }

    private String sanitizeForObjectName(String value) {
        if (value == null || value.isBlank()) return "anonymous";
        return value.replaceAll("[^A-Za-z0-9._-]", "_");
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
        db.collection("notification_settings").document(firebaseUid).delete().get();
        result.put("reportImages", deleteReportImagePrefix(firebaseUid));
        result.put("uid", firebaseUid);
        return result;
    }

    private int deleteReportImagePrefix(String firebaseUid) {
        try {
            Bucket bucket = reportImageBucket();
            String prefix = "report-images/" + sanitizeForObjectName(firebaseUid) + "/";
            int deleted = 0;
            for (com.google.cloud.storage.Blob blob : bucket.list(
                    com.google.cloud.storage.Storage.BlobListOption.prefix(prefix)).iterateAll()) {
                if (blob.delete()) deleted++;
            }
            return deleted;
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

    /** 공공데이터 인메모리 캐시에서 매장명으로 매장 정보 조회 (Firestore 읽기 0). 없으면 null */
    private Map<String, Object> findGovStoreByName(String storeName) {
        if (storeName == null || storeName.isBlank()) return null;
        return cachedStores.stream()
                .filter(s -> storeName.equals(String.valueOf(s.get("storeName"))))
                .findFirst()
                .orElse(null);
    }

    private static String strOrNull(Object value) {
        return value != null ? value.toString() : null;
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
        String docId = favoriteDocId(firebaseUid, storeId);
        db.collection("favorites").document(docId).delete().get();
        // 8/7 docId 이스케이프 도입 전의 구 형식(원본 storeId 그대로) 문서도 함께 삭제 — 기존 찜 데이터 호환
        String legacyDocId = firebaseUid + "_" + storeId;
        if (!legacyDocId.equals(docId)) {
            db.collection("favorites").document(legacyDocId).delete().get();
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
                            .storeId(data.get("storeId") != null ? data.get("storeId").toString() : null)
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
                    item.put("createdAt", data.get("createdAt"));
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
                    item.put("createdAt", data.get("createdAt"));
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

        // 가까운 순 상위 후보군 + 날짜 시드 셔플 (같은 날 안정적, 다음 날 순서 변경)
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

    /** 가까운 순 정렬 후 상위 limit개를 날짜 시드로 셔플 (위치 없으면 셔플만) */
    private List<Map<String, Object>> nearestShuffled(List<Map<String, Object>> pool,
                                                      Double lat, Double lng, int limit, long seed) {
        List<Map<String, Object>> scored = new ArrayList<>(pool);
        if (lat != null && lng != null) {
            scored.sort((a, b) -> Double.compare(
                    haversine(lat, lng, parseLat(a), parseLng(a)),
                    haversine(lat, lng, parseLat(b), parseLng(b))));
            if (scored.size() > limit) {
                scored = new ArrayList<>(scored.subList(0, limit));
            }
        }
        Collections.shuffle(scored, new Random(seed));
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
                .quietHours(booleanOrDefault(data, "quietHours", defaults.getQuietHours()))
                .quietStart(stringOrDefault(data, "quietStart", defaults.getQuietStart()))
                .quietEnd(stringOrDefault(data, "quietEnd", defaults.getQuietEnd()))
                .build();
    }

    public NotificationSettingsDto saveNotificationSettings(
            String firebaseUid,
            NotificationSettingsDto requested) throws Exception {
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
            Map<String, Object> data = new HashMap<>();
            data.put("userId", uid);
            data.put("title", title);
            data.put("body", body);
            data.put("type", type != null && !type.isBlank() ? type : "admin");
            data.put("isRead", false);
            data.put("createdAt", createdAt);
            db.collection("notifications").document().set(data).get();
            sent++;
        }
        Map<String, Object> result = new HashMap<>();
        result.put("sent", sent);
        result.put("broadcast", targetUid == null || targetUid.isBlank());
        return result;
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
