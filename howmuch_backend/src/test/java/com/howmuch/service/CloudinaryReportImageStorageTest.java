package com.howmuch.service;

import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class CloudinaryReportImageStorageTest {

    private final CloudinaryReportImageStorage storage =
            new CloudinaryReportImageStorage(
                    "cloudinary://api-key:api-secret@test-cloud",
                    "howmuch/report-images");

    @Test
    void acceptsOnlyVersionedDeliveryUrlsOwnedByTheUser() {
        String publicId = storage.ownerPrefix("user-1") + "/asset-1";
        String imageUrl = "https://res.cloudinary.com/test-cloud/image/upload/v123/"
                + publicId + ".jpg";

        assertThat(storage.isOwnedBy("user-1", imageUrl)).isTrue();
        assertThat(storage.publicIdFromOwnedUrl("user-1", imageUrl))
                .isEqualTo(publicId);
        assertThat(storage.isOwnedBy("user-2", imageUrl)).isFalse();
    }

    @Test
    void rejectsForeignOrManipulatedCloudinaryUrls() {
        String publicId = storage.ownerPrefix("user-1") + "/asset-1";

        assertThat(storage.isOwnedBy("user-1",
                "https://res.cloudinary.com/other-cloud/image/upload/v1/"
                        + publicId + ".png")).isFalse();
        assertThat(storage.isOwnedBy("user-1",
                "http://res.cloudinary.com/test-cloud/image/upload/v1/"
                        + publicId + ".png")).isFalse();
        assertThat(storage.isOwnedBy("user-1",
                "https://res.cloudinary.com/test-cloud/image/upload/c_fill/v1/"
                        + publicId + ".png")).isFalse();
        assertThat(storage.isOwnedBy("user-1",
                "https://res.cloudinary.com/test-cloud/image/upload/v1/"
                        + publicId + "%2Fforeign.png")).isFalse();
        assertThat(storage.isOwnedBy("user-1",
                "https://res.cloudinary.com/test-cloud/image/upload/v1/"
                        + publicId + ".svg")).isFalse();
    }

    @Test
    void staysUnavailableWithoutServerCredentials() {
        CloudinaryReportImageStorage unconfigured =
                new CloudinaryReportImageStorage("", "howmuch/report-images");

        assertThat(unconfigured.isOwnedBy("user-1", "https://example.com/image.jpg"))
                .isFalse();
        assertThatThrownBy(() -> unconfigured.upload(
                "user-1", new byte[]{1}, "image/jpeg"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("not configured");
    }

    @Test
    void exposesOnlyNonSensitiveUsageFields() {
        Map<String, Object> usage = storage.sanitizeUsage(Map.of(
                "plan", "Free",
                "credits", Map.of("usage", 3.2, "limit", 25, "used_percent", 12.8),
                "storage", Map.of("usage", 1024),
                "api_key", "must-not-leak",
                "cloud_name", "must-not-leak"));

        assertThat(usage).containsEntry("plan", "Free")
                .containsKey("credits")
                .containsKey("storage")
                .doesNotContainKeys("api_key", "cloud_name");
    }
}
