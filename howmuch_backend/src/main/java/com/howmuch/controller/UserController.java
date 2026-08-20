package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.UserProfileRequest;
import com.howmuch.dto.UserProfileResponse;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.regex.Pattern;

@Slf4j
@RestController
@RequestMapping("/api/user")
@RequiredArgsConstructor
public class UserController {

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
            "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$");

    private final FirebaseService firebaseService;

    /**
     * 유저 프로필 저장
     * 세션 토큰(SessionAuthFilter)으로 인증된 uid 기준으로 Firestore에 저장
     */
    @PostMapping("/profile")
    public ResponseEntity<?> saveUserProfile(
            HttpServletRequest httpRequest,
            @RequestBody UserProfileRequest request) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            ResponseEntity<?> validationError = validateAndNormalize(request);
            if (validationError != null) return validationError;
            UserProfileResponse response = firebaseService.saveUserProfile(firebaseUid, request);
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", e.getMessage()));
        } catch (Exception e) {
            log.error("[UserController] 프로필 저장 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "프로필 저장 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }

    private ResponseEntity<?> validateAndNormalize(UserProfileRequest request) {
        if (request == null || request.getNickname() == null
                || request.getNickname().isBlank()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "닉네임은 필수입니다."));
        }
        String nickname = request.getNickname().trim();
        String email = request.getEmail() == null ? "" : request.getEmail().trim();
        String region = request.getRegion() == null ? "" : request.getRegion().trim();
        if (nickname.length() > 50 || email.length() > 254 || region.length() > 100) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "프로필 입력값이 허용 길이를 초과했습니다."));
        }
        if (!email.isEmpty() && !EMAIL_PATTERN.matcher(email).matches()) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "이메일 형식을 확인해주세요."));
        }
        List<String> categories = request.getFavoriteCategories() == null
                ? List.of()
                : request.getFavoriteCategories().stream()
                        .filter(value -> value != null && !value.isBlank())
                        .map(String::trim)
                        .distinct()
                        .toList();
        if (categories.size() > 20 || categories.stream().anyMatch(value -> value.length() > 50)) {
            return ResponseEntity.badRequest().body(Map.of(
                    "success", false, "message", "관심 카테고리 입력값을 확인해주세요."));
        }
        request.setNickname(nickname);
        request.setEmail(email);
        request.setRegion(region);
        request.setFavoriteCategories(categories);
        return null;
    }

    /**
     * 유저 프로필 조회
     * 세션 토큰(SessionAuthFilter)으로 인증된 uid 기준으로 Firestore에서 조회.
     * 데이터가 있으면 200 OK + UserProfileResponse, 없으면 404 반환
     */
    @GetMapping("/profile")
    public ResponseEntity<?> getUserProfile(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            UserProfileResponse response = firebaseService.getUserProfile(firebaseUid);
            if (response == null) {
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.ok(response);
        } catch (Exception e) {
            log.error("[UserController] 프로필 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "프로필 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }

    /**
     * 회원 탈퇴 (DELETE /api/user)
     * 세션 인증된 본인 계정만 탈퇴 가능. users 문서 + 제보/리뷰/방문/찜 전부 삭제.
     */
    @DeleteMapping
    public ResponseEntity<?> deleteUser(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        try {
            java.util.Map<String, Object> result = firebaseService.deleteUser(firebaseUid);
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            log.error("[UserController] 회원 탈퇴 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "회원 탈퇴 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."));
        }
    }
}
