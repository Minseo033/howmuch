package com.howmuch.controller;

import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;
import static org.assertj.core.api.Assertions.assertThat;

class HealthControllerTest {
    @Test
    void reportsTheDeployedRevisionWithoutReadingTheDatabase() {
        var controller = new HealthController();
        ReflectionTestUtils.setField(controller, "deploymentCommit", "revision-123");
        assertThat(controller.health().getBody())
                .containsEntry("status", "ok")
                .containsEntry("commit", "revision-123");
    }
}
