package application.review;

import static application.review.TradingMistakes.Code.B1_CHASING_A_MOVE;
import static application.review.TradingMistakes.Code.B4_WIDE_SPREAD;
import static org.junit.jupiter.api.Assertions.assertEquals;

import application.review.TradingMistakes.Code;
import application.review.TradingMistakes.Mistake;
import application.review.TradingMistakes.Quote;
import engine.Event;
import engine.Instrument;
import engine.Order;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** B1 (chasing a move) and B4 (entry into a wide spread), from hand-written journal events and book snapshots. */
class TradingMistakesSecondBatchTest {

    private static final String ME = "me";
    private static final String MM = "mm";
    private static final String OTHER = "other";
    private static final String SILK = "SILK-SPARK";
    private static final long MIN = TradingMistakes.SIM_MINUTE;
    private static final long DAY = 60_000;
    private static final long FROM = 100 * MIN;
    private static final long TO = 1_000 * MIN;

    private final List<Event> events = new ArrayList<>();
    private final List<Quote> quotes = new ArrayList<>();
    private long nextId = 1;

    /** A trade between two other accounts: it moves the price, it is nobody's mistake here. */
    private void print(long ts, long price) {
        long buy = nextId++;
        long sell = nextId++;
        events.add(new Event.OrderAccepted(ts, sell, MM, SILK, Order.Side.SELL, Order.Type.LIMIT, price, 1, null));
        events.add(new Event.OrderAccepted(ts, buy, OTHER, SILK, Order.Side.BUY, Order.Type.LIMIT, price, 1, null));
        events.add(new Event.TradeExecuted(ts, nextId++, SILK, buy, sell, OTHER, MM, price, 1, Order.Side.BUY, 0, 0, 0));
    }

    private void buy(long ts, long qty, long price) {
        long mine = nextId++;
        long theirs = nextId++;
        events.add(new Event.OrderAccepted(ts, theirs, MM, SILK, Order.Side.SELL, Order.Type.LIMIT, price, qty, null));
        events.add(new Event.OrderAccepted(ts, mine, ME, SILK, Order.Side.BUY, Order.Type.LIMIT, price, qty, null));
        events.add(new Event.TradeExecuted(ts, nextId++, SILK, mine, theirs, ME, MM, price, qty, Order.Side.BUY, 0, 0, 0));
    }

    private void quote(long ts, long bid, long ask) {
        quotes.add(new Quote(ts, SILK, bid, ask));
    }

    private List<Mistake> find(Code code) {
        return TradingMistakes.find(events, Instrument.ALL, ME, FROM, TO, DAY, quotes).stream()
                .filter(m -> m.code() == code)
                .toList();
    }

    @Test
    void b1BuyingAfterARiseOfFivePercentSinceTheSessionsFirstTrade() {
        print(FROM - MIN, 8_000); // before the session: does not set the start of the move
        print(FROM + MIN, 10_000);
        print(FROM + 2 * MIN, 10_500);
        buy(FROM + 3 * MIN, 5, 10_500);

        List<Mistake> found = find(B1_CHASING_A_MOVE);
        assertEquals(1, found.size());
        assertEquals(new Mistake(B1_CHASING_A_MOVE, SILK, FROM + 3 * MIN, "first=10000 last=10500 riseBps=500"),
                found.getFirst());
    }

    @Test
    void b1ASmallerRiseOrTheFirstTradeItselfIsNoChase() {
        buy(FROM + MIN, 5, 10_000); // the session's first trade is the person's own: nothing rose before it
        print(FROM + 2 * MIN, 10_499);
        buy(FROM + 3 * MIN, 5, 10_499); // +4.99%

        assertEquals(List.of(), find(B1_CHASING_A_MOVE));
    }

    @Test
    void b1TheMoveTheBuyerMakesThemselvesDoesNotCount() {
        print(FROM + MIN, 10_000);
        buy(FROM + 2 * MIN, 5, 11_000); // a sweep up: the price seen before the order was still 10 000

        assertEquals(List.of(), find(B1_CHASING_A_MOVE));
    }

    @Test
    void b4EntryWhileTheSpreadIsThreeTimesItsSessionMedian() {
        quote(FROM + MIN, 9_990, 10_010);      // spread 20
        quote(FROM + 2 * MIN, 9_990, 10_010);  // 20
        quote(FROM + 3 * MIN, 9_980, 10_020);  // 40
        quote(FROM + 4 * MIN, 9_970, 10_030);  // 60: three times the median of 20
        buy(FROM + 4 * MIN + 1, 5, 10_030);

        List<Mistake> found = find(B4_WIDE_SPREAD);
        assertEquals(List.of(new Mistake(B4_WIDE_SPREAD, SILK, FROM + 4 * MIN + 1,
                "spread=60 median=20 quotedAt=" + (FROM + 4 * MIN))), found);
    }

    @Test
    void b4UsualSpreadOrTooFewSnapshotsIsNoFinding() {
        quote(FROM + MIN, 9_990, 10_010);
        quote(FROM + 2 * MIN, 9_980, 10_020);
        buy(FROM + 2 * MIN + 1, 5, 10_020); // only two snapshots: no usual spread yet
        quote(FROM + 3 * MIN, 9_990, 10_010);
        quote(FROM + 4 * MIN, 9_975, 10_025); // 50 < 3 × 20
        buy(FROM + 4 * MIN + 1, 5, 10_025);

        assertEquals(List.of(), find(B4_WIDE_SPREAD));
    }

    @Test
    void b4WithoutSnapshotsTheOldSignatureFindsNothing() {
        quote(FROM + MIN, 9_990, 10_010);
        quote(FROM + 2 * MIN, 9_990, 10_010);
        quote(FROM + 3 * MIN, 9_900, 10_100);
        buy(FROM + 3 * MIN + 1, 5, 10_100);

        assertEquals(1, find(B4_WIDE_SPREAD).size());
        assertEquals(List.of(), TradingMistakes.find(events, Instrument.ALL, ME, FROM, TO, DAY).stream()
                .filter(m -> m.code() == B4_WIDE_SPREAD).toList());
    }
}
