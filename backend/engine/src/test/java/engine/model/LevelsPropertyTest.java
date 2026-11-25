package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Order;
import engine.OrderBook;
import java.util.List;
import java.util.Map;
import java.util.TreeMap;
import org.junit.jupiter.api.Test;

/**
 * LE-005, intent 01 invariant 6: the book never shows an empty price level, and the best price is backed by
 * quantity. Re-checks invariant 3 (no crossed book) under the {@link ActionGen} flow.
 *
 * <p>After every step of every seed: each level in the full depth view has {@code qty > 0} and
 * {@code orders > 0}; best bid &lt; best ask when both sides are present; and the depth view's quantity equals
 * the Runner model's remaining quantity of resting orders — per side in total and per price.
 */
class LevelsPropertyTest {

    private static final int SEEDS = 200;
    private static final int LENGTH = 500;

    @Test
    void levelsAreNeverEmptyAndBestPriceIsBacked() {
        int bothSides = 0;
        int emptiedLevels = 0;
        for (long seed = 1; seed <= SEEDS; seed++) {
            List<Runner.Step> steps = Runner.run(ActionGen.generate(seed, LENGTH));
            int levelsBefore = 0;
            for (Runner.Step step : steps) {
                String where = "seed " + seed + " step " + step.index() + " (" + step.action() + ")";
                for (Order.Side side : Order.Side.values()) {
                    List<OrderBook.Level> levels = side == Order.Side.BUY ? step.bids() : step.asks();
                    for (OrderBook.Level level : levels) {
                        assertTrue(level.qty() > 0, where + ": " + side + " level with no quantity " + level);
                        assertTrue(level.orders() > 0, where + ": " + side + " level with no orders " + level);
                    }
                    assertEquals(modelQtyByPrice(step, side), depthQtyByPrice(levels),
                            where + ": " + side + " depth quantity per price differs from the model");
                    assertEquals(modelQty(step, side), levels.stream().mapToLong(OrderBook.Level::qty).sum(),
                            where + ": " + side + " depth total differs from the model's remaining quantity");
                }
                if (!step.bids().isEmpty() && !step.asks().isEmpty()) {
                    bothSides++;
                    long bestBid = step.bids().getFirst().price();
                    long bestAsk = step.asks().getFirst().price();
                    assertTrue(bestBid < bestAsk, where + ": crossed book, bid " + bestBid + " >= ask " + bestAsk);
                }
                int levelsAfter = step.bids().size() + step.asks().size();
                if (levelsAfter < levelsBefore) {
                    emptiedLevels++;
                }
                levelsBefore = levelsAfter;
            }
        }
        assertTrue(bothSides > SEEDS * LENGTH / 10, "book rarely had both sides: " + bothSides);
        assertTrue(emptiedLevels > SEEDS, "levels were rarely emptied; the property was not exercised");
    }

    private static Map<Long, Long> depthQtyByPrice(List<OrderBook.Level> levels) {
        Map<Long, Long> byPrice = new TreeMap<>();
        for (OrderBook.Level level : levels) {
            byPrice.merge(level.price(), level.qty(), Long::sum);
        }
        return byPrice;
    }

    private static Map<Long, Long> modelQtyByPrice(Runner.Step step, Order.Side side) {
        Map<Long, Long> byPrice = new TreeMap<>();
        for (Runner.LiveOrder o : step.live().values()) {
            if (o.side() == side) {
                byPrice.merge(o.price(), o.remainingQty(), Long::sum);
            }
        }
        return byPrice;
    }

    private static long modelQty(Runner.Step step, Order.Side side) {
        return step.live().values().stream()
                .filter(o -> o.side() == side)
                .mapToLong(Runner.LiveOrder::remainingQty)
                .sum();
    }
}
