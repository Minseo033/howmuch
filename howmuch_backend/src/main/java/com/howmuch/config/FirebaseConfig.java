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
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;

@Configuration
public class FirebaseConfig {

    @PostConstruct
    public void initFirebase() {
        try {
            InputStream serviceAccount = null;

            // 1) 환경변수 FIREBASE_CONFIG_PATH로 외부 파일 경로 지정 (Render Secret File 등)
            String configPath = System.getenv("FIREBASE_CONFIG_PATH");
            if (configPath != null && !configPath.isBlank()) {
                File file = new File(configPath);
                if (file.exists()) {
                    serviceAccount = new FileInputStream(file);
                    System.out.println("Firebase: 외부 파일에서 키 로드 → " + configPath);
                }
            }

            // 2) 환경변수가 없으면 classpath(로컬 개발용) 에서 탐색
            if (serviceAccount == null) {
                serviceAccount = getClass().getClassLoader()
                        .getResourceAsStream("firebase-service-account.json");
                if (serviceAccount != null) {
                    System.out.println("Firebase: classpath에서 키 로드");
                }
            }

            if (serviceAccount == null) {
                throw new RuntimeException("Firebase 자격 증명 키 파일을 찾을 수 없습니다. " +
                        "FIREBASE_CONFIG_PATH 환경변수 또는 src/main/resources/firebase-service-account.json 경로를 확인하십시오.");
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
