# 1단계: Java 21 + 프로젝트 Gradle Wrapper로 빌드
FROM eclipse-temurin:21-jdk AS build
WORKDIR /app
COPY . .
RUN chmod +x gradlew && ./gradlew clean test bootJar --no-daemon

# 2단계: 실행 이미지 (가볍게)
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /app/build/libs/*.jar app.jar

# Render에서 자동으로 PORT 환경변수를 주입해 줌
EXPOSE 8081

ENTRYPOINT ["java", "-jar", "app.jar"]
