package com.howmuch.service;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.lang.reflect.Constructor;
import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class ServiceConstructorInjectionTest {

    @Test
    void servicesWithTestConstructorsDeclareTheirInjectionConstructor() {
        assertSingleAutowiredConstructor(GeocodingService.class);
        assertSingleAutowiredConstructor(KakaoLocalService.class);
    }

    private void assertSingleAutowiredConstructor(Class<?> serviceType) {
        Constructor<?>[] candidates = Arrays.stream(serviceType.getDeclaredConstructors())
                .filter(constructor -> constructor.isAnnotationPresent(Autowired.class))
                .toArray(Constructor<?>[]::new);

        assertThat(candidates)
                .as("%s injection constructors", serviceType.getSimpleName())
                .hasSize(1);
    }
}
