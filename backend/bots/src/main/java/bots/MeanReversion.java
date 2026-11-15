package bots;

import engine.Order;
import java.util.List;
import java.util.Random;

/**
 * Bets the price returns to its average: when the last price is more than {@code bandBps} below the window's mean it
 * bids at the last price; more than {@code bandBps} above, it offers. Limit orders only — it earns the spread when it is
 * right and gets run over in a real trend.
 */
public record MeanReversion(long bandBps, long qty, double activity) implements Strategy {

    @Override
    public List<Intent> decide(MarketView v, Random random) {
        List<Long> p = v.recentPrices();
        if (p.size() < 5 || v.lastPrice() == null || random.nextDouble() >= activity) {
            return List.of();
        }
        long mean = p.stream().mapToLong(Long::longValue).sum() / p.size();
        long last = v.lastPrice();
        long gapBps = mean == 0 ? 0 : (last - mean) * 10_000 / mean;
        if (gapBps < -bandBps) {
            return List.of(new Intent.CancelAllMine(), new Intent.Place(Order.Side.BUY, Order.Type.LIMIT, last, qty));
        }
        if (gapBps > bandBps && v.baseAvailable() > 0) {
            return List.of(new Intent.CancelAllMine(),
                    new Intent.Place(Order.Side.SELL, Order.Type.LIMIT, last, Math.min(qty, v.baseAvailable())));
        }
        return List.of();
    }
}
