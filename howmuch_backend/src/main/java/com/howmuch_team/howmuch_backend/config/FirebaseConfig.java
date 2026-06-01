package com.howmuch_team.howmuch_backend.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import org.springframework.context.annotation.Configuration;

import jakarta.annotation.PostConstruct;
import java.io.InputStream;

@Configuration // 스프링 부트 설정 클래스로 등록
public class FirebaseConfig {

    @PostConstruct // 서버가 켜질 때 딱 한 번만 실행되도록 설정
    public void initFirebase() {
        try {
            // src/main/resources/ 폴더에 저장한 키 파일을 읽어옵니다.
            InputStream serviceAccount = getClass().getClassLoader()
                    .getResourceAsStream("firebase-service-account.json");

            if (serviceAccount == null) {
                throw new RuntimeException("Firebase 자격 증명 키 파일을 찾을 수 없습니다. 경로를 확인하십시오.");
            }

            // Firebase 환경 옵션 설정
            FirebaseOptions options = FirebaseOptions.builder()
                    .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                    .build();

            // 중복 초기화 방지 처리 후 연동 완료
            if (FirebaseApp.getApps().isEmpty()) {
                FirebaseApp.initializeApp(options);
                System.out.println("=========================================");
                System.out.println("=== Firebase Admin SDK 연동 환경 구축 성공 ===");
                System.out.println("=========================================");
            }
        } catch (Exception e) {
            System.err.println("Firebase 초기화 중 기술적 예외 에러 발생");
            e.printStackTrace();
        }
    }
}