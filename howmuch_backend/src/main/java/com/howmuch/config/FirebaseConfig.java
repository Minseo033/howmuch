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
import java.io.InputStream;

@Configuration
public class FirebaseConfig {
    private boolean firebaseAvailable = false;

    @PostConstruct
    public void initFirebase() {
        try {
            InputStream serviceAccount = getClass().getClassLoader()
                    .getResourceAsStream("firebase-service-account.json");

            if (serviceAccount == null) {
                System.err.println("Firebase 자격 증명 키 파일이 없어 개발 모드로 실행합니다.");
                System.err.println("실제 데이터 연동이 필요하면 src/main/resources/firebase-service-account.json 파일을 추가하세요.");
                return;
            }

            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                firebaseAvailable = true;
                System.out.println("=========================================");
                System.out.println("=== Firebase Admin SDK 연동 환경 구축 성공 ===");
                System.out.println("=========================================");
            } else {
                firebaseAvailable = true;
            }
        } catch (Exception e) {
            System.err.println("Firebase 초기화 중 기술적 예외 발생");
            e.printStackTrace();
        }
    }

    @Bean
    public Firestore getFirestore() {
        if (!firebaseAvailable) {
            return null;
        }
        return FirestoreClient.getFirestore();
    }

    @Bean
    public FirebaseAuth getFirebaseAuth() {
        if (!firebaseAvailable) {
            return null;
        }
        return FirebaseAuth.getInstance();
    }
}
