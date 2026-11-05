package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class FirebaseServiceImageValidationTest {

    private final ReportImageStorage imageStorage = mock(ReportImageStorage.class);
    private final FirebaseService service = new FirebaseService(
            mock(Firestore.class), imageStorage);

    @org.junit.jupiter.api.AfterEach
    void clearInterrupt() { Thread.interrupted(); }

    @org.junit.jupiter.params.ParameterizedTest
    @org.junit.jupiter.params.provider.ValueSource(booleans = {false, true})
    void compensatesFirstUploadBeforePropagatingSecondUploadInterruption(boolean cleanupAlsoInterrupted) throws Exception {
        byte[] jpeg = new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
        MockMultipartFile first = new MockMultipartFile("images", "first.jpg", "image/jpeg", jpeg);
        MockMultipartFile second = new MockMultipartFile("images", "second.jpg", "image/jpeg", jpeg);
        String uploadedUrl = "https://res.cloudinary.com/test/image/upload/first.jpg";
        InterruptedException uploadInterruption = new InterruptedException("second upload interrupted");
        InterruptedException cleanupInterruption = new InterruptedException("compensation interrupted");
        java.util.concurrent.atomic.AtomicBoolean cleanupObservedInterrupt = new java.util.concurrent.atomic.AtomicBoolean(true);
        when(imageStorage.upload(eq("user-1"), any(byte[].class), eq("image/jpeg")))
                .thenReturn(uploadedUrl).thenAnswer(invocation -> {
                    Thread.currentThread().interrupt();
                    throw uploadInterruption;
                });
        when(imageStorage.deleteOwned(eq("user-1"), any())).thenAnswer(invocation -> {
            cleanupObservedInterrupt.set(Thread.currentThread().isInterrupted());
            if (cleanupAlsoInterrupted) throw cleanupInterruption;
            return 1;
        });

        assertThatThrownBy(() -> service.uploadReportImages("user-1", List.of(first, second)))
                .isInstanceOf(java.util.concurrent.CancellationException.class).hasCause(uploadInterruption);

        verify(imageStorage).deleteOwned("user-1", List.of(uploadedUrl));
        assertThat(cleanupObservedInterrupt).isFalse();
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        if (cleanupAlsoInterrupted) assertThat(uploadInterruption.getSuppressed()).containsExactly(cleanupInterruption);
        else assertThat(uploadInterruption.getSuppressed()).isEmpty();
    }

    @Test
    void compensationInterruptionIsNotHiddenBehindAnOrdinaryUploadFailure() throws Exception {
        byte[] jpeg = new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
        MockMultipartFile first = new MockMultipartFile("images", "first.jpg", "image/jpeg", jpeg);
        MockMultipartFile second = new MockMultipartFile("images", "second.jpg", "image/jpeg", jpeg);
        String uploadedUrl = "https://res.cloudinary.com/test/image/upload/first.jpg";
        IllegalStateException original = new IllegalStateException("second upload failed");
        InterruptedException cleanup = new InterruptedException("compensation interrupted");
        when(imageStorage.upload(eq("user-1"), any(byte[].class), eq("image/jpeg")))
                .thenReturn(uploadedUrl).thenThrow(original);
        when(imageStorage.deleteOwned(eq("user-1"), any())).thenThrow(cleanup);

        assertThatThrownBy(() -> service.uploadReportImages("user-1", List.of(first, second)))
                .isInstanceOf(java.util.concurrent.CancellationException.class).hasCause(original);
        assertThat(original.getSuppressed()).containsExactly(cleanup);
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
        verify(imageStorage).deleteOwned("user-1", List.of(uploadedUrl));
    }

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

    @Test
    void uploadsValidatedBytesThroughTheConfiguredStorage() throws Exception {
        byte[] png = new byte[]{
                (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
        };
        MockMultipartFile image = new MockMultipartFile(
                "images", "price.png", "image/svg+xml", png);
        when(imageStorage.upload(eq("user-1"), any(byte[].class), eq("image/png")))
                .thenReturn("https://res.cloudinary.com/test/image/upload/v1/image.png");

        assertThat(service.uploadReportImages("user-1", List.of(image)))
                .containsExactly("https://res.cloudinary.com/test/image/upload/v1/image.png");
        verify(imageStorage).upload("user-1", png, "image/png");
    }

    @Test
    void removesEarlierUploadsWhenALaterImageFails() throws Exception {
        byte[] jpeg = new byte[]{(byte) 0xFF, (byte) 0xD8, (byte) 0xFF};
        MockMultipartFile first = new MockMultipartFile(
                "images", "first.jpg", "image/jpeg", jpeg);
        MockMultipartFile second = new MockMultipartFile(
                "images", "second.jpg", "image/jpeg", jpeg);
        String uploadedUrl = "https://res.cloudinary.com/test/image/upload/v1/first.jpg";
        when(imageStorage.upload(eq("user-1"), any(byte[].class), eq("image/jpeg")))
                .thenReturn(uploadedUrl)
                .thenThrow(new IllegalStateException("upload failed"));

        assertThatThrownBy(() -> service.uploadReportImages(
                "user-1", List.of(first, second)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("upload failed");
        verify(imageStorage).deleteOwned("user-1", List.of(uploadedUrl));
    }
}
