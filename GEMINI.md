# Project: howmuch

## 개요
- **서비스명**: howmuch (고물가 시대 대응 생활밀착형 서비스 가격 비교 및 탐색 플랫폼)
- **핵심 기능**: 외식비, 미용비, 세탁비 등 주변의 저렴한 소상공인 및 업소 정보 제공
- **데이터 원천**: 공공데이터포털 '착한가격업소' 오픈 API

## 기술 스택 (Tech Stack)
- **Backend**: Java 21, Spring Boot 3.4.0
- **Frontend**: Flutter 3.44.0 (Stable Channel)
- **Infrastructure & Database**: Firebase Cloud Firestore, Firebase Admin SDK
- **External APIs**: 공공데이터 착한가격업소 API, Kakao Map Open API, Gemini API

## 아키텍처 및 개발 원칙
- **Backend**: Controller - Service - Repository/DAO 레이어 아키텍처 준수.
- **Data Exchange**: Frontend-Backend 간 데이터 교환 시 타입 세이프(Type-safe) DTO 및 JSON 직렬화 필수.
- **품질 기준**: 예외 처리, 비동기 스레드 안정성(Thread-safety), 가독성 및 보안 최우선.
- **디렉터리 구조**:
    - Root: `~\IdeaProjects\howmuch`
    - Backend: `howmuch_backend`
    - Frontend: `lib` (Flutter app)

## AI 보조 지침
- 모든 코드 생성 및 리팩토링은 위 아키텍처와 기술 스택을 엄격히 준수한다.
- 불확실한 정보는 추측하지 않고 팩트에 기반하여 건조하고 전문적인 어조로 답변한다.
- 프로덕션 레벨의 코드 품질(에러 핸들링, 보안 등)을 유지한다.
