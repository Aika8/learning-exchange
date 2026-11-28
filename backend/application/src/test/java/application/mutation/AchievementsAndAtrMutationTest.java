package application.mutation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.AchievementsProjection;
import application.AchievementsProjection.Achievement;
import application.AchievementsProjection.Id;
import application.Atr;
import application.CandleProjection.Candle;
import engine.Conditional;
import engine.Event;
import engine.Order;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Achievements fed with events directly, and the smallest ATR period (LE-020). */
class AchievementsAndAtrMutationTest {

    private static final String ME = "acc-me";
    private final AchievementsProjection p = new AchievementsProjection();

    private Achievement get(Id id) {
        return p.achievements(ME).stream().filter(a -> a.id() == id).findFirst().orElseThrow();
    }

    private static Event.TradeExecuted trade(long ts, String instrument) {
        return new Event.TradeExecuted(ts, ts, instrument, 1, 2, ME, "acc-mm", 100, 1, Order.Side.BUY, 0, 0, 0);
    }

    @Test
    void aLockedAchievementShowsNoProgress() {
        Achievement a = get(Id.FIRST_TRADE);
        assertFalse(a.unlocked());
        assertEquals(0, a.progress());
    }

    @Test
    void placingAndFiringAStopUnlockTheirAchievements() {
        p.onEvents(List.of(
                new Event.ConditionalPlaced(5, 1, ME, "SILK-SPARK", Conditional.Kind.STOP_MARKET, Order.Side.SELL, 1, 90, 0, 0, 0,
                        0, "k"),
                new Event.ConditionalTriggered(6, 1, ME, 90, 3, null)));
        assertEquals(5L, get(Id.FIRST_STOP).at());
        assertEquals(6L, get(Id.STOP_FIRED).at());
    }

    @Test
    void fiveNotesUnlockTheJournalAchievementAtTheFifth() {
        for (int i = 1; i <= 4; i++) {
            p.onEvents(List.of(new Event.OrderAnnotated(i, i, ME, "why", "calm", "ok", 0)));
        }
        assertFalse(get(Id.JOURNAL_5).unlocked());
        assertEquals(4, get(Id.JOURNAL_5).progress());
        p.onEvents(List.of(new Event.OrderAnnotated(5, 5, ME, "why", "calm", "ok", 0)));
        assertEquals(5L, get(Id.JOURNAL_5).at());
    }

    @Test
    void notesOnASubAccountCountForNobody() {
        p.onEvents(List.of(new Event.OrderAnnotated(1, 1, ME + "~m1", "why", "calm", "ok", 0)));
        assertEquals(0, get(Id.JOURNAL_5).progress());
    }

    @Test
    void threeInstrumentsUnlockDiversifiedAtTheThird() {
        p.onEvents(List.of(trade(1, "SILK-SPARK"), trade(2, "AMBER-SPARK"), trade(3, "FORGE-SPARK")));
        assertEquals(3L, get(Id.DIVERSIFIED_3).at());
    }

    @Test
    void aSavingsDepositAndADividendUnlockTheirAchievements() {
        p.onEvents(List.of(new Event.SavingsOpened(7, 1, ME, "SPARK", 100, 500, 60_000, "k"),
                new Event.DividendPaid(8, "SILK-SPARK", ME, 1, 10, 1)));
        assertEquals(7L, get(Id.FIRST_SAVINGS).at());
        assertEquals(8L, get(Id.FIRST_DIVIDEND).at());
    }

    @Test
    void aSavingsDepositOfASubAccountUnlocksNothing() {
        p.onEvents(List.of(new Event.SavingsOpened(7, 1, ME + "~s1", "SPARK", 100, 500, 60_000, "k")));
        assertFalse(get(Id.FIRST_SAVINGS).unlocked());
    }

    @Test
    void theSmallestAtrPeriodIsTwo() {
        List<Candle> c = List.of(new Candle(0, 100, 100, 100, 100, 1), new Candle(1, 100, 110, 100, 105, 1),
                new Candle(2, 105, 105, 95, 100, 1));
        Atr.Result r = Atr.wilder(c, 2);
        assertTrue(r.ready());
        assertEquals(10L, r.atr(), "true ranges 10 and 10");
    }
}
