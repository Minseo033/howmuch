package com.howmuch.service;

import com.howmuch.HowMuchApplication;
import jakarta.annotation.PostConstruct;
import org.junit.jupiter.api.Test;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.scheduling.annotation.EnableAsync;

import java.lang.reflect.Method;

import static org.assertj.core.api.Assertions.assertThat;

class FirebaseServiceStartupTest {

    @Test
    void storeCacheWarmupRunsAsynchronouslyAfterApplicationIsReady() throws Exception {
        Method warmup = FirebaseService.class.getMethod("warmStoreCaches");
        EventListener listener = warmup.getAnnotation(EventListener.class);

        assertThat(warmup.isAnnotationPresent(PostConstruct.class)).isFalse();
        assertThat(warmup.isAnnotationPresent(Async.class)).isTrue();
        assertThat(listener).isNotNull();
        assertThat(listener.value()).containsExactly(ApplicationReadyEvent.class);
        assertThat(HowMuchApplication.class.isAnnotationPresent(EnableAsync.class)).isTrue();
    }
}
