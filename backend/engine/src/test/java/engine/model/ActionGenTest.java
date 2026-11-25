package engine.model;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

/** LE-001: the generator is deterministic per seed, only produces valid actions, and the Runner survives long runs. */
class ActionGenTest {

    @Test
    void sameSeedGivesTheSameList() {
        for (long seed = 1; seed <= 20; seed++) {
            assertEquals(ActionGen.generate(seed, 2_000), ActionGen.generate(seed, 2_000), "seed " + seed);
        }
        assertNotEquals(ActionGen.generate(1, 200), ActionGen.generate(2, 200));
    }

    @Test
    void everyGeneratedActionIsValid() {
        for (long seed = 1; seed <= 20; seed++) {
            for (Action a : ActionGen.generate(seed, 10_000)) {
                switch (a) {
                    case Action.SubmitLimit l -> {
                        assertTrue(l.side() != null, a::toString);
                        assertTrue(l.price() > 0, a::toString);
                        assertTrue(l.qty() > 0, a::toString);
                        assertTrue(l.price() >= ActionGen.MIN_PRICE && l.price() <= ActionGen.MAX_PRICE, a::toString);
                        assertTrue(l.qty() <= ActionGen.MAX_QTY, a::toString);
                    }
                    case Action.SubmitMarket m -> {
                        assertTrue(m.side() != null, a::toString);
                        assertTrue(m.qty() > 0 && m.qty() <= ActionGen.MAX_QTY, a::toString);
                    }
                    case Action.Cancel c -> assertTrue(c.pickIndex() >= 0, a::toString);
                }
            }
        }
    }

    @Test
    void mixIsRoughlyFortyFiveTwentyThirtyFive() {
        List<Action> actions = ActionGen.generate(7, 20_000);
        long limits = actions.stream().filter(a -> a instanceof Action.SubmitLimit).count();
        long markets = actions.stream().filter(a -> a instanceof Action.SubmitMarket).count();
        long cancels = actions.stream().filter(a -> a instanceof Action.Cancel).count();
        assertTrue(Math.abs(limits / 20_000.0 - 0.45) < 0.02, "limits " + limits);
        assertTrue(Math.abs(markets / 20_000.0 - 0.20) < 0.02, "markets " + markets);
        assertTrue(Math.abs(cancels / 20_000.0 - 0.35) < 0.02, "cancels " + cancels);
    }

    @Test
    void runnerSurvivesTenThousandActionsForSeedsOneToTwenty() {
        for (long seed = 1; seed <= 20; seed++) {
            List<Action> actions = ActionGen.generate(seed, 10_000);
            List<Runner.Step> steps = assertDoesNotThrow(() -> Runner.run(actions), "seed " + seed);
            assertEquals(actions.size(), steps.size(), "seed " + seed);
            assertTrue(steps.stream().anyMatch(s -> !s.trades().isEmpty()), "seed " + seed + " never traded");
            assertTrue(steps.stream().anyMatch(Runner.Step::cancelled), "seed " + seed + " never cancelled");
        }
    }

    @Test
    void stepRecordsWhatTheBookDid() {
        List<Action> actions = List.of(
                new Action.Cancel(3),
                new Action.SubmitLimit(engine.Order.Side.SELL, 100, 5),
                new Action.SubmitLimit(engine.Order.Side.SELL, 101, 4),
                new Action.SubmitMarket(engine.Order.Side.BUY, 7),
                new Action.Cancel(1));
        List<Runner.Step> steps = Runner.run(actions);

        assertTrue(steps.get(0).orderId().isEmpty());
        assertTrue(!steps.get(0).cancelled());

        Runner.Step market = steps.get(3);
        assertEquals(3L, market.orderId().getAsLong());
        assertEquals(7, market.submitResult().orElseThrow().filledQty());
        assertEquals(List.of(1L, 2L), market.trades().stream().map(t -> t.sellOrderId()).toList());
        Runner.LiveOrder left = market.live().get(2L);
        assertEquals(new Runner.LiveOrder(2, engine.Order.Side.SELL, 101, 4, 2, 2), left);
        assertEquals(1, market.live().size());
        assertEquals(List.of(new engine.OrderBook.Level(101, 2, 1)), market.asks());

        Runner.Step cancel = steps.get(4);
        assertEquals(2L, cancel.orderId().getAsLong());
        assertTrue(cancel.cancelled());
        assertTrue(cancel.live().isEmpty());
        assertTrue(cancel.asks().isEmpty() && cancel.bids().isEmpty());
    }
}
