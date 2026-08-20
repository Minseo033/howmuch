package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import com.howmuch.dto.PublicStoreResponseDto;
import com.howmuch.dto.StoreDto;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.util.UriComponentsBuilder;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;
import lombok.extern.slf4j.Slf4j;

import java.net.URI;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

@Service
@Slf4j
public class PublicDataService {

    private final WebClient webClient;
    private final GeocodingService geocodingService;
    private final Firestore firestore;
    private final String publicServiceKey;
    private final AtomicBoolean syncRunning = new AtomicBoolean(false);

    private static final String BASE_URL =
            "https://api.odcloud.kr/api/3045247/v1/uddi:12a36b40-6230-4401-b647-b8456a789c7f";

    public PublicDataService(
            WebClient.Builder webClientBuilder,
            GeocodingService geocodingService,
            Firestore firestore,
            @Value("${public-data.api-key:}") String publicServiceKey) {
        this.webClient = webClientBuilder.build();
        this.geocodingService = geocodingService;
        this.firestore = firestore;
        this.publicServiceKey = publicServiceKey == null ? "" : publicServiceKey.trim();
    }

    /**
     * 모든 데이터를 백그라운드에서 동기화합니다.
     */
    public boolean syncAllPublicDataInBackground() {
        if (publicServiceKey.isBlank()) {
            throw new IllegalStateException("PUBLIC_DATA_API_KEY is not configured.");
        }
        if (!syncRunning.compareAndSet(false, true)) {
            return false;
        }

        AtomicInteger totalSaved = new AtomicInteger(0);
        int perPage = 100;

        log.info("공공데이터 백그라운드 동기화를 시작합니다.");

        fetchPage(1, 1)
                .flatMap(firstResponse -> {
                    int totalCount = firstResponse.getTotalCount();
                    int totalPages = (int) Math.ceil((double) totalCount / perPage);
                    
                    log.info("공공데이터 동기화 대상: {}개, {}페이지", totalCount, totalPages);

                    return Flux.range(1, totalPages)
                            .concatMap(page -> {
                                log.info("공공데이터 동기화 진행: {}/{}페이지, {}개 저장",
                                        page, totalPages, totalSaved.get());
                                return fetchPage(page, perPage)
                                        .flatMapMany(response -> Flux.fromIterable(response.getData()))
                                        .flatMap(item -> geocodingService.getCoordinates(item.getAddress())
                                                .flatMap(coords -> {
                                                    Double latitude = coords.get("latitude");
                                                    Double longitude = coords.get("longitude");
                                                    if (latitude == null || longitude == null
                                                            || !Double.isFinite(latitude) || !Double.isFinite(longitude)
                                                            || latitude < -90 || latitude > 90
                                                            || longitude < -180 || longitude > 180) {
                                                        return Mono.empty();
                                                    }
                                                    return Mono.just(convertToStoreDto(item, coords));
                                                })
                                                .flatMap(this::saveToFirestore)
                                                .filter(Boolean.TRUE::equals)
                                                .doOnNext(saved -> totalSaved.incrementAndGet())
                                                .onErrorResume(e -> {
                                                    log.warn("공공데이터 항목 저장을 건너뜁니다: {}",
                                                            e.getClass().getSimpleName());
                                                    return Mono.empty();
                                                }), 3) // 동시성을 3으로 낮춰 안정성 강화
                                        .then(Mono.empty());
                            })
                            .then(Mono.fromRunnable(() -> {
                                log.info("공공데이터 동기화 완료: {}개 저장", totalSaved.get());
                            }));
                })
                .doFinally(signal -> syncRunning.set(false))
                .subscribeOn(Schedulers.boundedElastic()) // 별도 스레드에서 실행
                .subscribe(); // 비동기 실행 시작
        return true;
    }

    private Mono<PublicStoreResponseDto> fetchPage(int page, int perPage) {
        URI targetUri = UriComponentsBuilder.fromHttpUrl(BASE_URL)
                .queryParam("serviceKey", publicServiceKey)
                .queryParam("page", page)
                .queryParam("perPage", perPage)
                .build()
                .toUri();

        return webClient.get()
                .uri(targetUri)
                .retrieve()
                .bodyToMono(PublicStoreResponseDto.class)
                .timeout(java.time.Duration.ofSeconds(10)) // API 호출 타임아웃 10초
                .onErrorResume(e -> {
                    log.warn("공공데이터 페이지 호출 실패: page={}, error={}",
                            page, e.getClass().getSimpleName());
                    return Mono.empty();
                });
    }

    private StoreDto convertToStoreDto(PublicStoreResponseDto.StoreItem item, Map<String, Double> coords) {
        return StoreDto.builder()
                .cityProvince(item.getCityProvince())
                .cityDistrict(item.getCityDistrict())
                .industry(item.getIndustry())
                .storeName(item.getStoreName() != null ? item.getStoreName().trim() : "Unknown")
                .phoneNumber(item.getPhoneNumber())
                .address(item.getAddress())
                .menu1(item.getMenu1())
                .price1(item.getPrice1())
                .menu2(item.getMenu2())
                .price2(item.getPrice2())
                .menu3(item.getMenu3())
                .price3(item.getPrice3())
                .menu4(item.getMenu4())
                .price4(item.getPrice4())
                .latitude(coords.get("latitude"))
                .longitude(coords.get("longitude"))
                .build();
    }

    Mono<Boolean> saveToFirestore(StoreDto storeDto) {
        // 💡 문서 ID를 "업소명_시도_시군구" 형태로 만들어 중복 덮어쓰기 방지
        String safeName = storeDto.getStoreName() != null ? storeDto.getStoreName().replace("/", "-").replace(".", "").trim() : "Unknown";
        String city = storeDto.getCityProvince() != null ? storeDto.getCityProvince().trim() : "";
        String district = storeDto.getCityDistrict() != null ? storeDto.getCityDistrict().trim() : "";
        
        String docId = String.format("%s_%s_%s", safeName, city, district).replaceAll("\\s+", "_");
        if (docId.startsWith("Unknown_")) docId = docId + "_" + System.currentTimeMillis();

        final String finalDocId = docId;
        return Mono.fromCallable(() -> {
            try {
                firestore.collection("stores").document(finalDocId).set(storeDto).get();
                return true;
            } catch (Exception e) {
                log.warn("공공데이터 Firestore 저장 실패: {}", e.getClass().getSimpleName());
                return false; // 한 항목 실패가 전체 동기화를 중단시키지는 않습니다.
            }
        }).subscribeOn(Schedulers.boundedElastic());
    }
}
