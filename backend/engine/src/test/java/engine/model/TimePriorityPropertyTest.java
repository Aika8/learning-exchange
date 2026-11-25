package engine.model;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import engine.Order;
import engine.Trade;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/**
 * LE-002, intent 01 invariant 1 (time priority): at one price the earlier resting order is filled first.
 *
 * <p>For every submit that trades, the trades are replayed in order against the live orders the Runner's model
 * held just before the step. A maker may be filled only if no order of the same side and price with an earlier
 * arrival still rests with quantity at that moment.
 */
class TimePriorityPropertyTest {

    private static final int SEEDS = 200;
    private static final int LENGTH = 500;

    @Test
    void earlierOrderAtTheSamePriceIsFilledFirst() {
        long contested = 0;
        for (long seed = 1; seed <= SEEDS; seed++) {
            contested += check(seed);
        }
        // Not vacuous: some fills had a later order waiting behind them at the same price.
        assertTrue(contested > 0, "no fill ever met a queue of two or more orders at one price");
    }

    /** Checks one seed; returns how many fills happened while a later order waited at the same price. */
    private static long check(long seed) {
        List<Runner.Step> steps = Runner.run(ActionGen.generate(seed, LENGTH));
        Map<Long, Runner.LiveOrder> before = Map.of();
        long contested = 0;
        for (Runner.Step step : steps) {
            if (!step.trades().isEmpty()) {
                contested += checkStep(seed, step, before);
            }
            before = step.live();
        }
        return contested;
    }

    private static long checkStep(long seed, Runner.Step step, Map<Long, Runner.LiveOrder> before) {
        Map<Long, Long> remaining = new HashMap<>();
        before.forEach((id, o) -> remaining.put(id, o.remainingQty()));
        long contested = 0;
        for (Trade t : step.trades()) {
            long makerId = t.aggressorSide() == Order.Side.BUY ? t.sellOrderId() : t.buyOrderId();
            Runner.LiveOrder maker = before.get(makerId);
            if (maker == null || remaining.get(makerId) <= 0) {
                fail(where(seed, step) + ": trade " + t + " filled order " + makerId + " that was not resting");
            }
            boolean laterWaits = false;
            for (Runner.LiveOrder other : before.values()) {
                if (other.id() == makerId || other.side() != maker.side() || other.price() != maker.price()
                        || remaining.get(other.id()) <= 0) {
                    continue;
                }
                if (other.arrival() < maker.arrival()) {
                    fail(where(seed, step) + ": order " + makerId + " (arrival " + maker.arrival() + ") filled at "
                            + maker.price() + " while earlier order " + other.id() + " (arrival " + other.arrival()
                            + ") still rests with " + remaining.get(other.id()));
                }
                laterWaits = true;
            }
            if (laterWaits) {
                contested++;
            }
            remaining.put(makerId, remaining.get(makerId) - t.qty());
        }
        return contested;
    }

    private static String where(long seed, Runner.Step step) {
        return "seed " + seed + ", step " + step.index() + " (" + step.action() + ")";
    }
}
