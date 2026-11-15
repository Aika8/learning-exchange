package application;

import engine.Accounts;
import engine.Event;
import engine.Order;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import java.util.function.Function;

/**
 * The trade journal read model (M2c): every order a person placed, the note they attached (why, market state, mood,
 * planned risk) and what the order's fills came to. The session review groups results by mood and by market state,
 * in money and in R, so "my FOMO trades" become a number. It describes, it does not advise.
 *
 * <p>Result of an order: its fills measured against the mark price (the last price now), fees included —
 * BUY: (mark − price) × qty − fee; SELL: (price − mark) × qty − fee. One rule for entries and exits keeps it simple;
 * DECISIONS.md explains why not FIFO round-trips.
 *
 * <p>Pattern: Event Sourcing projection / CQRS read model. Not thread-safe: sequencer thread only.
 */
public final class SessionReviewProjection implements MarketListener {

    /** Orders kept per person (bots place many). */
    static final int KEPT = 5_000;

    public record Note(String why, String marketState, String mood, Long plannedRisk) {}

    public record Entry(long orderId, String instrument, Order.Side side, long placedAt, long qty, long filledQty,
                        Long avgPrice, Long markPrice, long fees, long result, Long resultRx100, Note note) {}

    public record Group(String key, int orders, int wins, long result, Long avgRx100) {}

    public record Review(long from, long to, String currency, List<Entry> entries, List<Group> byMood,
                         List<Group> byMarketState, int orders, int annotated, int wins, long result, Long expectancyRx100) {}

    private static final class OrderRow {
        final long orderId;
        final String instrument;
        final Order.Side side;
        final long ts;
        final long qty;
        long filled;
        long notional;
        long fees;
        Note note;

        OrderRow(Event.OrderAccepted o) {
            this.orderId = o.orderId();
            this.instrument = o.instrument();
            this.side = o.side();
            this.ts = o.ts();
            this.qty = o.qty();
        }
    }

    private final Map<String, LinkedHashMap<Long, OrderRow>> byOwner = new HashMap<>();
    private final Map<Long, OrderRow> byId = new HashMap<>();

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            switch (e) {
                case Event.OrderAccepted o when !Accounts.isSubAccount(o.account()) -> {
                    OrderRow row = new OrderRow(o);
                    LinkedHashMap<Long, OrderRow> rows = byOwner.computeIfAbsent(o.account(), k -> new LinkedHashMap<>());
                    rows.put(o.orderId(), row);
                    byId.put(o.orderId(), row);
                    if (rows.size() > KEPT) {
                        Long oldest = rows.keySet().iterator().next();
                        rows.remove(oldest);
                        byId.remove(oldest);
                    }
                }
                case Event.TradeExecuted t -> {
                    fill(byId.get(t.buyOrderId()), t, t.buyerFee());
                    fill(byId.get(t.sellOrderId()), t, t.sellerFee());
                }
                case Event.OrderAnnotated a -> {
                    OrderRow row = byId.get(a.orderId());
                    if (row != null) {
                        row.note = new Note(a.why(), a.marketState(), a.mood(), a.plannedRisk() > 0 ? a.plannedRisk() : null);
                    }
                }
                default -> { }
            }
        }
    }

    private static void fill(OrderRow row, Event.TradeExecuted t, long fee) {
        if (row != null) {
            row.filled += t.qty();
            row.notional += t.price() * t.qty();
            row.fees += fee;
        }
    }

    /** @param markPrice last price per instrument now */
    public Review review(String owner, long from, long to, Function<String, Long> markPrice) {
        List<Entry> entries = new ArrayList<>();
        for (OrderRow r : byOwner.getOrDefault(owner, new LinkedHashMap<>()).values()) {
            if (r.ts < from || r.ts >= to) {
                continue;
            }
            Long mark = markPrice.apply(r.instrument);
            long result = 0;
            if (r.filled > 0 && mark != null) {
                long markValue = mark * r.filled;
                result = (r.side == Order.Side.BUY ? markValue - r.notional : r.notional - markValue) - r.fees;
            } else {
                result = -r.fees;
            }
            Long rx100 = r.note != null && r.note.plannedRisk() != null && r.filled > 0
                    ? Math.floorDiv(result * 100, r.note.plannedRisk()) : null;
            entries.add(new Entry(r.orderId, r.instrument, r.side, r.ts, r.qty, r.filled,
                    r.filled > 0 ? r.notional / r.filled : null, mark, r.fees, result, rx100, r.note));
        }
        List<Entry> filled = entries.stream().filter(x -> x.filledQty() > 0).toList();
        int wins = (int) filled.stream().filter(x -> x.result() > 0).count();
        long total = filled.stream().mapToLong(Entry::result).sum();
        int annotated = (int) entries.stream().filter(x -> x.note() != null).count();
        return new Review(from, to, "SPARK", entries,
                group(filled, x -> x.note() == null || x.note().mood() == null ? "NONE" : x.note().mood()),
                group(filled, x -> x.note() == null || x.note().marketState() == null ? "NONE" : x.note().marketState()),
                entries.size(), annotated, wins, total, avgR(filled));
    }

    private static List<Group> group(List<Entry> entries, Function<Entry, String> key) {
        Map<String, List<Entry>> groups = new TreeMap<>();
        for (Entry e : entries) {
            groups.computeIfAbsent(key.apply(e), k -> new ArrayList<>()).add(e);
        }
        List<Group> out = new ArrayList<>();
        groups.forEach((k, list) -> out.add(new Group(k, list.size(), (int) list.stream().filter(x -> x.result() > 0).count(),
                list.stream().mapToLong(Entry::result).sum(), avgR(list))));
        return out;
    }

    private static Long avgR(List<Entry> entries) {
        List<Long> rs = entries.stream().map(Entry::resultRx100).filter(java.util.Objects::nonNull).toList();
        return rs.isEmpty() ? null : Math.floorDiv(rs.stream().mapToLong(Long::longValue).sum(), rs.size());
    }
}
