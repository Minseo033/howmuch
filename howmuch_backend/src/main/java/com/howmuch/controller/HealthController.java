package com.howmuch.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.beans.factory.annotation.Value;

import java.time.Instant;
import java.util.Map;

/** Load-balancer readiness probe. Deliberately avoids Firestore and third-party calls. */
@RestController
public class HealthController {
    @Value("${RENDER_GIT_COMMIT:}")
    private String deploymentCommit = "";

    @GetMapping("/healthz")
    public ResponseEntity<Map<String, Object>> health() {
        return ResponseEntity.ok(Map.of(
                "status", "ok",
                "commit", deploymentCommit,
                "time", Instant.now().toString()));
    }
}
