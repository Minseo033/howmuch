package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.dto.UserProfileResponse;
import org.springframework.stereotype.Service;
import jakarta.annotation.PostConstruct;
import java.util.ArrayList;
import java.util.List;

import java.util.HashMap;
import java.util.Map;

@Service
public class FirebaseService {

    private final Firestore db;
    private final List<Map<String, Object>> cachedStores = new ArrayList<>();

    public FirebaseService(Firestore db) {
        this.db = db;
    }

    @PostConstruct
    public void initAllStores() {
        try {
            System.out.println("앱 구동 시 전체 매장 데이터를 한 번만 로드합니다...");
            List<Map<String, Object>> stores = db.collection("stores")
                    .get().get().getDocuments().stream()
                    .map(DocumentSnapshot::getData)
                    .toList();
            cachedStores.addAll(stores);
            System.out.println("전체 매장 로드 완료: " + cachedStores.size() + "개");
        } catch (Exception e) {
            e.printStackTrace();
            System.err.println("전체 매장 데이터 로드 중 오류 발생!");
        }
    }

    public List<Map<String, Object>> getAllStores() {
        return cachedStores;
    }

    // 💡 화면 범위(Bounds) 기반 업소 조회 (정부 데이터 + 사용자 제보 통합)
    public java.util.List<Map<String, Object>> getStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) throws Exception {
        // 1. 정부 인증 업소 조회 (Blue) - 파이어베이스 과금 방지를 위해 메모리 캐시 사용!
        java.util.List<Map<String, Object>> govStores = cachedStores.stream()
                .filter(data -> {
                    try {
                        Object latObj = data.get("latitude");
                        Object lngObj = data.get("longitude");
                        if (latObj != null && lngObj != null) {
                            double lat = Double.parseDouble(latObj.toString());
                            double lng = Double.parseDouble(lngObj.toString());
                            return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
                        }
                    } catch (NumberFormatException e) {
                        return false;
                    }
                    return false;
                })
                .map(data -> {
                    Map<String, Object> map = new HashMap<>(data);
                    map.put("source", "GOV"); // 💡 소스 구분용 플래그
                    return map;
                })
                .limit(1000) // 클라이언트 부하를 위해 최대 1000개까지만 전달 (원래 300개였음)
                .toList();

        // 2. 사용자 제보 업소 조회 (Orange)
        java.util.List<Map<String, Object>> userStores = db.collection("stores_user")
                .whereGreaterThanOrEqualTo("latitude", minLat)
                .whereLessThanOrEqualTo("latitude", maxLat)
                .limit(200)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("source", "USER"); // 💡 소스 구분용 플래그
                    return data;
                })
                .filter(data -> {
                    try {
                        Object lngObj = data.get("longitude");
                        Object latObj = data.get("latitude");
                        if (lngObj != null && latObj != null) {
                            double lng = Double.parseDouble(lngObj.toString());
                            double lat = Double.parseDouble(latObj.toString());
                            return lng >= minLng && lng <= maxLng && lat >= minLat && lat <= maxLat;
                        }
                    } catch (NumberFormatException e) {
                        return false;
                    }
                    return false;
                })
                .toList();

        // 3. 통합 리스트 반환
        java.util.List<Map<String, Object>> combined = new java.util.ArrayList<>();
        combined.addAll(govStores);
        combined.addAll(userStores);
        return combined;
    }

    // 💡 사용자의 매장 제보 저장
    public String saveUserReport(com.howmuch.dto.UserReportRequest report) throws Exception {
        report.setStatus("PENDING");
        report.setCreatedAt(java.time.Instant.now().toString());

        DocumentReference docRef = db.collection("stores_user").document();
        ApiFuture<WriteResult> future = docRef.set(report);
        return docRef.getId();
    }

    // 💡 사용자의 제보 목록 조회
    public java.util.List<Map<String, Object>> getUserReports(String firebaseUid) throws Exception {
        return db.collection("stores_user")
                .whereEqualTo("reporterId", firebaseUid)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("id", doc.getId()); // 문서 ID 포함
                    return data;
                })
                .toList();
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
        future.get(); // 저장 완료 대기

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
