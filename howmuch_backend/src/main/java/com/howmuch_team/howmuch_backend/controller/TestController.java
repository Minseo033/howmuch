package com.howmuch_team.howmuch_backend.controller;

import com.howmuch_team.howmuch_backend.service.FirebaseService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/test")
public class TestController {

    private final FirebaseService firebaseService;

    // 생성자를 통해 FirebaseService 의존성을 주입받습니다.
    public TestController(FirebaseService firebaseService) {
        this.firebaseService = firebaseService;
    }

    @GetMapping("/hello")
    public String sayHello() {
        return "Howmuch 백엔드 서버가 정상적으로 구동 중이며, 연결에 성공했습니다!";
    }

    // 데이터베이스 저장 테스트 URL: http://localhost:8081/api/test/save?id=user1&name=kim&email=test@test.com
    @GetMapping("/save")
    public String saveTest(@RequestParam String id, @RequestParam String name, @RequestParam String email) {
        try {
            return firebaseService.saveUserData(id, name, email);
        } catch (Exception e) {
            e.printStackTrace();
            return "저장 실패: " + e.getMessage();
        }
    }

    // 데이터베이스 조회 테스트 URL: http://localhost:8081/api/test/get?id=user1
    @GetMapping("/get")
    public String getTest(@RequestParam String id) {
        try {
            return firebaseService.getUserData(id);
        } catch (Exception e) {
            e.printStackTrace();
            return "조회 실패: " + e.getMessage();
        }
    }
}