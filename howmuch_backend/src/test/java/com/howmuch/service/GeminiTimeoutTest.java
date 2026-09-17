package com.howmuch.service;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CompletableFuture;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assertions.assertTimeout;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

class GeminiTimeoutTest {
    @Test
    void slowResponseUsesOneTotalBudgetAndCancelsTheRequest() {
        HttpClient client = mock(HttpClient.class);
        CompletableFuture<HttpResponse<String>> pending = new CompletableFuture<>();
        when(client.sendAsync(any(), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any()))
                .thenReturn(pending);
        GeminiService service = new GeminiService("test-key", 80, false, "test-model", client);

        assertTimeout(Duration.ofSeconds(2), () ->
                assertThat(service.isAiFailureResponse(service.getAiResponse("hello"))).isTrue());
        assertThat(pending.isCancelled()).isTrue();
        verify(client, times(1)).sendAsync(any(), any());
    }

    @Test
    void cachedModelIsNotRetriedTwiceAndCompatibilityRetrySharesDeadline() {
        HttpClient client = mock(HttpClient.class);
        var ok = response(200);
        var badConfig = response(400);
        var missing = response(404);
        when(client.sendAsync(any(), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any()))
                .thenReturn(ok, badConfig, missing, ok);
        GeminiService service = new GeminiService("test-key", 20_000, false, "test-model", client);
        assertThat(service.getAiResponse("first")).isEqualTo("ok");
        assertThat(service.getAiResponse("second")).isEqualTo("ok");

        ArgumentCaptor<HttpRequest> requests = ArgumentCaptor.forClass(HttpRequest.class);
        verify(client, times(4)).sendAsync(requests.capture(), any());
        var sent = requests.getAllValues();
        assertThat(sent.get(1).uri()).isEqualTo(sent.get(2).uri());
        assertThat(sent.get(3).uri()).isNotEqualTo(sent.get(2).uri());
        assertThat(sent.get(2).timeout().orElseThrow()).isLessThan(sent.get(1).timeout().orElseThrow());
        assertThat(sent.get(0).timeout().orElseThrow()).isLessThanOrEqualTo(Duration.ofSeconds(12));
        assertThat(sent).allSatisfy(request -> assertThat(request.method()).isEqualTo("POST"));
    }

    @Test
    void invalidKeyStopsWithoutProbingMoreModels() {
        HttpClient client = mock(HttpClient.class);
        var forbidden = response(403);
        when(client.sendAsync(any(), org.mockito.ArgumentMatchers.<HttpResponse.BodyHandler<String>>any()))
                .thenReturn(forbidden);
        GeminiService service = new GeminiService("test-key", 1000, false, "test-model", client);
        assertThat(service.isAiFailureResponse(service.getAiResponse("hello"))).isTrue();
        verify(client, times(1)).sendAsync(any(), any());
    }

    @SuppressWarnings("unchecked")
    private CompletableFuture<HttpResponse<String>> response(int status) {
        HttpResponse<String> response = mock(HttpResponse.class);
        when(response.statusCode()).thenReturn(status);
        when(response.body()).thenReturn("{\"candidates\":[{\"content\":{\"parts\":[{\"text\":\"ok\"}]}}]}");
        return CompletableFuture.completedFuture(response);
    }
}
