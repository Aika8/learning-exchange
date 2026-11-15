package app.realworld;

import application.realworld.RealMarketData;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Real-world data adapter that serves a recorded sample from the classpath ({@code real/sample.json}). Shipped because
 * the terms of use of live sources were not verified (ADR-0015): every value carries a {@code sample} source, and
 * clients show the «sample data» badge.
 *
 * <p>Pattern: Adapter + Anti-corruption layer — the file's shape (ISO dates, pairs) is translated into the port's
 * records here and nowhere else.
 */
public final class StaticSampleData implements RealMarketData {

    private final Source source;
    private final List<Quote> quotes = new ArrayList<>();
    private final Map<String, List<Point>> history = new java.util.HashMap<>();
    private final BaseRate baseRate;

    public StaticSampleData(JsonMapper json) {
        try (InputStream in = StaticSampleData.class.getResourceAsStream("/real/sample.json")) {
            JsonNode root = json.readTree(in);
            JsonNode s = root.get("source");
            source = new Source(s.get("id").asString(), s.get("name").asString(),
                    s.get("url").isNull() ? null : s.get("url").asString(), s.get("terms").asString(),
                    s.get("sample").asBoolean(), s.get("delayed").asBoolean());
            for (JsonNode q : root.get("quotes")) {
                List<Point> points = new ArrayList<>();
                for (JsonNode p : q.get("history")) {
                    points.add(new Point(date(p.get(0).asString()), p.get(1).asLong()));
                }
                String symbol = q.get("symbol").asString();
                history.put(symbol, List.copyOf(points));
                quotes.add(new Quote(symbol, q.get("base").asString(), q.get("quote").asString(), points.getLast().price(),
                        q.get("scale").asInt(), Instant.parse(q.get("asOf").asString()).toEpochMilli(), source));
            }
            JsonNode r = root.get("baseRate");
            List<RateDecision> decisions = new ArrayList<>();
            for (JsonNode d : r.get("history")) {
                decisions.add(new RateDecision(date(d.get(0).asString()), d.get(1).asLong()));
            }
            List<Long> upcoming = new ArrayList<>();
            for (JsonNode d : r.get("upcoming")) {
                upcoming.add(date(d.asString()));
            }
            baseRate = new BaseRate(r.get("bank").asString(), decisions.getLast().rateBps(),
                    Instant.parse(r.get("asOf").asString()).toEpochMilli(), List.copyOf(decisions), List.copyOf(upcoming), source);
        } catch (IOException e) {
            throw new UncheckedIOException("real/sample.json unreadable", e);
        }
    }

    private static long date(String iso) {
        return LocalDate.parse(iso).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli();
    }

    @Override
    public List<Quote> quotes() {
        return List.copyOf(quotes);
    }

    @Override
    public List<Point> history(String symbol) {
        return history.getOrDefault(symbol, List.of());
    }

    @Override
    public Optional<BaseRate> baseRate() {
        return Optional.of(baseRate);
    }
}
