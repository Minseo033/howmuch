package com.howmuch.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.io.ClassPathResource;
import org.springframework.test.util.ReflectionTestUtils;

import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Explicit local ranking-only comparison; weather, network, credentials and Firebase are excluded. */
public final class TodaysPickBenchmark {
    public static void main(String[] args) throws Exception {
        int runs = args.length == 0 ? 7 : Integer.parseInt(args[0]);
        if (runs < 1 || runs > 30) throw new IllegalArgumentException("Use 1..30 runs");
        var mapper = new ObjectMapper();
        List<Map<String, Object>> raw;
        try (var input = new ClassPathResource("stores-snapshot.json").getInputStream()) {
            raw = mapper.readValue(input, new TypeReference<>() {});
        }
        var service = new FirebaseService(null, null);
        service.setStoreHoursCatalog(new StoreHoursCatalog());
        ReflectionTestUtils.invokeMethod(service, "installGovStores", raw);
        int count = service.getAllStores().size(); // Already loaded home catalog, outside ranking measurement.
        var results = new ArrayList<Map<String, Object>>();
        var signatures = new LinkedHashMap<String, String>();
        for (String condition : List.of("맑음", "비")) {
            for (var city : List.of(new double[]{37.5665, 126.9780}, new double[]{37.4563, 126.7052}, new double[]{35.1796, 129.0756})) {
                for (int radius : List.of(1000, 3000)) {
                    String key = condition + ":" + city[0] + ":" + city[1] + ":" + radius;
                    double[] durations = new double[runs];
                    String expected = null;
                    for (int run = 0; run < runs; run++) {
                        long started = System.nanoTime();
                        var picks = service.getTodaysPicks(condition, 20, city[0], city[1], radius);
                        durations[run] = (System.nanoTime() - started) / 1_000_000.0;
                        String hash = java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                                .digest(mapper.writeValueAsBytes(picks)));
                        if (expected != null && !expected.equals(hash)) throw new AssertionError("Unstable recommendation " + key);
                        expected = hash;
                    }
                    signatures.put(key, expected);
                    java.util.Arrays.sort(durations);
                    results.add(Map.of("case", key, "medianMs", durations[runs / 2]));
                }
            }
        }
        double[] medians = results.stream().mapToDouble(row -> (double) row.get("medianMs")).sorted().toArray();
        var output = new LinkedHashMap<String, Object>();
        output.put("scope", "Local bundled catalog, already loaded, fixed weather; ranking only, not HTTP/UI latency");
        output.put("stores", count);
        output.put("runsPerCase", runs);
        output.put("cases", results);
        output.put("medianOfCaseMediansMs", medians[medians.length / 2]);
        output.put("resultSignatures", signatures);
        System.out.println("TODAYS_PICK_BENCHMARK " + mapper.writeValueAsString(output));
    }
}
