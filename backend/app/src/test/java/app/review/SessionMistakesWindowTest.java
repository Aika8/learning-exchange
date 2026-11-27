package app.review;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import application.InMemoryJournal;
import application.TradingService;
import application.review.TradingMistakes;
import application.review.TradingMistakes.Mistake;
import engine.Event;
import engine.Instrument;
import engine.Order;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * AUTO-20261126-11: the session review ({@code GET /session-review}) uses the same one-bank-day "after a loss"
 * window as {@link TradingMistakes#afterLossWindow(long)} (LE-405), with the bank day of the running economy.
 */
class SessionMistakesWindowTest {

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

    /** A loss, then a new entry in the same instrument {@code tenths}/10 bank days later; the B10 the review finds. */
    private List<Mistake> revengeAfter(long dayMillis, long tenths) {
        long lossAt = 10 * dayMillis;
        trade(lossAt - 1, Order.Side.BUY, 10, 10_000);
        trade(lossAt, Order.Side.SELL, 10, 9_000);
        long entry = lossAt + tenths * dayMillis / 10;
        trade(entry, Order.Side.BUY, 5, 9_000);
        trade(entry + 1, Order.Side.SELL, 5, 9_000);

        InMemoryJournal journal = new InMemoryJournal();
        journal.append(events);
        TradingService market = mock(TradingService.class);
        when(market.instruments()).thenReturn(Instrument.ALL);
        when(market.savingsProduct()).thenReturn(new TradingService.SavingsProduct("SILK", 0, dayMillis));

        return new SessionMistakes(journal, market).find(ME, 0, 100 * dayMillis).stream()
                .filter(m -> m.code() == TradingMistakes.Code.B10_REVENGE)
                .toList();
    }

    @Test
    void anEntryZeroPointNineBankDayAfterALossIsRevengeWithMinuteDays() {
        List<Mistake> found = revengeAfter(60_000, 9);
        assertEquals(1, found.size(), found.toString());
        assertEquals(10 * 60_000 + 54_000, found.get(0).at());
    }

    @Test
    void anEntryTwoBankDaysAfterALossIsNotRevengeWithMinuteDays() {
        // two minute-long bank days are well inside the old five-sim-minute window
        assertEquals(List.of(), revengeAfter(60_000, 20));
    }

    @Test
    void anEntryZeroPointNineBankDayAfterALossIsRevengeWithTenMinuteDays() {
        // 0.9 of a ten-minute bank day is nine minutes: outside the old five-sim-minute window
        List<Mistake> found = revengeAfter(600_000, 9);
        assertEquals(1, found.size(), found.toString());
    }
}
