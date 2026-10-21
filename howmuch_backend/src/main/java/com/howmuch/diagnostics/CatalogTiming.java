package com.howmuch.diagnostics;

import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;

/** Request-local measurements for the two synchronous public catalog endpoints. */
public final class CatalogTiming {
    private static final ThreadLocal<CatalogTiming> CURRENT = new ThreadLocal<>();
    private final long started = System.nanoTime();
    private final String requestId = UUID.randomUUID().toString();
    private final Map<String, Long> phases = new LinkedHashMap<>();
    private String sourceCache = "not_checked";
    private String mapCache = "not_checked";
    private int stores;
    private boolean warmingUp;

    private CatalogTiming() {}

    public static CatalogTiming begin() {
        CatalogTiming timing = new CatalogTiming();
        CURRENT.set(timing);
        return timing;
    }

    public static void clear() { CURRENT.remove(); }

    public static void record(String phase, long startedNanos) {
        CatalogTiming timing = CURRENT.get();
        if (timing != null) timing.phases.merge(phase, System.nanoTime() - startedNanos, Long::sum);
    }

    public static void source(String cache, int stores, boolean warmingUp) {
        CatalogTiming timing = CURRENT.get();
        if (timing != null) {
            timing.sourceCache = cache;
            timing.stores = stores;
            timing.warmingUp = warmingUp;
        }
    }

    public static void map(String cache) {
        CatalogTiming timing = CURRENT.get();
        if (timing != null) timing.mapCache = cache;
    }

    public String requestId() { return requestId; }
    public long elapsedNanos() { return System.nanoTime() - started; }

    public String serverTiming(long beforeWriteNanos) {
        StringBuilder header = new StringBuilder();
        phases.forEach((phase, nanos) -> header.append(phase).append(";dur=")
                .append(millis(nanos)).append(", "));
        return header.append("app_prewrite;dur=").append(millis(beforeWriteNanos)).toString();
    }

    public String summary() {
        return "source_cache=" + sourceCache + " map_cache=" + mapCache
                + " stores=" + stores + " warming_up=" + warmingUp;
    }

    public static String millis(long nanos) {
        return String.format(Locale.ROOT, "%.3f", nanos / 1_000_000.0);
    }
}
