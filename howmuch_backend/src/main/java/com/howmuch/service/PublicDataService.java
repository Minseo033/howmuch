package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import com.howmuch.dto.PublicStoreResponseDto;
import com.howmuch.dto.StoreDto;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.util.UriComponentsBuilder;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.net.URI;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class PublicDataService {

    private final WebClient webClient;
    private final GeocodingService geocodingService;
    private final Firestore firestore;

    private final String PUBLIC_SERVICE_KEY = "6d18dc89fe8fe9ca957848b14987ebfd9cc3ec91e227e3312d6dc7c61d49f263";
    private final String BASE_URL = "https://api.odcloud.kr/api/3045247/v1/uddi:12a36b40-6230-4401-b647-b8456a789c7f";

    public PublicDataService(WebClient.Builder webClientBuilder, GeocodingService geocodingService, Firestore firestore) {
        this.webClient = webClientBuilder.build();
        this.geocodingService = geocodingService;
        this.firestore = firestore;
    }

    /**
     * 모든 데이터를 백그라운드에서 동기화합니다.
     */
    public void syncAllPublicDataInBackground() {
        AtomicInteger totalSaved = new AtomicInteger(0);
        int perPage = 100;

        System.out.println(">>> [백그라운드] 전체 데이터 동기화 프로세스 시작...");

        fetchPage(1, 1)
                .flatMap(firstResponse -> {
                    int totalCount = firstResponse.getTotalCount();
                    int totalPages = (int) Math.ceil((double) totalCount / perPage);
                    
                    System.out.println(">>> [백그라운드] 총 데이터: " + totalCount + ", 총 페이지: " + totalPages);

                    return Flux.range(1, totalPages)
                            .concatMap(page -> {
                                System.out.println(">>> [동기화 진행 중] 페이지 " + page + " / " + totalPages + " (현재까지 " + totalSaved.get() + "개 완료)");
                                return fetchPage(page, perPage)
                                        .flatMapMany(response -> Flux.fromIterable(response.getData()))
                                        .flatMap(item -> geocodingService.getCoordinates(item.getAddress())
                                                .map(coords -> convertToStoreDto(item, coords))
                                                .flatMap(this::saveToFirestore)
                                                .doOnSuccess(v -> totalSaved.incrementAndGet())
                                                .onErrorResume(e -> {
                                                    System.err.println("항목 건너뜀 (에러): " + e.getMessage());
                                                    return Mono.empty();
                                                }), 3) // 동시성을 3으로 낮춰 안정성 강화
                                        .then(Mono.empty());
                            })
                            .then(Mono.fromRunnable(() -> {
                                System.out.println("=========================================");
                                System.out.println(">>> [동기화 완료] 총 " + totalSaved.get() + "개의 데이터를 저장했습니다.");
                                System.out.println("=========================================");
                            }));
                })
                .subscribeOn(Schedulers.boundedElastic()) // 별도 스레드에서 실행
                .subscribe(); // 비동기 실행 시작
    }

    private Mono<PublicStoreResponseDto> fetchPage(int page, int perPage) {
        URI targetUri = UriComponentsBuilder.fromHttpUrl(BASE_URL)
                .queryParam("serviceKey", PUBLIC_SERVICE_KEY)
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
                    System.err.println("페이지 호출 실패 (page=" + page + "): " + e.getMessage());
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

    private Mono<Void> saveToFirestore(StoreDto storeDto) {
        String docId = storeDto.getStoreName().replace("/", "-").replace(".", "").trim();
        if (docId.isEmpty()) docId = "Unknown_" + System.currentTimeMillis();

        final String finalDocId = docId;
        return Mono.<Void>fromCallable(() -> {
            try {
                firestore.collection("stores").document(finalDocId).set(storeDto).get();
                return null;
            } catch (Exception e) {
                System.err.println("Firestore 저장 실패: " + finalDocId + " (" + e.getMessage() + ")");
                return null; // 실패해도 프로세스는 계속 진행
            }
        }).subscribeOn(Schedulers.boundedElastic());
    }
}
