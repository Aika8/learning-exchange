package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Order;
import engine.OrderBook;
import engine.Trade;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;
import org.junit.jupiter.api.Test;

/**
 * LE-006, intent 01 invariant 7: filled quantity never exceeds order quantity; remaining = quantity − filled.
 *
 * <p>Per order id the test keeps the original quantity (and the limit price, if any) from the action that
 * created it, and adds up the quantity of every {@link Trade} naming that id on either side. After every step:
 * filled ≤ original for every id; every trade has qty &gt; 0 and a price within both orders' limits (market
 * orders have none); and the book's depth equals, level by level, the sum of original − filled over the orders
 * the test believes rest there (a limit with something left at submit, not cancelled, not yet filled to zero).
 * The book has no per-order accessor, so the remaining quantity is checked through the depth aggregation.
 */
class FillAccountingPropertyTest {

    private static final int SEEDS = 200;
    private static final int LENGTH = 500;

    /** What the test knows about one order id: its side, its limit (null for market) and its quantity. */
    private record Known(Order.Side side, Long limit, long qty) {}

    @Test
    void filledNeverExceedsQuantityAndRemainingIsQuantityMinusFilled() {
        long trades = 0;
        long partialChecks = 0;
        for (long seed = 1; seed <= SEEDS; seed++) {
            List<Runner.Step> steps = Runner.run(ActionGen.generate(seed, LENGTH));
            Map<Long, Known> known = new HashMap<>();
            Map<Long, Long> filled = new HashMap<>();
            Set<Long> resting = new LinkedHashSet<>();
            for (Runner.Step step : steps) {
                String where = "seed " + seed + " step " + step.index() + " (" + step.action() + ")";
                switch (step.action()) {
                    case Action.SubmitLimit l ->
                            known.put(step.orderId().orElseThrow(), new Known(l.side(), l.price(), l.qty()));
                    case Action.SubmitMarket m ->
                            known.put(step.orderId().orElseThrow(), new Known(m.side(), null, m.qty()));
                    case Action.Cancel c -> {
                        if (step.cancelled()) {
                            resting.remove(step.orderId().getAsLong());
                        }
                    }
                }

                for (Trade t : step.trades()) {
                    trades++;
                    assertTrue(t.qty() > 0, where + ": trade with qty <= 0: " + t);
                    Known buy = known.get(t.buyOrderId());
                    Known sell = known.get(t.sellOrderId());
                    assertNotNull(buy, where + ": trade names unknown buy id: " + t);
                    assertNotNull(sell, where + ": trade names unknown sell id: " + t);
                    assertEquals(Order.Side.BUY, buy.side(), where + ": buy id is not a buy order: " + t);
                    assertEquals(Order.Side.SELL, sell.side(), where + ": sell id is not a sell order: " + t);
                    if (buy.limit() != null) {
                        assertTrue(t.price() <= buy.limit(), where + ": price above buy limit " + buy.limit() + ": " + t);
                    }
                    if (sell.limit() != null) {
                        assertTrue(t.price() >= sell.limit(), where + ": price below sell limit " + sell.limit() + ": " + t);
                    }
                    filled.merge(t.buyOrderId(), t.qty(), Long::sum);
                    filled.merge(t.sellOrderId(), t.qty(), Long::sum);
                }

                if (step.action() instanceof Action.SubmitLimit) {
                    long id = step.orderId().orElseThrow();
                    if (filled.getOrDefault(id, 0L) < known.get(id).qty()) {
                        resting.add(id);
                    }
                }
                for (Map.Entry<Long, Long> e : filled.entrySet()) {
                    long qty = known.get(e.getKey()).qty();
                    assertTrue(e.getValue() <= qty,
                            where + ": order " + e.getKey() + " filled " + e.getValue() + " > quantity " + qty);
                    if (e.getValue() == qty) {
                        resting.remove(e.getKey());
                    }
                }

                Map<Long, long[]> bids = new TreeMap<>();
                Map<Long, long[]> asks = new TreeMap<>();
                for (long id : resting) {
                    Known k = known.get(id);
                    long remaining = k.qty() - filled.getOrDefault(id, 0L);
                    if (remaining < k.qty()) {
                        partialChecks++;
                    }
                    long[] level = (k.side() == Order.Side.BUY ? bids : asks)
                            .computeIfAbsent(k.limit(), p -> new long[2]);
                    level[0] += remaining;
                    level[1]++;
                }
                assertEquals(levels(bids), aggregate(step.bids()), where + ": bid depth != quantity - filled");
                assertEquals(levels(asks), aggregate(step.asks()), where + ": ask depth != quantity - filled");
            }
        }
        assertTrue(trades > SEEDS * LENGTH / 10, "too few trades: " + trades);
        assertTrue(partialChecks > 0, "no partially filled order ever rested; remaining was not exercised");
    }

    /** Expected levels as price → "qty/orders", for a readable diff on failure. */
    private static Map<Long, String> levels(Map<Long, long[]> byPrice) {
        Map<Long, String> out = new TreeMap<>();
        byPrice.forEach((price, l) -> out.put(price, l[0] + "/" + l[1]));
        return out;
    }

    private static Map<Long, String> aggregate(List<OrderBook.Level> depth) {
        Map<Long, String> out = new TreeMap<>();
        for (OrderBook.Level l : depth) {
            out.put(l.price(), l.qty() + "/" + l.orders());
        }
        return out;
    }
}
