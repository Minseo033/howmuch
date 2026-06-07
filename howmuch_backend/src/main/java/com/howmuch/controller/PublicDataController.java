package com.howmuch.controller;

import com.howmuch.service.PublicDataService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/api/public-data")
public class PublicDataController {

    private final PublicDataService publicDataService;

    public PublicDataController(PublicDataService publicDataService) {
        this.publicDataService = publicDataService;
    }

    @GetMapping("/sync")
    public Mono<String> syncData() {
        // 백그라운드에서 동기화 작업을 시작합니다.
        publicDataService.syncAllPublicDataInBackground();
        
        // 작업 시작 메시지를 즉시 반환하여 503 타임아웃 에러를 방지합니다.
        return Mono.just("전국 착한가격업소 데이터 동기화(약 12,000건)를 백그라운드에서 시작했습니다. " +
                         "진행 상황은 서버 터미널 로그를 통해 확인하실 수 있습니다.");
    }
}
