package application.review;

import application.StatementProjection;
import engine.Accounts;
import engine.Event;
import engine.Instrument;
import engine.Order;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Trading mistakes of one person in one session from the field guide's table B
 * (docs/teaching/field-guide-lessons.md). First batch: B2 entry before a report, B6 averaging down, B7 no exit plan,
 * B8 size after a loss, B10 revenge. Second batch: B1 chasing a move, B4 entry into a wide spread (from book
 * snapshots, {@link Quote}). B5 (buying before the open after a pre-open rise) is not detected: the simulation has no
 * pre-open phase in which prices move (see DECISIONS.md, LE-057). A pure function of the journalled events: no clock, no I/O, the same events give the same list.
 * It names what happened, it does not advise.
 *
 * <p>Only the person's own spot orders count (not margin sub-accounts, not orders a conditional generated). An
 * <i>entry</i> is an own BUY order that got at least one fill (spot is long-only). Realised profit of a sale and the
 * cost basis come from {@link StatementProjection} (average cost, fees included), so the rule lives in one place.
 */
public final class TradingMistakes {

    public enum Code { B1_CHASING_A_MOVE, B2_BEFORE_REPORT, B4_WIDE_SPREAD, B6_AVERAGING_DOWN, B7_NO_EXIT_PLAN, B8_SIZE_AFTER_LOSS, B10_REVENGE }

    /** {@code at}: simulation time it happened (B7: the end of the session). {@code detail}: the numbers, key=value. */
    public record Mistake(Code code, String instrument, long at, String detail) {}

    /**
     * One snapshot of the top of the book: best bid and best ask at simulation time {@code ts} (0 for an empty side).
     * The journal does not keep the book, so the caller hands the snapshots in (B4).
     */
    public record Quote(long ts, String instrument, long bid, long ask) {}

    static final long SIM_MINUTE = 60_000;
    /** B1: a rise of 5% within one session is "a large move of the same day" for the game's instruments. */
    static final long RISE_BPS = 500;
    /** B4: "several times the usual" — three times the session's median spread. */
    static final long SPREAD_FACTOR = 3;
    /** B4: below three snapshots a session median of the spread means nothing. */
    static final int MIN_QUOTES = 3;
    /** B8/B10: a decision this soon after a closed loss is still the loss talking (field guide: "within minutes"). */
    static final long AFTER_LOSS_WINDOW = 5 * SIM_MINUTE;
    /** B8: twice the usual size is a jump nobody plans by accident. */
    static final long SIZE_FACTOR = 2;
    /** B8: below three earlier orders "usual size" means nothing. */
    static final int MIN_EARLIER_ORDERS = 3;
    /** B2: the field guide's "within two sim days" of a scheduled report, in bank days. */
    static final long DAYS_BEFORE_REPORT = 2;

    private TradingMistakes() {
    }

    /**
     * @param events      the journal, in order, from its start (earlier sessions give the position and usual size)
     * @param account     the person's account id
     * @param from        session start, inclusive (simulation time)
     * @param to          session end, exclusive
     * @param dayMillis   one bank day in simulation milliseconds (the economy's day)
     */
    public static List<Mistake> find(List<Event> events, List<Instrument> instruments, String account, long from, long to,
                                     long dayMillis) {
        return find(events, instruments, account, from, to, dayMillis, List.of());
    }

    /**
     * As {@link #find(List, List, String, long, long, long)}, with book snapshots for B4.
     *
     * @param quotes top-of-book snapshots, any order; only those inside the session count (none: B4 finds nothing)
     */
    public static List<Mistake> find(List<Event> events, List<Instrument> instruments, String account, long from, long to,
                                     long dayMillis, List<Quote> quotes) {
        Map<String, List<Quote>> sessionQuotes = new HashMap<>();
        quotes.stream()
                .filter(q -> inSession(q.ts(), from, to) && q.bid() > 0 && q.ask() > q.bid())
                .sorted(Comparator.comparingLong(Quote::ts))
                .forEach(q -> sessionQuotes.computeIfAbsent(q.instrument(), k -> new ArrayList<>()).add(q));
        Map<String, Long> medianSpread = new HashMap<>();
        sessionQuotes.forEach((instrument, qs) -> {
            if (qs.size() >= MIN_QUOTES) {
                medianSpread.put(instrument, median(qs.stream().map(q -> q.ask() - q.bid()).toList()));
            }
        });
        Map<String, Long> firstPrice = new HashMap<>(); // instrument → price of its first trade in the session
        Map<String, Long> lastPrice = new HashMap<>();
        StatementProjection statement = new StatementProjection(instruments);
        statement.onEvents(events);
        List<StatementProjection.Line> trades = statement.statement(account, Long.MIN_VALUE, Long.MAX_VALUE).lines().stream()
                .filter(l -> l.kind() == StatementProjection.Kind.TRADE)
                .toList();
        long ownSides = events.stream()
                .mapToLong(e -> e instanceof Event.TradeExecuted t ? sides(t, account) : 0)
                .sum();
        long skip = ownSides - trades.size(); // the statement keeps a bounded number of lines
        Iterator<StatementProjection.Line> lines = trades.iterator();

        Set<Long> filledOrders = new HashSet<>();
        for (Event e : events) {
            if (e instanceof Event.TradeExecuted t) {
                filledOrders.add(t.buyOrderId());
            }
        }

        Map<String, long[]> position = new HashMap<>(); // instrument → {qty, cost}
        Map<String, List<Long>> entrySizes = new HashMap<>();
        Map<Long, Event.ConditionalPlaced> conditionals = new LinkedHashMap<>();
        Set<Long> generated = new HashSet<>();
        Map<String, Long> reportAt = new HashMap<>();
        Set<Long> averagedDown = new HashSet<>();
        Set<String> enteredInSession = new HashSet<>();
        long lastLossAt = Long.MIN_VALUE;
        long lastLoss = 0;
        Map<String, Long> lastLossAtByInstrument = new HashMap<>();
        Map<String, Long> lastLossByInstrument = new HashMap<>();
        List<Mistake> out = new ArrayList<>();

        for (Event e : events) {
            if (e.ts() >= to) {
                break; // the session is over: B7 looks at the position as it stood then
            }
            switch (e) {
                case Event.ConsensusPublished c -> reportAt.put(c.instrument(), c.reportAt());
                case Event.ConditionalPlaced c when c.account().equals(account) -> conditionals.put(c.conditionalId(), c);
                case Event.ConditionalCancelled c -> conditionals.remove(c.conditionalId());
                case Event.ConditionalTriggered c -> {
                    conditionals.remove(c.conditionalId());
                    generated.add(c.orderId());
                }
                case Event.OrderAccepted o when o.account().equals(account) && o.side() == Order.Side.BUY
                        && !generated.contains(o.orderId()) -> {
                    List<Long> earlier = entrySizes.computeIfAbsent(o.instrument(), k -> new ArrayList<>());
                    if (filledOrders.contains(o.orderId()) && inSession(o.ts(), from, to)) {
                        enteredInSession.add(o.instrument());
                        long sinceLoss = o.ts() - lastLossAt;
                        if (lastLossAt != Long.MIN_VALUE && sinceLoss <= AFTER_LOSS_WINDOW && earlier.size() >= MIN_EARLIER_ORDERS) {
                            long median = median(earlier);
                            if (o.qty() >= SIZE_FACTOR * median) {
                                out.add(new Mistake(Code.B8_SIZE_AFTER_LOSS, o.instrument(), o.ts(), "qty=" + o.qty()
                                        + " median=" + median + " lossAgoMs=" + sinceLoss + " loss=" + lastLoss));
                            }
                        }
                        Long lossAt = lastLossAtByInstrument.get(o.instrument());
                        if (lossAt != null && o.ts() - lossAt <= AFTER_LOSS_WINDOW) {
                            out.add(new Mistake(Code.B10_REVENGE, o.instrument(), o.ts(), "lossAgoMs=" + (o.ts() - lossAt)
                                    + " loss=" + lastLossByInstrument.get(o.instrument())));
                        }
                        Long first = firstPrice.get(o.instrument());
                        Long last = lastPrice.get(o.instrument());
                        // B1: the price the person saw (the last trade before the order) is well above the session's first.
                        if (first != null && (last - first) * 10_000 >= RISE_BPS * first) {
                            out.add(new Mistake(Code.B1_CHASING_A_MOVE, o.instrument(), o.ts(), "first=" + first
                                    + " last=" + last + " riseBps=" + (last - first) * 10_000 / first));
                        }
                        Long usual = medianSpread.get(o.instrument());
                        Quote seen = usual == null ? null : latest(sessionQuotes.get(o.instrument()), o.ts());
                        if (seen != null && seen.ask() - seen.bid() >= SPREAD_FACTOR * usual) {
                            out.add(new Mistake(Code.B4_WIDE_SPREAD, o.instrument(), o.ts(), "spread="
                                    + (seen.ask() - seen.bid()) + " median=" + usual + " quotedAt=" + seen.ts()));
                        }
                        Long report = reportAt.get(o.instrument());
                        if (report != null && o.ts() < report && report - o.ts() <= DAYS_BEFORE_REPORT * dayMillis) {
                            out.add(new Mistake(Code.B2_BEFORE_REPORT, o.instrument(), o.ts(), "reportAt=" + report
                                    + " daysBefore=" + Math.floorDiv(report - o.ts(), dayMillis)));
                        }
                    }
                    earlier.add(o.qty());
                }
                case Event.TradeExecuted t -> {
                    if (inSession(t.ts(), from, to)) {
                        firstPrice.putIfAbsent(t.instrument(), t.price());
                        lastPrice.put(t.instrument(), t.price());
                    }
                    for (long k = sides(t, account); k > 0; k--) {
                        if (skip > 0) {
                            skip--;
                            continue;
                        }
                        StatementProjection.Line l = lines.next();
                        if (l.margin()) {
                            continue;
                        }
                        long[] p = position.computeIfAbsent(l.instrument(), x -> new long[2]);
                        if (l.side() == Order.Side.BUY) {
                            // B6: the holding is worth less at this price than it cost (fees included), and it grows.
                            if (p[0] > 0 && l.price() * p[0] < p[1] && inSession(l.ts(), from, to) && averagedDown.add(l.refId())) {
                                out.add(new Mistake(Code.B6_AVERAGING_DOWN, l.instrument(), l.ts(), "price=" + l.price()
                                        + " avgCost=" + p[1] / p[0] + " held=" + p[0] + " added=" + l.qty()));
                            }
                            p[0] += l.qty();
                            p[1] += -l.amount();
                        } else {
                            p[0] -= l.qty();
                            p[1] -= l.amount() - l.realisedPnl();
                            if (p[0] <= 0 || p[1] < 0) {
                                p[0] = Math.max(0, p[0]);
                                p[1] = p[0] == 0 ? 0 : Math.max(0, p[1]);
                            }
                            if (l.realisedPnl() < 0) {
                                lastLossAt = l.ts();
                                lastLoss = l.realisedPnl();
                                lastLossAtByInstrument.put(l.instrument(), l.ts());
                                lastLossByInstrument.put(l.instrument(), l.realisedPnl());
                            }
                        }
                    }
                }
                default -> { }
            }
        }

        // B7: a position entered in this session and still open at its end, not covered by a waiting sell rule.
        position.entrySet().stream().sorted(Map.Entry.comparingByKey()).forEach(p -> {
            long held = p.getValue()[0];
            if (held > 0 && enteredInSession.contains(p.getKey())) {
                long covered = conditionals.values().stream()
                        .filter(c -> c.instrument().equals(p.getKey()) && c.side() == Order.Side.SELL)
                        .mapToLong(Event.ConditionalPlaced::qty)
                        .sum();
                if (covered < held) {
                    out.add(new Mistake(Code.B7_NO_EXIT_PLAN, p.getKey(), to, "held=" + held + " covered=" + covered));
                }
            }
        });
        out.sort(Comparator.comparingLong(Mistake::at));
        return List.copyOf(out);
    }

    private static boolean inSession(long ts, long from, long to) {
        return ts >= from && ts < to;
    }

    /** How many statement lines this trade gives the person: one per side they are on (two for a self-trade). */
    private static int sides(Event.TradeExecuted t, String account) {
        return (Accounts.owner(t.buyer()).equals(account) ? 1 : 0) + (Accounts.owner(t.seller()).equals(account) ? 1 : 0);
    }

    /** The last snapshot taken at or before {@code ts}, or null; {@code sorted} is in time order. */
    private static Quote latest(List<Quote> sorted, long ts) {
        Quote seen = null;
        for (Quote q : sorted) {
            if (q.ts() > ts) {
                break;
            }
            seen = q;
        }
        return seen;
    }

    /** The lower median: with an even count, the smaller of the two middle sizes. */
    private static long median(List<Long> sizes) {
        List<Long> sorted = sizes.stream().sorted().toList();
        return sorted.get((sorted.size() - 1) / 2);
    }
}
