package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import engine.Trade;
import engine.ref.RefTrade;
import engine.ref.ReferenceBook;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * LE-008: the engine's {@link engine.OrderBook} trades exactly like the naive {@link ReferenceBook} (LE-051).
 *
 * <p>The same generated actions go to both books. The engine side runs through {@link Runner}; a cancel sends the
 * id the Runner resolved to the reference book too (ids are assigned the same way in both, from 1). After every
 * step the assigned id and the trade list must be equal: buyer id, seller id, price, quantity, aggressor side, in
 * order. On the first difference the test fails with the seed, the step and the REPL script of the prefix
 * (LE-007), so the run can be replayed by hand with {@code make repl}.
 */
class DifferentialTest {

    private static final int SEEDS = 500;
    private static final int LENGTH = 1_000;

    @Test
    void engineTradesExactlyLikeTheReferenceBook() {
        long trades = 0;
        for (long seed = 1; seed <= SEEDS; seed++) {
            trades += compare(seed, ActionGen.generate(seed, LENGTH));
        }
        assertTrue(trades > SEEDS * (long) LENGTH / 10, "too few trades to compare: " + trades);
    }

    @Test
    void aDifferenceIsReportedWithSeedStepAndScript() {
        List<Action> actions = ActionGen.generate(1, 5);
        List<Runner.Step> steps = Runner.run(actions);
        String message = failure(1, actions, steps, 3, "id", "1", "2");
        assertTrue(message.startsWith("seed 1, step 3"), message);
        assertTrue(message.endsWith(ReplScript.render(actions.subList(0, 4), steps.subList(0, 4))), message);
    }

    /** Runs both books over {@code actions}; returns how many trades were compared. */
    private static long compare(long seed, List<Action> actions) {
        List<Runner.Step> steps = Runner.run(actions);
        ReferenceBook ref = new ReferenceBook();
        long compared = 0;
        for (Runner.Step step : steps) {
            List<RefTrade> expected;
            switch (step.action()) {
                case Action.SubmitLimit l -> {
                    long id = ref.submitLimit(l.side(), l.price(), l.qty());
                    check(seed, actions, steps, step, "order id", id, step.orderId().orElseThrow());
                    expected = ref.lastTrades();
                }
                case Action.SubmitMarket m -> {
                    long id = ref.submitMarket(m.side(), m.qty());
                    check(seed, actions, steps, step, "order id", id, step.orderId().orElseThrow());
                    expected = ref.lastTrades();
                }
                case Action.Cancel c -> {
                    if (step.orderId().isPresent()) {
                        boolean cancelled = ref.cancel(step.orderId().getAsLong());
                        check(seed, actions, steps, step, "cancel result", cancelled, step.cancelled());
                    }
                    expected = List.of();
                }
            }
            List<RefTrade> actual = step.trades().stream().map(DifferentialTest::asRef).toList();
            check(seed, actions, steps, step, "trades", expected, actual);
            compared += actual.size();
        }
        return compared;
    }

    private static RefTrade asRef(Trade t) {
        return new RefTrade(t.buyOrderId(), t.sellOrderId(), t.price(), t.qty(), t.aggressorSide());
    }

    private static void check(long seed, List<Action> actions, List<Runner.Step> steps, Runner.Step step,
            String what, Object reference, Object engine) {
        if (!reference.equals(engine)) {
            fail(failure(seed, actions, steps, step.index(), what, reference, engine));
        }
    }

    /** The failure text: seed, step, both values, and the REPL script of actions 0..step. */
    static String failure(long seed, List<Action> actions, List<Runner.Step> steps, int index, String what,
            Object reference, Object engine) {
        int end = index + 1;
        return "seed " + seed + ", step " + index + " (" + actions.get(index) + "): " + what + " differ\n"
                + "  reference: " + reference + "\n"
                + "  engine:    " + engine + "\n"
                + "REPL script of the prefix (make repl):\n"
                + ReplScript.render(actions.subList(0, end), steps.subList(0, end));
    }

    @Test
    void sameIdsFromOneInBothBooks() {
        List<Action> actions = List.of(new Action.SubmitLimit(engine.Order.Side.BUY, 100, 5));
        assertEquals(1L, Runner.run(actions).getFirst().orderId().orElseThrow());
        assertEquals(1L, new ReferenceBook().submitLimit(engine.Order.Side.BUY, 100, 5));
    }
}
