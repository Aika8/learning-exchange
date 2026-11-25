package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import engine.Order;
import engine.OrderBook;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/**
 * LE-003, intent 01 invariant 4: only priced orders rest; an unfilled market-order remainder is cancelled.
 *
 * <p>The book exposes no resting ids, only levels. So "the market id never rests" is checked three ways:
 * the levels' total quantity drops by exactly the filled quantity (a resting remainder would raise it), the
 * levels' order count and quantity match the Runner's model (which never puts a market id in), and a replay
 * that cancels each market id right after its submit gets {@code false} and ends in the same book.
 */
class MarketRemainderPropertyTest {

    private static final int SEEDS = 200;
    private static final int LENGTH = 500;

    @Test
    void marketRemainderNeverRests() {
        int markets = 0;
        int partial = 0;
        for (long seed = 1; seed <= SEEDS; seed++) {
            List<Action> actions = ActionGen.generate(seed, LENGTH);
            List<Runner.Step> steps = Runner.run(actions);
            long before = 0;
            for (Runner.Step step : steps) {
                long after = restingQty(step);
                if (step.action() instanceof Action.SubmitMarket m) {
                    markets++;
                    String where = where(seed, step);
                    long id = step.orderId().orElseThrow();
                    long filled = step.submitResult().orElseThrow().filledQty();
                    if (filled < m.qty()) {
                        partial++;
                    }
                    assertEquals(before - filled, after, where + ": resting qty must drop by the filled qty");
                    assertFalse(step.live().containsKey(id), where + ": market id " + id + " in the model");
                    assertModelMatchesLevels(step, where);
                }
                before = after;
            }
            assertCancelOfMarketIdsFails(seed, actions, steps);
        }
        assertTrue(markets > SEEDS * LENGTH / 10, "too few market orders: " + markets);
        assertTrue(partial > 0, "no market order ever had a remainder; the property was not exercised");
    }

    /** The levels hold exactly the model's live orders: same count and same quantity per side. */
    private static void assertModelMatchesLevels(Runner.Step step, String where) {
        for (Order.Side side : Order.Side.values()) {
            List<OrderBook.Level> levels = side == Order.Side.BUY ? step.bids() : step.asks();
            long levelQty = levels.stream().mapToLong(OrderBook.Level::qty).sum();
            long levelOrders = levels.stream().mapToLong(OrderBook.Level::orders).sum();
            long modelQty = step.live().values().stream()
                    .filter(o -> o.side() == side).mapToLong(Runner.LiveOrder::remainingQty).sum();
            long modelOrders = step.live().values().stream().filter(o -> o.side() == side).count();
            assertEquals(modelQty, levelQty, where + ": " + side + " resting qty vs model");
            assertEquals(modelOrders, levelOrders, where + ": " + side + " resting order count vs model");
        }
    }

    /**
     * Replays the run on a fresh book, cancelling each market id right after its submit and once more at the
     * end. Every such cancel must return false and leave the book as the Runner saw it.
     */
    private static void assertCancelOfMarketIdsFails(long seed, List<Action> actions, List<Runner.Step> steps) {
        OrderBook book = new OrderBook();
        List<Long> marketIds = new ArrayList<>();
        for (int i = 0; i < actions.size(); i++) {
            Runner.Step step = steps.get(i);
            String where = where(seed, step);
            switch (actions.get(i)) {
                case Action.SubmitLimit l -> {
                    long id = book.submit(Order.limit(l.side(), l.price(), l.qty())).orderId();
                    assertEquals(step.orderId().orElseThrow(), id, where + ": replay diverged");
                }
                case Action.SubmitMarket m -> {
                    long id = book.submit(Order.market(m.side(), m.qty())).orderId();
                    assertEquals(step.orderId().orElseThrow(), id, where + ": replay diverged");
                    assertFalse(book.cancel(id), where + ": cancel of market id " + id + " returned true");
                    marketIds.add(id);
                }
                case Action.Cancel c -> {
                    if (step.orderId().isPresent()) {
                        assertEquals(step.cancelled(), book.cancel(step.orderId().getAsLong()), where + ": replay");
                    }
                }
            }
            if (!book.bids(Integer.MAX_VALUE).equals(step.bids()) || !book.asks(Integer.MAX_VALUE).equals(step.asks())) {
                fail(where + ": book after cancelling market ids differs from the run without those cancels");
            }
        }
        for (long id : marketIds) {
            assertFalse(book.cancel(id), "seed " + seed + " end of run: cancel of market id " + id + " returned true");
        }
    }

    private static long restingQty(Runner.Step step) {
        return step.bids().stream().mapToLong(OrderBook.Level::qty).sum()
                + step.asks().stream().mapToLong(OrderBook.Level::qty).sum();
    }

    private static String where(long seed, Runner.Step step) {
        return "seed " + seed + " step " + step.index() + " (" + step.action() + ")";
    }
}
