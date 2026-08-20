package com.howmuch.service;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verifyNoInteractions;

class SavingsServiceValidationTest {

    @Test
    void rejectsUnknownPeriodInsteadOfSilentlyUsingCurrentMonth() {
        FirebaseService firebaseService = mock(FirebaseService.class);
        SavingsService service = new SavingsService(firebaseService);

        assertThrows(IllegalArgumentException.class,
                () -> service.getSavingsStats("user-1", "this_weak"));
        verifyNoInteractions(firebaseService);
    }
}
