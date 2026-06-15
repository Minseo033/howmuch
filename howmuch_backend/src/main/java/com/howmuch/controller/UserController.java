package com.howmuch.controller;

import com.howmuch.dto.UserProfileRequest;
import com.howmuch.dto.UserProfileResponse;
import com.howmuch.service.FirebaseService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private final FirebaseService firebaseService;

    /**
     * 유저 프로필 저장
     * X-Firebase-Uid 헤더로 uid를 받아 Firestore에 저장 후 저장된 데이터 반환
     */
    @PostMapping("/profile")
    public ResponseEntity<?> saveUserProfile(
            @RequestHeader("X-Firebase-Uid") String firebaseUid,
            @RequestBody UserProfileRequest request) {
        try {
            log.info("[UserController] 프로필 저장 요청 - uid: {}", firebaseUid);
            UserProfileResponse response = firebaseService.saveUserProfile(firebaseUid, request);
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("[UserController] 프로필 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body("프로필 저장 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    /**
     * 유저 프로필 조회
     * X-Firebase-Uid 헤더로 uid를 받아 Firestore에서 조회.
     * 데이터가 있으면 200 OK + UserProfileResponse, 없으면 404 반환
     */
    @GetMapping("/profile")
    public ResponseEntity<?> getUserProfile(
            @RequestHeader("X-Firebase-Uid") String firebaseUid) {
        try {
            log.info("[UserController] 프로필 조회 요청 - uid: {}", firebaseUid);
            UserProfileResponse response = firebaseService.getUserProfile(firebaseUid);
            if (response == null) {
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("[UserController] 프로필 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body("프로필 조회 중 오류가 발생했습니다: " + e.getMessage());
        }
    }
}
