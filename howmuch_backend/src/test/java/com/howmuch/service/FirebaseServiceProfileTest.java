package com.howmuch.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

class FirebaseServiceProfileTest {

    @Test
    void preservesExistingEmailWhenSocialProviderReturnsNoEmail() {
        assertEquals(
                "saved@example.com",
                FirebaseService.resolveProfileEmail("", " saved@example.com "));
        assertEquals(
                "saved@example.com",
                FirebaseService.resolveProfileEmail(null, "saved@example.com"));
    }

    @Test
    void usesNewEmailWhenSocialProviderReturnsOne() {
        assertEquals(
                "new@example.com",
                FirebaseService.resolveProfileEmail(" new@example.com ", "saved@example.com"));
    }

    @Test
    void preservesOrUpdatesProfileImageUrl() {
        assertEquals(
                "https://saved.example/profile.jpg",
                FirebaseService.resolveProfileImageUrl("", " https://saved.example/profile.jpg "));
        assertEquals(
                "https://new.example/profile.jpg",
                FirebaseService.resolveProfileImageUrl(
                        " https://new.example/profile.jpg ",
                        "https://saved.example/profile.jpg"));
    }
}
