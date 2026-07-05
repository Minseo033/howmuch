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

    public String saveUserData(String userId, String name, String email) throws Exception {
        Map<String, Object> docData = new HashMap<>();
        docData.put("name", name);
        docData.put("email", email);

        ApiFuture<WriteResult> future = db.collection("users").document(userId).set(docData);

        return "데이터 저장 완료 시간: " + future.get().getUpdateTime();
    }

    public String getUserData(String userId) throws Exception {
        DocumentReference docRef = db.collection("users").document(userId);
        ApiFuture<DocumentSnapshot> future = docRef.get();
        DocumentSnapshot document = future.get();

        if (document.exists()) {
            return document.getData().toString();
        } else {
            return "해당 ID를 가진 유저 데이터가 존재하지 않습니다.";
        }
    }

    // 💡 문서 개수를 가져오는 메서드 추가
    public long getStoreCount() throws Exception {
        return db.collection("stores").count().get().get().getCount();
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
