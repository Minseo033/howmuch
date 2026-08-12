package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

class FirebaseServiceImageValidationTest {

    private final FirebaseService service = new FirebaseService(mock(Firestore.class));

    @Test
    void detectsSupportedImageSignaturesWithoutTrustingTheHeader() {
        assertThat(service.detectReportImageContentType(new byte[]{
                (byte) 0xFF, (byte) 0xD8, (byte) 0xFF
        })).isEqualTo("image/jpeg");
        assertThat(service.detectReportImageContentType(new byte[]{
                (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        })).isEqualTo("image/png");
        assertThat(service.detectReportImageContentType(new byte[]{
                0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50
        })).isEqualTo("image/webp");
    }

    @Test
    void rejectsSvgAndArbitraryBytesEvenWhenTheFilenameCouldLookLikeAnImage() {
        assertThat(service.detectReportImageContentType(
                "<svg><script /></svg>".getBytes())).isNull();
        assertThat(service.detectReportImageContentType(new byte[]{1, 2, 3, 4})).isNull();
    }
}
