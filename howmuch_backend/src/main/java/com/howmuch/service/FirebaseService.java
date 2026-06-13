package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.Map;

@Service
public class FirebaseService {

    private final Firestore db;

    public FirebaseService(Firestore db) {
        this.db = db;
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
        // 1. 정부 인증 업소 조회 (Blue)
        java.util.List<Map<String, Object>> govStores = db.collection("stores")
                .whereGreaterThanOrEqualTo("latitude", minLat)
                .whereLessThanOrEqualTo("latitude", maxLat)
                .limit(300)
                .get().get().getDocuments().stream()
                .map(doc -> {
                    Map<String, Object> data = new HashMap<>(doc.getData());
                    data.put("source", "GOV"); // 💡 소스 구분용 플래그
                    return data;
                })
                .filter(data -> {
                    Object lngObj = data.get("longitude");
                    if (lngObj instanceof Double lng) {
                        return lng >= minLng && lng <= maxLng;
                    }
                    return false;
                })
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
                    Object lngObj = data.get("longitude");
                    if (lngObj instanceof Double lng) {
                        return lng >= minLng && lng <= maxLng;
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
        DocumentReference docRef = db.collection("stores_user").document();
        ApiFuture<WriteResult> future = docRef.set(report);
        return docRef.getId();
    }
}
