package com.howmuch.service;

import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 초간단 인메모리 레이트리밋 (슬라이딩 윈도우 근사).
 * 유저별로 윈도우(기본 1시간) 내 최대 요청 횟수를 제한합니다.
 * Render 단일 인스턴스 기준이며, 인스턴스 재시작 시 카운터는 초기화됩니다.
 */
@Component
public class SimpleRateLimiter {

    private static class WindowCounter {
        volatile long windowStartMillis;
        final AtomicInteger count = new AtomicInteger(0);
    }

    private final Map<String, WindowCounter> counters = new ConcurrentHashMap<>();

    /**
     * 요청 1회를 기록하고 허용 여부를 반환합니다.
     *
     * @param key           유저 식별자 (uid 등)
     * @param maxRequests   윈도우 내 최대 허용 횟수
     * @param windowMillis  윈도우 길이 (밀리초)
     * @return true면 허용, false면 한도 초과
     */
    public boolean tryAcquire(String key, int maxRequests, long windowMillis) {
        long now = System.currentTimeMillis();
        WindowCounter counter = counters.computeIfAbsent(key, k -> {
            WindowCounter c = new WindowCounter();
            c.windowStartMillis = now;
            return c;
        });

        synchronized (counter) {
            if (now - counter.windowStartMillis >= windowMillis) {
                counter.windowStartMillis = now;
                counter.count.set(0);
            }
            return counter.count.incrementAndGet() <= maxRequests;
        }
    }

    /** 메모리 누수 방지: 비활성 키 정리 (요청이 끊긴 유저의 카운터 제거) */
    public void evictIdle(long idleMillis) {
        long now = System.currentTimeMillis();
        counters.entrySet().removeIf(e -> now - e.getValue().windowStartMillis > idleMillis);
    }
}
