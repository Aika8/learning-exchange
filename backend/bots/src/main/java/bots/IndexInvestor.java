package bots;

import engine.Order;
import java.util.List;
import java.util.Random;

/**
 * Buys a fixed quantity every {@code everySteps} steps and never sells (dollar-cost averaging into the "basket"; one
 * bot per market of the basket). The quiet benchmark most active traders lose to.
 */
public record IndexInvestor(long everySteps, long qty) implements Strategy {

    @Override
    public List<Intent> decide(MarketView v, Random random) {
        if (v.step() % Math.max(1, everySteps) != 0) {
            return List.of();
        }
        return List.of(new Intent.Place(Order.Side.BUY, Order.Type.MARKET, 0, qty));
    }
}
