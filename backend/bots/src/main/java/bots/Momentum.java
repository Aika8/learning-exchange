package bots;

import engine.Order;
import java.util.List;
import java.util.Random;

/**
 * Follows the trend: buys after the price rose more than {@code thresholdBps} over its look-back window, sells what it
 * holds after a fall. Pays the spread to get in and out — and shows the leverage trap when the trend reverses.
 */
public record Momentum(long thresholdBps, long qty, double activity) implements Strategy {

    @Override
    public List<Intent> decide(MarketView v, Random random) {
        List<Long> p = v.recentPrices();
        if (p.size() < 2 || random.nextDouble() >= activity) {
            return List.of();
        }
        long first = p.getFirst();
        long last = p.getLast();
        long changeBps = first == 0 ? 0 : (last - first) * 10_000 / first;
        if (changeBps > thresholdBps) {
            return List.of(new Intent.Place(Order.Side.BUY, Order.Type.MARKET, 0, qty));
        }
        if (changeBps < -thresholdBps && v.baseAvailable() > 0) {
            return List.of(new Intent.Place(Order.Side.SELL, Order.Type.MARKET, 0, Math.min(qty, v.baseAvailable())));
        }
        return List.of();
    }
}
