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

    // 💡 모든 업소 데이터를 가져오는 메서드 추가
    public java.util.List<Map<String, Object>> getAllStores() throws Exception {
        return db.collection("stores").get().get().getDocuments().stream()
                .map(DocumentSnapshot::getData)
                .toList();
    }

    // 💡 문서 개수를 가져오는 메서드 추가
    public long getStoreCount() throws Exception {
        return db.collection("stores").count().get().get().getCount();
    }

    // 💡 화면 범위(Bounds) 기반 업소 조회 (비용 보호를 위해 최대 500개로 제한)
    public java.util.List<Map<String, Object>> getStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) throws Exception {
        return db.collection("stores")
                .whereGreaterThanOrEqualTo("latitude", minLat)
                .whereLessThanOrEqualTo("latitude", maxLat)
                .limit(500) // 💡 중요: 줌 아웃 상태에서 너무 많은 데이터를 읽어 비용이 폭탄되는 것을 방지합니다.
                .get().get().getDocuments().stream()
                .map(DocumentSnapshot::getData)
                .filter(data -> {
                    Object lngObj = data.get("longitude");
                    if (lngObj instanceof Double lng) {
                        return lng >= minLng && lng <= maxLng;
                    }
                    return false;
                })
                .toList();
    }
}
