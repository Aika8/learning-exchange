package bots;

import engine.Order;
import java.util.List;
import java.util.Random;

/**
 * Trades at random: with some probability per step it sends a small market order or a limit order near the best
 * price. It loses the spread on average — the lesson of "trading for the sake of trading".
 *
 * @param activity    probability of acting in a step, 0..1
 * @param maxQty      largest order
 * @param marketShare share of market orders among its orders, 0..1
 */
public record Noise(double activity, long maxQty, double marketShare) implements Strategy {

    @Override
    public List<Intent> decide(MarketView v, Random random) {
        if (random.nextDouble() >= activity) {
            return List.of();
        }
        Order.Side side = random.nextBoolean() ? Order.Side.BUY : Order.Side.SELL;
        long qty = 1 + random.nextInt((int) Math.max(1, maxQty));
        if (random.nextDouble() < marketShare) {
            return List.of(new Intent.Place(side, Order.Type.MARKET, 0, qty));
        }
        long ref = v.lastPrice() != null ? v.lastPrice() : v.fairValue();
        long offset = random.nextInt(30) - 10;
        long price = side == Order.Side.BUY ? ref - offset : ref + offset;
        return List.of(new Intent.Place(side, Order.Type.LIMIT, Math.max(1, price), qty));
    }
}
