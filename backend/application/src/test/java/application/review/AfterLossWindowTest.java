package application.review;

import static application.review.TradingMistakes.Code.B10_REVENGE;
import static org.junit.jupiter.api.Assertions.assertEquals;

import application.review.TradingMistakes.Mistake;
import engine.Event;
import engine.Instrument;
import engine.Order;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/** LE-405: "after a loss" (B8/B10) is one bank day of the economy, whatever length a bank day has. */
class AfterLossWindowTest {

    private static final String ME = "me";
    private static final String MM = "mm";
    private static final String SILK = "SILK-SPARK";

    private final List<Event> events = new ArrayList<>();
    private long nextId = 1;

    private void trade(long ts, Order.Side mySide, long qty, long price) {
        long mine = nextId++;
        long theirs = nextId++;
        Order.Side other = mySide == Order.Side.BUY ? Order.Side.SELL : Order.Side.BUY;
        events.add(new Event.OrderAccepted(ts, theirs, MM, SILK, other, Order.Type.LIMIT, price, qty, null));
        events.add(new Event.OrderAccepted(ts, mine, ME, SILK, mySide, Order.Type.LIMIT, price, qty, null));
        if (mySide == Order.Side.BUY) {
            events.add(new Event.TradeExecuted(ts, nextId++, SILK, mine, theirs, ME, MM, price, qty, mySide, 0, 0, 0));
        } else {
            events.add(new Event.TradeExecuted(ts, nextId++, SILK, theirs, mine, MM, ME, price, qty, mySide, 0, 0, 0));
        }
    }

    /** A loss closed at {@code lossAt}, then a new entry in the same instrument {@code tenths}/10 bank days later. */
    private List<Mistake> revengeAfter(long dayMillis, long tenths) {
        long lossAt = 10 * dayMillis;
        trade(lossAt - 1, Order.Side.BUY, 10, 10_000);
        trade(lossAt, Order.Side.SELL, 10, 9_000);
        long entry = lossAt + tenths * dayMillis / 10;
        trade(entry, Order.Side.BUY, 5, 9_000);
        trade(entry + 1, Order.Side.SELL, 5, 9_000);
        List<Mistake> all = TradingMistakes.find(events, Instrument.ALL, ME, 0, 100 * dayMillis, dayMillis, List.of(),
                TradingMistakes.afterLossWindow(dayMillis));
        return all.stream().filter(m -> m.code() == B10_REVENGE).toList();
    }

    @ParameterizedTest
    @ValueSource(longs = {60_000, 86_400_000})
    void anEntryWithinOneBankDayOfALossIsRevenge(long dayMillis) {
        List<Mistake> found = revengeAfter(dayMillis, 9);
        assertEquals(1, found.size(), found.toString());
        assertEquals(10 * dayMillis + 9 * dayMillis / 10, found.get(0).at());
    }

    @ParameterizedTest
    @ValueSource(longs = {60_000, 86_400_000})
    void anEntryMoreThanOneBankDayAfterALossIsNot(long dayMillis) {
        assertEquals(List.of(), revengeAfter(dayMillis, 11));
    }

    @ParameterizedTest
    @ValueSource(longs = {60_000, 86_400_000})
    void theWindowIsOneBankDay(long dayMillis) {
        assertEquals(dayMillis, TradingMistakes.afterLossWindow(dayMillis));
    }
}
