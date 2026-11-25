package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import engine.Order;
import engine.OrderBook;
import engine.Trade;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import org.junit.jupiter.api.Test;

/**
 * LE-004, intent 01 invariant 5: a cancelled order never executes again.
 *
 * <p>The {@link Runner} records which ids {@code cancel} returned true for. After every later step no trade may
 * name such an id on either side. The Runner only cancels live ids, so the "cancel again" and "cancel a fully
 * filled id" checks run on a replay book: the same actions on a fresh {@link OrderBook}, where after every step
 * each cancelled id and each fully filled limit id is cancelled once more. Each of those must return false and
 * leave the book as the Runner saw it.
 */
class CancelPropertyTest {

    private static final int SEEDS = 200;
    private static final int LENGTH = 500;

    @Test
    void cancelledOrderNeverExecutesAgain() {
        long cancels = 0;
        long filledChecks = 0;
        for (long seed = 1; seed <= SEEDS; seed++) {
            List<Action> actions = ActionGen.generate(seed, LENGTH);
            List<Runner.Step> steps = Runner.run(actions);
            OrderBook replay = new OrderBook();
            Set<Long> cancelled = new LinkedHashSet<>();
            Set<Long> filled = new LinkedHashSet<>();
            Set<Long> liveBefore = Set.of();
            for (int i = 0; i < actions.size(); i++) {
                Runner.Step step = steps.get(i);
                String where = where(seed, step);
                replayStep(replay, actions.get(i), step, where);

                for (Trade t : step.trades()) {
                    assertFalse(cancelled.contains(t.buyOrderId()),
                            where + ": trade " + t + " names cancelled buy id " + t.buyOrderId());
                    assertFalse(cancelled.contains(t.sellOrderId()),
                            where + ": trade " + t + " names cancelled sell id " + t.sellOrderId());
                }

                if (step.cancelled()) {
                    cancels++;
                    cancelled.add(step.orderId().orElseThrow());
                }
                filled.addAll(newlyFilled(step, liveBefore));
                liveBefore = step.live().keySet();

                for (long id : cancelled) {
                    assertFalse(replay.cancel(id), where + ": second cancel of cancelled id " + id + " returned true");
                }
                for (long id : filled) {
                    filledChecks++;
                    assertFalse(replay.cancel(id), where + ": cancel of fully filled id " + id + " returned true");
                }
                if (!replay.bids(Integer.MAX_VALUE).equals(step.bids())
                        || !replay.asks(Integer.MAX_VALUE).equals(step.asks())) {
                    fail(where + ": book after the repeated cancels differs from the run without them");
                }
            }
        }
        assertTrue(cancels > SEEDS * LENGTH / 10, "too few successful cancels: " + cancels);
        assertTrue(filledChecks > 0, "no limit order was ever fully filled; the property was not exercised");
    }

    /** Applies one action to the replay book and checks it still follows the Runner's run. */
    private static void replayStep(OrderBook book, Action action, Runner.Step step, String where) {
        switch (action) {
            case Action.SubmitLimit l -> assertEquals(step.orderId().orElseThrow(),
                    book.submit(Order.limit(l.side(), l.price(), l.qty())).orderId(), where + ": replay diverged");
            case Action.SubmitMarket m -> assertEquals(step.orderId().orElseThrow(),
                    book.submit(Order.market(m.side(), m.qty())).orderId(), where + ": replay diverged");
            case Action.Cancel c -> {
                if (step.orderId().isPresent()) {
                    assertEquals(step.cancelled(), book.cancel(step.orderId().getAsLong()), where + ": replay");
                }
            }
        }
    }

    /**
     * Limit ids fully filled by this step: a limit submit with nothing left to rest, or a live order that left
     * the model without being cancelled (its maker side was filled to zero).
     */
    private static Set<Long> newlyFilled(Runner.Step step, Set<Long> liveBefore) {
        Set<Long> ids = new LinkedHashSet<>();
        if (step.action() instanceof Action.SubmitLimit l
                && step.submitResult().orElseThrow().filledQty() == l.qty()) {
            ids.add(step.orderId().orElseThrow());
        }
        for (long id : liveBefore) {
            if (!step.live().containsKey(id) && !(step.cancelled() && step.orderId().getAsLong() == id)) {
                ids.add(id);
            }
        }
        return ids;
    }

    private static String where(long seed, Runner.Step step) {
        return "seed " + seed + " step " + step.index() + " (" + step.action() + ")";
    }
}
