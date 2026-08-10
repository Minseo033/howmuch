package com.howmuch.service;

import com.google.api.core.ApiFuture;
import com.google.cloud.firestore.DocumentReference;
import com.google.cloud.firestore.DocumentSnapshot;
import com.google.cloud.firestore.Firestore;
import com.google.cloud.firestore.WriteResult;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.dto.UserProfileResponse;
import com.howmuch.dto.VisitResponseDto;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

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
    public List<Map<String, Object>> getStoresInBounds(double minLat, double maxLat, double minLng, double maxLng) throws Exception {
        // 1. 정부 인증 업소 조회 (Blue)
        List<Map<String, Object>> govStores = db.collection("stores")
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
                .collect(Collectors.toList());

        // 2. 사용자 제보 업소 조회 (Orange)
        List<Map<String, Object>> userStores = db.collection("stores_user")
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
                .collect(Collectors.toList());

        // 3. 통합 리스트 반환
        List<Map<String, Object>> combined = new ArrayList<>();
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

            Long savedAmt = parseLongSafely(data.get("savedAmount"));
            Long priceAmt = parseLongSafely(data.get("price"));
            Boolean isGov = parseBooleanSafely(data.get("isGov"));

            com.howmuch.dto.VisitResponseDto dto = com.howmuch.dto.VisitResponseDto.builder()
                    .id(doc.getId())
                    .visitedAt(data.get("visitedAt") != null ? data.get("visitedAt").toString() : null)
                    .storeName(data.get("storeName") != null ? data.get("storeName").toString() : null)
                    .savedAmount(savedAmt != null ? savedAmt : 0L)
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
                .collect(Collectors.toList()));
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

    // 💡 커뮤니티 피드 목록 조회 (최신순)
    public List<com.howmuch.dto.FeedResponseDto> getCommunityFeeds() throws Exception {
        var documents = db.collection("stores_user")
                .orderBy("createdAt", com.google.cloud.firestore.Query.Direction.DESCENDING)
                .get().get().getDocuments();

        List<com.howmuch.dto.FeedResponseDto> feeds = new ArrayList<>();
        Map<String, String> authorCache = new HashMap<>();

        for (DocumentSnapshot doc : documents) {
            Map<String, Object> data = doc.getData();
            if (data == null) continue;

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
        return feeds;
    }

    // 💡 커뮤니티 피드 상세 조회
    public com.howmuch.dto.FeedDetailResponseDto getCommunityFeedDetail(String id) throws Exception {
        DocumentSnapshot doc = db.collection("stores_user").document(id).get().get();
        if (!doc.exists()) {
            return null;
        }

        Map<String, Object> data = doc.getData();
        if (data == null) return null;

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
                .rejectReason(data.get("rejectReason") != null ? (String) data.get("rejectReason") : "")
                .build();
    }

    // 💡 내 알림 목록 조회
    public List<com.howmuch.dto.NotificationResponseDto> getNotifications(String firebaseUid) throws Exception {
        var documents = db.collection("notifications")
                .whereEqualTo("userId", firebaseUid)
                .get().get().getDocuments();

        List<com.howmuch.dto.NotificationResponseDto> notifications = new ArrayList<>();
        for (DocumentSnapshot doc : documents) {
            Map<String, Object> data = doc.getData();
            if (data == null) continue;

            Boolean isRead = parseBooleanSafely(data.get("isRead"));

            com.howmuch.dto.NotificationResponseDto dto = com.howmuch.dto.NotificationResponseDto.builder()
                    .id(doc.getId())
                    .title(data.get("title") != null ? data.get("title").toString() : "")
                    .body(data.get("body") != null ? data.get("body").toString() : "")
                    .type(data.get("type") != null ? data.get("type").toString() : "")
                    .isRead(isRead != null ? isRead : false)
                    .createdAt(data.get("createdAt") != null ? data.get("createdAt").toString() : "")
                    .build();

            notifications.add(dto);
        }

        // 최신순 정렬
        notifications.sort((a, b) -> {
            String aTime = a.getCreatedAt() != null ? a.getCreatedAt() : "";
            String bTime = b.getCreatedAt() != null ? b.getCreatedAt() : "";
            return bTime.compareTo(aTime);
        });

        return notifications;
    }

    // 💡 알림 읽음 처리
    public void markNotificationAsRead(String notificationId) throws Exception {
        DocumentReference docRef = db.collection("notifications").document(notificationId);
        docRef.update("isRead", true).get();
    }
}
