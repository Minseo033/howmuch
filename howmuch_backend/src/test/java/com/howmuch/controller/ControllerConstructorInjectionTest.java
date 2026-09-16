package com.howmuch.controller;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class ControllerConstructorInjectionTest {

    @Test
    void controllersWithTestConvenienceConstructorsDeclareOneSpringConstructor() {
        for (Class<?> controller : new Class<?>[] {
                AuthController.class,
                AdminController.class,
                UserController.class,
                RecommendationController.class,
                LocationController.class
        }) {
            long autowiredConstructors = Arrays.stream(controller.getDeclaredConstructors())
                    .filter(constructor -> constructor.isAnnotationPresent(Autowired.class))
                    .count();
            assertThat(autowiredConstructors)
                    .as(controller.getSimpleName())
                    .isEqualTo(1);
        }
    }
}
