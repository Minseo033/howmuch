package com.howmuch.service;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.config.BeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;

import java.lang.reflect.Constructor;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class ServiceConstructorInjectionTest {

    @Test
    void servicesWithTestConstructorsDeclareTheirInjectionConstructor() {
        assertSingleAutowiredConstructor(GeocodingService.class);
        assertSingleAutowiredConstructor(KakaoLocalService.class);
    }

    /**
     * 테스트용 생성자를 더하면 Spring이 주입할 생성자를 고르지 못해 서버가 뜨지 않는다
     * (9/14 GeminiService, 10/6 WeatherService 배포 실패). 모든 컴포넌트를 검사한다.
     */
    @Test
    void everySpringComponentHasAnUnambiguousInjectionConstructor() throws Exception {
        ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(true);
        List<String> ambiguous = new ArrayList<>();
        for (BeanDefinition definition : scanner.findCandidateComponents("com.howmuch")) {
            Class<?> type = Class.forName(definition.getBeanClassName());
            Constructor<?>[] constructors = type.getDeclaredConstructors();
            if (constructors.length < 2) continue;
            long autowired = Arrays.stream(constructors)
                    .filter(constructor -> constructor.isAnnotationPresent(Autowired.class))
                    .count();
            boolean hasDefault = Arrays.stream(constructors).anyMatch(constructor -> constructor.getParameterCount() == 0);
            if (autowired == 1 || (autowired == 0 && hasDefault)) continue;
            ambiguous.add(type.getSimpleName());
        }

        assertThat(ambiguous).as("Spring cannot choose a constructor for these components").isEmpty();
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
