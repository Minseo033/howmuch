package com.howmuch.service;

import com.google.cloud.firestore.Firestore;
import org.junit.jupiter.api.Test;
import org.springframework.web.reactive.function.client.WebClient;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

class PublicDataServiceTest {

    @Test
    void refusesToStartWithoutAServerSideApiKey() {
        PublicDataService service = new PublicDataService(
                WebClient.builder(),
                mock(GeocodingService.class),
                mock(Firestore.class),
                "");

        assertThatThrownBy(service::syncAllPublicDataInBackground)
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("PUBLIC_DATA_API_KEY");
    }
}
