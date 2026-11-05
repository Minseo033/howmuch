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
        boolean range = false;
        List<Long> amounts = new ArrayList<>();
        int start = 0;
        for (int i = 0; i <= raw.length(); i++) {
            boolean atEnd = i == raw.length();
            char ch = atEnd ? '\0' : raw.charAt(i);
            if (atEnd || ch == '/' || isRangeSeparator(ch)) {
                if (amounts.size() == 4) return Optional.empty();
                Long amount = parseAmount(raw.substring(start, i));
                if (amount == null) return Optional.empty();
                amounts.add(amount);
                if (!atEnd && isRangeSeparator(ch)) range = true;
                start = i + 1;
            }
        }
        if (range && amounts.size() != 2) return Optional.empty();
        if (range && amounts.get(0) > amounts.get(1)) return Optional.empty();
        return Optional.of(new Value(List.copyOf(amounts), range));
    }

    private static boolean isRangeSeparator(char ch) {
        return ch == '~' || ch == '〜' || ch == '–' || ch == '-';
    }

    private static Long parseAmount(String part) {
        String token = part.trim();
        if (token.endsWith("원")) token = token.substring(0, token.length() - 1).trim();
        if (token.isEmpty()) return null;
        long amount = 0;
        int groupDigits = 0;
        boolean commaSeen = false;
        for (int i = 0; i < token.length(); i++) {
            char ch = token.charAt(i);
            if (ch == ',') {
                if (groupDigits == 0 || (commaSeen ? groupDigits != 3 : groupDigits > 3)) return null;
                commaSeen = true;
                groupDigits = 0;
            } else if (ch >= '0' && ch <= '9') {
                amount = amount * 10 + ch - '0';
                if (amount > MAX_AMOUNT) return null;
                groupDigits++;
            } else {
                return null;
            }
        }
        return groupDigits == 0 || (commaSeen && groupDigits != 3) ? null : amount;
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
