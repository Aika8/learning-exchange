package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import engine.Order;
import engine.OrderBook;
import engine.ref.RefLevel;
import engine.ref.ReferenceBook;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * LE-009: like {@link DifferentialTest} (LE-008), but the engine's {@link OrderBook} and the {@link ReferenceBook}
 * must show the same depth view after every step: the top {@value #DEPTH} aggregated levels on both sides (price,
 * total remaining quantity, number of orders), and the same result for every cancel.
 *
 * <p>The engine side is a fresh {@link OrderBook} fed the same actions, so {@code bids(10)} / {@code asks(10)} are
 * read from the book itself, not cut from a full view. {@link Runner} only resolves which id a cancel targets. A
 * cancel with nothing resting cancels the last assigned id on both books instead (a filled or market order, so
 * both must answer false and change nothing) — see DECISIONS.md, LE-009. On the first difference the test fails
 * with the seed, the step and the REPL script of the prefix (LE-007).
 */
class DifferentialDepthTest {

    private static final int SEEDS = 500;
    private static final int LENGTH = 1_000;
    private static final int DEPTH = 10;

    @Test
    void engineShowsTheSameDepthAsTheReferenceBookAfterEveryStep() {
        long levels = 0;
        long cancels = 0;
        for (long seed = 1; seed <= SEEDS; seed++) {
            long[] counts = compare(seed, ActionGen.generate(seed, LENGTH));
            levels += counts[0];
            cancels += counts[1];
        }
        // Guard against a vacuous run: books that are mostly empty, or no cancels at all, would prove nothing.
        assertTrue(levels > SEEDS * (long) LENGTH, "too few levels compared: " + levels);
        assertTrue(cancels > SEEDS, "too few cancels compared: " + cancels);
    }

    @Test
    void depthIsCutAtTenLevelsOnBothBooks() {
        OrderBook engine = new OrderBook();
        ReferenceBook ref = new ReferenceBook();
        for (long price = 100; price < 112; price++) {
            engine.submit(Order.limit(Order.Side.BUY, price, 1));
            ref.submitLimit(Order.Side.BUY, price, 1);
        }
        assertEquals(DEPTH, engine.bids(DEPTH).size());
        assertEquals(asRef(engine.bids(DEPTH)), ref.bids(DEPTH));
        assertEquals(111, ref.bids(DEPTH).getFirst().price());
    }

    @Test
    void cancelOfAFilledOrderIsFalseOnBothBooks() {
        OrderBook engine = new OrderBook();
        ReferenceBook ref = new ReferenceBook();
        engine.submit(Order.limit(Order.Side.SELL, 100, 2));
        ref.submitLimit(Order.Side.SELL, 100, 2);
        long id = engine.submit(Order.market(Order.Side.BUY, 2)).orderId();
        assertEquals(id, ref.submitMarket(Order.Side.BUY, 2));
        assertFalse(engine.cancel(1));
        assertFalse(ref.cancel(1));
        assertFalse(engine.cancel(id));
        assertFalse(ref.cancel(id));
    }

    /** Runs both books over {@code actions}; returns {levels compared, cancels compared}. */
    private static long[] compare(long seed, List<Action> actions) {
        List<Runner.Step> steps = Runner.run(actions);
        OrderBook engine = new OrderBook();
        ReferenceBook ref = new ReferenceBook();
        long lastId = 0;
        long levels = 0;
        long cancels = 0;
        for (Runner.Step step : steps) {
            switch (step.action()) {
                case Action.SubmitLimit l -> {
                    long id = engine.submit(Order.limit(l.side(), l.price(), l.qty())).orderId();
                    check(seed, actions, steps, step, "order id", ref.submitLimit(l.side(), l.price(), l.qty()), id);
                    lastId = id;
                }
                case Action.SubmitMarket m -> {
                    long id = engine.submit(Order.market(m.side(), m.qty())).orderId();
                    check(seed, actions, steps, step, "order id", ref.submitMarket(m.side(), m.qty()), id);
                    lastId = id;
                }
                case Action.Cancel c -> {
                    long id = step.orderId().orElse(lastId);
                    if (id > 0) {
                        check(seed, actions, steps, step, "cancel result of " + id, ref.cancel(id), engine.cancel(id));
                        cancels++;
                    }
                }
            }
            List<RefLevel> bids = asRef(engine.bids(DEPTH));
            List<RefLevel> asks = asRef(engine.asks(DEPTH));
            check(seed, actions, steps, step, "bids(" + DEPTH + ")", ref.bids(DEPTH), bids);
            check(seed, actions, steps, step, "asks(" + DEPTH + ")", ref.asks(DEPTH), asks);
            levels += bids.size() + asks.size();
        }
        return new long[] {levels, cancels};
    }

    private static List<RefLevel> asRef(List<OrderBook.Level> levels) {
        return levels.stream().map(l -> new RefLevel(l.price(), l.qty(), l.orders())).toList();
    }

    private static void check(long seed, List<Action> actions, List<Runner.Step> steps, Runner.Step step,
            String what, Object reference, Object engine) {
        if (!reference.equals(engine)) {
            fail(DifferentialTest.failure(seed, actions, steps, step.index(), what, reference, engine));
        }
    }
}
