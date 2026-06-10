package com.howmuch.controller;

import com.howmuch.service.FirebaseService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/test")
public class TestController {

    private final FirebaseService firebaseService;

    public TestController(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
    }

    @GetMapping("/hello")
    public String sayHello() {
        return "Howmuch 백엔드 서버가 정상적으로 구동 중이며, 연결에 성공했습니다!";
    }

    @GetMapping("/save")
    public String saveTest(@RequestParam String id, @RequestParam String name, @RequestParam String email) {
        try {
            return firebaseService.saveUserData(id, name, email);
        } catch (Exception e) {
            e.printStackTrace();
            return "저장 실패: " + e.getMessage();
        }
    }

    @GetMapping("/get")
    public String getTest(@RequestParam String id) {
        try {
            return firebaseService.getUserData(id);
        } catch (Exception e) {
            e.printStackTrace();
            return "조회 실패: " + e.getMessage();
        }
    }

    @GetMapping("/all")
    public java.util.List<java.util.Map<String, Object>> getAllStores() {
        try {
            return firebaseService.getAllStores();
        } catch (Exception e) {
            e.printStackTrace();
            return java.util.Collections.emptyList();
        }
    }

    // 💡 화면 범위 내 업소 조회 URL: http://localhost:8081/api/test/bounds?minLat=37.5&maxLat=37.6&minLng=126.9&maxLng=127.0
    @GetMapping("/bounds")
    public java.util.List<java.util.Map<String, Object>> getStoresInBounds(
            @RequestParam double minLat, @RequestParam double maxLat,
            @RequestParam double minLng, @RequestParam double maxLng) {
        try {
            return firebaseService.getStoresInBounds(minLat, maxLat, minLng, maxLng);
        } catch (Exception e) {
            e.printStackTrace();
            return java.util.Collections.emptyList();
        }
    }
}
