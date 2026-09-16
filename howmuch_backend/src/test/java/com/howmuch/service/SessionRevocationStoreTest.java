package com.howmuch.service;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class SessionRevocationStoreTest {

    @Test
    void usesStableOpaqueDocumentIdsForFirebaseStyleUids() {
        String kakaoUid = "kakao:123456789";

        String documentId = SessionRevocationStore.documentId(kakaoUid);

        assertThat(documentId).doesNotContain(kakaoUid).doesNotContain(":").doesNotContain("/");
        assertThat(documentId).isEqualTo(SessionRevocationStore.documentId(kakaoUid));
        assertThat(documentId).isNotEqualTo(SessionRevocationStore.documentId("kakao:123456780"));
    }
}
