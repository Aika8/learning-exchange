package bots;

import engine.Order;
import java.util.List;
import java.util.Random;

/**
 * Values a company from its published reports: value = target P/E × yearly EPS from the latest guidance. Buys when the
 * price is more than {@code marginBps} below that value and sells above it. Waits until the first report.
 */
public record Fundamentalist(long targetPe, long marginBps, long qty, double activity) implements Strategy {

    @Override
    public List<Intent> decide(MarketView v, Random random) {
        if (v.fundamentalValue() == null || v.lastPrice() == null || random.nextDouble() >= activity) {
            return List.of();
        }
        long value = v.fundamentalValue() * targetPe;
        long price = v.lastPrice();
        if (price * 10_000 < value * (10_000 - marginBps)) {
            return List.of(new Intent.CancelAllMine(), new Intent.Place(Order.Side.BUY, Order.Type.LIMIT, price, qty));
        }
        if (price * 10_000 > value * (10_000 + marginBps) && v.baseAvailable() > 0) {
            return List.of(new Intent.CancelAllMine(),
                    new Intent.Place(Order.Side.SELL, Order.Type.LIMIT, price, Math.min(qty, v.baseAvailable())));
        }
        return List.of();
    }
}
