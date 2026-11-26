package application.review;

import static application.review.TradingMistakes.Code.B10_REVENGE;
import static application.review.TradingMistakes.Code.B2_BEFORE_REPORT;
import static application.review.TradingMistakes.Code.B6_AVERAGING_DOWN;
import static application.review.TradingMistakes.Code.B7_NO_EXIT_PLAN;
import static application.review.TradingMistakes.Code.B8_SIZE_AFTER_LOSS;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.review.TradingMistakes.Code;
import application.review.TradingMistakes.Mistake;
import engine.Conditional;
import engine.Event;
import engine.Instrument;
import engine.Order;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** One example per detector, built from hand-written journal events, and a clean session with no findings. */
class TradingMistakesTest {

    private static final String ME = "me";
    private static final String MM = "mm";
    private static final String SILK = "SILK-SPARK";
    private static final String AMBER = "AMBER-SPARK";
    private static final long MIN = TradingMistakes.SIM_MINUTE;
    private static final long DAY = 60_000;

    private final List<Event> events = new ArrayList<>();
    private long nextId = 1;

    private long buy(long ts, String instrument, long qty, long price) {
        long mine = nextId++;
        long theirs = nextId++;
        events.add(new Event.OrderAccepted(ts, theirs, MM, instrument, Order.Side.SELL, Order.Type.LIMIT, price, qty, null));
        events.add(new Event.OrderAccepted(ts, mine, ME, instrument, Order.Side.BUY, Order.Type.LIMIT, price, qty, null));
        events.add(new Event.TradeExecuted(ts, nextId++, instrument, mine, theirs, ME, MM, price, qty, Order.Side.BUY, 0, 0, 0));
        return mine;
    }

    private void sell(long ts, String instrument, long qty, long price) {
        long mine = nextId++;
        long theirs = nextId++;
        events.add(new Event.OrderAccepted(ts, theirs, MM, instrument, Order.Side.BUY, Order.Type.LIMIT, price, qty, null));
        events.add(new Event.OrderAccepted(ts, mine, ME, instrument, Order.Side.SELL, Order.Type.LIMIT, price, qty, null));
        events.add(new Event.TradeExecuted(ts, nextId++, instrument, theirs, mine, MM, ME, price, qty, Order.Side.SELL, 0, 0, 0));
    }

    private long stop(long ts, String instrument, long qty, long trigger) {
        long id = nextId++;
        events.add(new Event.ConditionalPlaced(ts, id, ME, instrument, Conditional.Kind.STOP_MARKET, Order.Side.SELL, qty,
                trigger, 0, 0, 0, 0, null));
        return id;
    }

    private List<Mistake> find() {
        return TradingMistakes.find(events, Instrument.ALL, ME, 0, 1_000 * DAY, DAY);
    }

    private static List<Mistake> only(List<Mistake> all, Code code) {
        return all.stream().filter(m -> m.code() == code).toList();
    }

    @Test
    void aCleanSessionHasNoFindings() {
        buy(1_000, SILK, 10, 10_000);
        stop(1_000, SILK, 10, 9_500);
        sell(1_000 + MIN, SILK, 10, 11_000); // a win; the stop is left waiting, harmless
        buy(1_000 + 20 * MIN, AMBER, 5, 50_000);
        stop(1_000 + 20 * MIN, AMBER, 5, 48_000);

        assertEquals(List.of(), find());
    }

    @Test
    void b6AddingToALosingPosition() {
        buy(1_000, SILK, 10, 10_000);
        long added = buy(1_000 + MIN, SILK, 10, 9_000);
        stop(1_000 + MIN, SILK, 20, 8_500);

        List<Mistake> all = find();
        assertEquals(1, all.size(), all.toString());
        assertEquals(B6_AVERAGING_DOWN, all.get(0).code());
        assertEquals(1_000 + MIN, all.get(0).at());
        assertTrue(added > 0);
    }

    @Test
    void b7APositionWithoutAStopAtTheEndOfTheSession() {
        buy(1_000, SILK, 10, 10_000);
        long cancelled = stop(1_000, SILK, 10, 9_500);
        events.add(new Event.ConditionalCancelled(2_000, cancelled, ME));
        stop(2_000, SILK, 4, 9_500); // covers only part of it

        List<Mistake> all = find();
        assertEquals(List.of(new Mistake(B7_NO_EXIT_PLAN, SILK, 1_000 * DAY, "held=10 covered=4")), all);
    }

    @Test
    void b8SizeJumpsRightAfterALoss() {
        for (int k = 0; k < 3; k++) { // the usual size on Amber: 10
            buy(1_000 + k * 10 * MIN, AMBER, 10, 50_000);
            sell(1_000 + k * 10 * MIN + MIN, AMBER, 10, 50_000);
        }
        long t = 100 * MIN;
        buy(t, SILK, 10, 10_000);
        sell(t + MIN, SILK, 10, 9_000); // a loss of 10 000
        buy(t + 3 * MIN, AMBER, 25, 50_000);
        stop(t + 3 * MIN, AMBER, 25, 48_000);

        List<Mistake> all = find();
        assertEquals(1, all.size(), all.toString());
        Mistake m = all.get(0);
        assertEquals(B8_SIZE_AFTER_LOSS, m.code());
        assertEquals(AMBER, m.instrument());
        assertEquals("qty=25 median=10 lossAgoMs=" + 2 * MIN + " loss=-10000", m.detail());
    }

    @Test
    void b10ANewEntryInTheSameInstrumentRightAfterALoss() {
        buy(1_000, SILK, 10, 10_000);
        sell(1_000 + MIN, SILK, 10, 9_000);
        buy(1_000 + 3 * MIN, SILK, 5, 9_000); // revenge
        sell(1_000 + 4 * MIN, SILK, 5, 9_000);
        buy(1_000 + 30 * MIN, SILK, 5, 9_000); // long after: not revenge
        sell(1_000 + 31 * MIN, SILK, 5, 9_100);

        List<Mistake> all = find();
        assertEquals(1, all.size(), all.toString());
        assertEquals(B10_REVENGE, all.get(0).code());
        assertEquals(1_000 + 3 * MIN, all.get(0).at());
    }

    @Test
    void b2AnEntryWithinTwoDaysBeforeAScheduledReport() {
        long report = 30 * DAY;
        events.add(new Event.ConsensusPublished(report - 5 * DAY, SILK, 1, report, 1_000, 100, 10));
        buy(report - 3 * DAY, SILK, 1, 10_000); // three days before: fine
        sell(report - 3 * DAY + 1, SILK, 1, 10_000);
        buy(report - DAY, SILK, 1, 10_000);
        sell(report - DAY + 1, SILK, 1, 10_000);

        List<Mistake> all = find();
        assertEquals(1, only(all, B2_BEFORE_REPORT).size(), all.toString());
        assertEquals(report - DAY, all.get(0).at());
        assertEquals(1, all.size(), all.toString());
    }

    @Test
    void onlyTheSessionWindowIsReportedButEarlierEventsGiveTheContext() {
        buy(1_000, SILK, 10, 10_000);
        buy(1_000 + MIN, SILK, 10, 9_000); // averaging down, but before the session
        sell(1_000 + 2 * MIN, SILK, 20, 9_000);

        assertEquals(List.of(), TradingMistakes.find(events, Instrument.ALL, ME, 1_000 + 2 * MIN, 1_000 * DAY, DAY));
    }
}
