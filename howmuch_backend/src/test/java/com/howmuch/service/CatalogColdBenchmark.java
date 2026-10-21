package com.howmuch.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.howmuch.controller.StoresController;
import com.howmuch.diagnostics.CatalogTiming;
import org.springframework.core.io.ClassPathResource;
import org.springframework.test.util.ReflectionTestUtils;

import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/** Opt-in local CPU/allocation comparison. No Firebase, HTTP, credentials or production writes. */
public final class CatalogColdBenchmark {
    public static void main(String[] args) throws Exception {
        int runs = args.length == 0 ? 7 : Integer.parseInt(args[0]);
        if (runs < 1 || runs > 30) throw new IllegalArgumentException("Use 1..30 runs");
        var mapper = new ObjectMapper();
        List<Map<String, Object>> raw;
        try (var input = new ClassPathResource("stores-snapshot.json").getInputStream()) {
            raw = mapper.readValue(input, new TypeReference<>() {});
        }
        var hours = new StoreHoursCatalog();
        var results = new ArrayList<Map<String, Object>>();
        byte[] referenceAll = null;
        byte[] referenceLight = null;
        String referenceTag = null;
        for (int run = 0; run < runs; run++) {
            var service = new FirebaseService(null, null);
            service.setStoreHoursCatalog(hours);
            long installStart = System.nanoTime();
            ReflectionTestUtils.invokeMethod(service, "installGovStores", raw);
            double installMs = millis(System.nanoTime() - installStart);
            var controller = new StoresController(service);
            var timing = CatalogTiming.begin();
            long lookupStart = System.nanoTime();
            var response = controller.getMapCatalog(null);
            long afterLookup = System.nanoTime();
            String phases = timing.serverTiming(afterLookup - lookupStart);
            byte[] light = mapper.writeValueAsBytes(response.getBody());
            long afterEncoding = System.nanoTime();
            CatalogTiming.clear();
            var full = service.getPublicStoreCatalog();
            byte[] all = mapper.writeValueAsBytes(full.stores());
            String allTag = "\"" + sha(all) + "\"";
            if (!allTag.equals(full.etag())) throw new AssertionError("ETag does not match full JSON");
            if (full.stores().size() != 11385) throw new AssertionError("Bundled store count changed");
            if (run == 0) {
                referenceAll = all;
                referenceLight = light;
                referenceTag = response.getHeaders().getETag();
            } else if (!Arrays.equals(referenceAll, all) || !Arrays.equals(referenceLight, light)
                    || !referenceTag.equals(response.getHeaders().getETag())) {
                throw new AssertionError("Identical snapshots produced inconsistent data/ETags");
            }
            if (response.getBody() != controller.getMapCatalog(null).getBody()) {
                throw new AssertionError("Warm response did not reuse its snapshot");
            }
            var result = new LinkedHashMap<String, Object>();
            result.put("run", run + 1);
            result.put("installMs", installMs);
            result.put("coldLookupMs", millis(afterLookup - lookupStart));
            result.put("responseEncodingMs", millis(afterEncoding - afterLookup));
            result.put("lookupPlusEncodingMs", millis(afterEncoding - lookupStart));
            result.put("serverPhases", phases);
            results.add(result);
        }
        var output = new LinkedHashMap<String, Object>();
        output.put("scope", "Bundled 11385 stores, fresh service caches in one local JVM; not Render or browser latency");
        output.put("allSha256", sha(referenceAll));
        output.put("catalogSha256", sha(referenceLight));
        output.put("allJsonBytes", referenceAll.length);
        output.put("catalogJsonBytes", referenceLight.length);
        output.put("mapEtag", referenceTag);
        output.put("runs", results);
        var sorted = results.stream().mapToDouble(row -> (double) row.get("lookupPlusEncodingMs")).sorted().toArray();
        output.put("lookupPlusEncodingMedianMs", sorted[sorted.length / 2]);
        var withInstall = results.stream().mapToDouble(row -> (double) row.get("installMs")
                + (double) row.get("lookupPlusEncodingMs")).sorted().toArray();
        output.put("installPlusLookupAndEncodingMedianMs", withInstall[withInstall.length / 2]);
        System.out.println("CATALOG_BENCHMARK " + mapper.writeValueAsString(output));
    }

    private static String sha(byte[] body) throws Exception {
        return java.util.HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(body));
    }

    private static double millis(long nanos) { return Math.round(nanos / 1000.0) / 1000.0; }
}
