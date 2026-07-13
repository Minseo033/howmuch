package com.howmuch.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.cloud.firestore.Firestore;
import com.google.firebase.auth.FirebaseAuth;
import com.google.firebase.cloud.FirestoreClient;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.io.ByteArrayInputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.Base64;

@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void initFirebase() {
        try {
            InputStream serviceAccount = null;

            // 1) Base64 인코딩된 환경변수에서 로드 (Render 클라우드용 - 가장 안전)
            String base64Credentials = System.getenv("FIREBASE_CREDENTIALS_BASE64");
            if (base64Credentials != null && !base64Credentials.isBlank()) {
                byte[] decoded = Base64.getDecoder().decode(base64Credentials);
                serviceAccount = new ByteArrayInputStream(decoded);
                System.out.println("Firebase: Base64 환경변수에서 키 로드 (Render)");
            }

            // 2) 외부 파일 경로 (FIREBASE_CONFIG_PATH)
            if (serviceAccount == null) {
                String configPath = System.getenv("FIREBASE_CONFIG_PATH");
                if (configPath != null && !configPath.isBlank()) {
                    File file = new File(configPath);
                    if (file.exists()) {
                        serviceAccount = new FileInputStream(file);
                        System.out.println("Firebase: 외부 파일에서 키 로드 → " + configPath);
                    }
                }
            }

            // 3) classpath에서 탐색 (로컬 개발용)
            if (serviceAccount == null) {
                serviceAccount = getClass().getClassLoader()
                        .getResourceAsStream("firebase-service-account.json");
                if (serviceAccount != null) {
                    System.out.println("Firebase: classpath에서 키 로드");
                }
            }

            if (serviceAccount == null) {
                throw new RuntimeException("Firebase 자격 증명 키 파일을 찾을 수 없습니다. " +
                        "FIREBASE_CREDENTIALS_BASE64 환경변수 또는 src/main/resources/firebase-service-account.json 경로를 확인하십시오.");
            }

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                System.out.println("=========================================");
                System.out.println("=== Firebase Admin SDK 연동 환경 구축 성공 ===");
                System.out.println("=========================================");
            }
        } catch (Exception e) {
            System.err.println("Firebase 초기화 중 기술적 예외 발생");
            e.printStackTrace();
        }
    }

    @Bean
    public Firestore getFirestore() {
        return FirestoreClient.getFirestore();
    }

    @Bean
    public FirebaseAuth getFirebaseAuth() {
        return FirebaseAuth.getInstance();
    }
}

