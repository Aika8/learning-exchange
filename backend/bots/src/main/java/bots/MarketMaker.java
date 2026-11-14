package bots;

import engine.Order;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * Quotes both sides around fair value and earns the spread. Each step it pulls its old quotes and puts new ones.
 * When it holds more than its target inventory it shifts both quotes down (to sell more), and up when it holds less:
 * that inventory skew is how real market makers limit risk.
 *
 * @param halfSpread minor units between fair value and the best quote on each side
 * @param step       minor units between its own levels
 * @param levels     price levels per side
 * @param qty        quantity per level
 * @param targetBase inventory it tries to hold
 * @param skewPerUnit minor units of price shift per unit of inventory away from target
 */
public record MarketMaker(long halfSpread, long step, int levels, long qty, long targetBase, double skewPerUnit)
        implements Strategy {

    @Override
    public List<Intent> decide(MarketView v, Random random) {
        List<Intent> out = new ArrayList<>();
        out.add(new Intent.CancelAllMine());
        long skew = Math.round((v.baseTotal() - targetBase) * skewPerUnit);
        long centre = Math.max(1, v.fairValue() - skew);
        for (int i = 0; i < levels; i++) {
            long jitter = random.nextInt(3);
            long bid = centre - halfSpread - i * step - jitter;
            long ask = centre + halfSpread + i * step + jitter;
            long q = Math.max(1, qty + random.nextInt((int) Math.max(1, qty / 2)) - qty / 4);
            if (bid > 0) {
                out.add(new Intent.Place(Order.Side.BUY, Order.Type.LIMIT, bid, q));
            }
            out.add(new Intent.Place(Order.Side.SELL, Order.Type.LIMIT, ask, q));
        }
        return out;
    }
}
