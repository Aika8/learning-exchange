package bots;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Event;
import engine.Order;
import java.util.List;
import java.util.Map;
import java.util.Random;
import org.junit.jupiter.api.Test;

/** M2b strategies and the world feed: each is a small pure decision, tested by example. */
class M2bBotsTest {

    private static MarketView view(List<Long> prices, Long fundamental, long step, long base) {
        return new MarketView("X", null, null, prices.isEmpty() ? null : prices.getLast(), 10_000, List.of(), base, 1_000_000,
                base, prices, fundamental, step);
    }

    @Test
    void momentumBuysARiseAndSellsAFall() {
        Momentum m = new Momentum(50, 2, 1.0);
        assertEquals(Order.Side.BUY, ((Intent.Place) m.decide(view(List.of(10_000L, 10_100L), null, 1, 0), new Random(1)).getFirst()).side());
        assertEquals(Order.Side.SELL, ((Intent.Place) m.decide(view(List.of(10_000L, 9_900L), null, 1, 5), new Random(1)).getFirst()).side());
        assertTrue(m.decide(view(List.of(10_000L, 10_001L), null, 1, 5), new Random(1)).isEmpty());
    }

    @Test
    void meanReversionBidsBelowTheAverage() {
        var intents = new MeanReversion(40, 2, 1.0).decide(view(List.of(10_000L, 10_000L, 10_000L, 10_000L, 9_900L), null, 1, 0), new Random(1));
        assertEquals(Order.Side.BUY, ((Intent.Place) intents.getLast()).side());
    }

    @Test
    void indexInvestorBuysOnScheduleAndNeverSells() {
        IndexInvestor i = new IndexInvestor(10, 1);
        assertEquals(1, i.decide(view(List.of(), null, 20, 100), new Random(1)).size());
        assertTrue(i.decide(view(List.of(), null, 21, 100), new Random(1)).isEmpty());
    }

    @Test
    void fundamentalistBuysBelowValueAndWaitsForAReport() {
        Fundamentalist f = new Fundamentalist(10, 1_000, 3, 1.0);
        assertTrue(f.decide(view(List.of(10_000L), null, 1, 0), new Random(1)).isEmpty());
        // EPS 1 500/yr × P/E 10 = 15 000 > 10 000 × 1.1 → buy
        assertEquals(Order.Side.BUY, ((Intent.Place) f.decide(view(List.of(10_000L), 1_500L, 1, 0), new Random(1)).getLast()).side());
    }

    @Test
    void theOpenGapsByTheSurpriseNotByTheProfitAndStormsRaiseVolatility() {
        FairValue stock = new FairValue(10_000, 0, 1, 1);
        FairValue fx = new FairValue(50_000, 0, 1, 2);
        WorldFeed w = new WorldFeed(Map.of("S", stock, "AMBER-SPARK", fx), "AMBER-SPARK", null);
        // record profit but 10% below consensus: the price falls 5%
        w.onEvents(List.of(new Event.EarningsReported(1, "S", 1, 1, 1, 90, 0, 0, 0, 100, 1, 100)));
        assertEquals(9_500, stock.value());
        assertEquals(400L, w.annualEps("S"));
        w.onEvents(List.of(new Event.RateDecided(2, 1, 1_650, 1_600, 1_600, 1_000)));
        assertEquals(49_500, fx.value(), "a hike above consensus strengthens SPARK");
        w.onEvents(List.of(new Event.PayoutStarted(3, "S", Event.PayoutKind.DIVIDEND, "i", 100, 1, 100)));
        assertEquals(9_400, stock.value(), "the price drops by the dividend at the ex-date");
    }
}
