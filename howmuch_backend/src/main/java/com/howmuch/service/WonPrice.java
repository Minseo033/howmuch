package com.howmuch.service;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** Preserves alternatives/ranges instead of concatenating unrelated digits. */
public final class WonPrice {
    public static final long MAX_AMOUNT = 10_000_000L;
    private WonPrice() {}

    public record Value(List<Long> amounts, boolean range) {
        public boolean exact() { return amounts.size() == 1; }
        public long minimum() { return amounts.stream().mapToLong(Long::longValue).min().orElseThrow(); }
        public long maximum() { return amounts.stream().mapToLong(Long::longValue).max().orElseThrow(); }
    }

    public static Optional<Value> parse(Object input) {
        if (input == null) return Optional.empty();
        if (input instanceof Number number) {
            double value = number.doubleValue();
            if (!Double.isFinite(value) || value < 0 || value > MAX_AMOUNT || value != Math.rint(value)) {
                return Optional.empty();
            }
            return Optional.of(new Value(List.of(number.longValue()), false));
        }
        String raw = String.valueOf(input).trim();
        if (raw.isEmpty() || raw.startsWith("-")) return Optional.empty();
        boolean range = raw.matches(".*[~〜–-].*");
        String[] parts = raw.split("\\s*[/~〜–-]\\s*", -1);
        if (parts.length > 4 || (range && parts.length != 2)) return Optional.empty();
        List<Long> amounts = new ArrayList<>();
        for (String part : parts) {
            String token = part.trim().replaceFirst("원$", "").trim();
            if (!token.matches("(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)")) return Optional.empty();
            try {
                long amount = Long.parseLong(token.replace(",", ""));
                if (amount > MAX_AMOUNT) return Optional.empty();
                amounts.add(amount);
            } catch (NumberFormatException exception) { return Optional.empty(); }
        }
        if (range && amounts.get(0) > amounts.get(1)) return Optional.empty();
        return Optional.of(new Value(List.copyOf(amounts), range));
    }

    public static Long exactPositive(Object input) {
        return parse(input).filter(Value::exact).filter(value -> value.minimum() > 0)
                .map(Value::minimum).orElse(null);
    }

    public static Long menuMinimum(Object input, boolean free) {
        return parse(input).filter(value -> free
                ? value.exact() && value.minimum() == 0
                : value.minimum() > 0).map(Value::minimum).orElse(null);
    }
}
