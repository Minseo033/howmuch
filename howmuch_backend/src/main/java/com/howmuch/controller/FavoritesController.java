package com.howmuch.controller;

import com.howmuch.config.SessionAuthFilter;
import com.howmuch.dto.FavoriteRequest;
import com.howmuch.dto.FavoriteResponse;
import com.howmuch.service.FirebaseService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 찜하기 API 컨트롤러.
 * GET /api/favorites: 내 찜 목록 조회 (최신순)
 * POST /api/favorites: 찜 추가 (멱등 — 같은 매장 재추가해도 중복 생성 안 됨)
 * DELETE /api/favorites/{storeId}: 찜 해제 (멱등 — 없어도 성공)
 */
@Slf4j
@RestController
@RequestMapping("/api/favorites")
@RequiredArgsConstructor
public class FavoritesController {

    private final FirebaseService firebaseService;

    /** 내 찜 목록 조회 (GET /api/favorites) */
    @GetMapping
    public ResponseEntity<?> getFavorites(HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[FavoritesController] 찜 목록 조회 요청 - uid: {}", firebaseUid);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }
            List<FavoriteResponse> favorites = firebaseService.getFavorites(firebaseUid);
            return ResponseEntity.ok(favorites);
        } catch (Exception e) {
            log.error("[FavoritesController] 찜 목록 조회 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "찜 목록 조회 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 찜 추가 (POST /api/favorites) */
    @PostMapping
    public ResponseEntity<?> addFavorite(@RequestBody FavoriteRequest request,
                                         HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[FavoritesController] 찜 추가 요청 - uid: {}, storeId: {}", firebaseUid, request.getStoreId());

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }
            if (request.getStoreId() == null || request.getStoreId().isBlank()) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "storeId는 필수입니다."
                ));
            }
            if (request.getStoreId().length() > 200
                    || (request.getStoreName() != null && request.getStoreName().length() > 100)) {
                return ResponseEntity.badRequest().body(Map.of(
                        "success", false,
                        "message", "입력값이 허용 길이를 초과했습니다."
                ));
            }
            FavoriteResponse favorite = firebaseService.addFavorite(firebaseUid, request);
            return ResponseEntity.ok(favorite);
        } catch (Exception e) {
            log.error("[FavoritesController] 찜 추가 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "찜 추가 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }

    /** 찜 해제 (DELETE /api/favorites/{storeId}) */
    @DeleteMapping("/{storeId}")
    public ResponseEntity<?> removeFavorite(@PathVariable String storeId,
                                            HttpServletRequest httpRequest) {
        String firebaseUid = (String) httpRequest.getAttribute(SessionAuthFilter.UID_ATTRIBUTE);
        log.info("[FavoritesController] 찜 해제 요청 - uid: {}, storeId: {}", firebaseUid, storeId);

        try {
            if (firebaseUid == null || firebaseUid.isBlank()) {
                return ResponseEntity.status(401).body("인증 정보가 유효하지 않습니다.");
            }
            firebaseService.removeFavorite(firebaseUid, storeId);
            return ResponseEntity.ok(Map.of(
                    "success", true,
                    "storeId", storeId
            ));
        } catch (Exception e) {
            log.error("[FavoritesController] 찜 해제 중 오류 발생: ", e);
            return ResponseEntity.status(500).body(Map.of(
                    "success", false,
                    "message", "찜 해제 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
            ));
        }
    }
}