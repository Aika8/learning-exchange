package bots;

import application.Clock;
import java.util.List;

/**
 * Drives the bots on simulation time: each {@link #tick()} (called every {@code tickMillis} of real time) runs one
 * step per unit of clock speed, and none while the clock is paused. Fair value steps once per bot step.
 */
public final class BotRunner {

    private final List<TradingBot> bots;
    private final FairValue fairValue;
    private final Clock clock;

    public BotRunner(List<TradingBot> bots, FairValue fairValue, Clock clock) {
        this.bots = List.copyOf(bots);
        this.fairValue = fairValue;
        this.clock = clock;
    }

    public void tick() {
        if (clock.paused()) {
            return;
        }
        for (int s = 0; s < clock.speed(); s++) {
            long fv = fairValue.step();
            for (TradingBot bot : bots) {
                bot.step(fv);
            }
        }
    }

    public List<TradingBot> bots() {
        return bots;
    }

    public long fairValue() {
        return fairValue.value();
    }
}
