package application;

import engine.Event;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Daily candles (open, high, low, close, volume) per instrument from trades, one bank day per candle, for the price
 * charts (the dividend ex-date is marked on them). Keeps the last {@link #KEPT} days.
 *
 * <p>Pattern: Event Sourcing projection. Not thread-safe: sequencer thread only.
 */
public final class CandleProjection implements MarketListener {

    static final int KEPT = 365;

    public record Candle(long start, long open, long high, long low, long close, long volume) {}

    private final long bucket;
    private final Map<String, Deque<long[]>> candles = new HashMap<>();

    public CandleProjection(long bucketMillis) {
        this.bucket = bucketMillis;
    }

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            if (e instanceof Event.TradeExecuted t) {
                long start = Math.floorDiv(t.ts(), bucket) * bucket;
                Deque<long[]> q = candles.computeIfAbsent(t.instrument(), k -> new ArrayDeque<>());
                long[] last = q.peekLast();
                if (last == null || last[0] < start) {
                    q.addLast(new long[] {start, t.price(), t.price(), t.price(), t.price(), t.qty()});
                    while (q.size() > KEPT) {
                        q.removeFirst();
                    }
                } else {
                    last[2] = Math.max(last[2], t.price());
                    last[3] = Math.min(last[3], t.price());
                    last[4] = t.price();
                    last[5] += t.qty();
                }
            }
        }
    }

    public List<Candle> candles(String instrument, int limit) {
        Deque<long[]> q = candles.getOrDefault(instrument, new ArrayDeque<>());
        return q.stream().skip(Math.max(0, q.size() - limit))
                .map(c -> new Candle(c[0], c[1], c[2], c[3], c[4], c[5])).toList();
    }
}
