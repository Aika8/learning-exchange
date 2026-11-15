package bots;

import application.Clock;
import java.util.List;

/**
 * Drives the bots on simulation time: each {@link #tick()} (called every {@code tickMillis} of real time) runs one
 * step per unit of clock speed, and none while the clock is paused. Each market's fair value steps once per bot step.
 */
public final class BotRunner {

    /** The bots of one market and the fair value they share. */
    public record Group(FairValue fairValue, List<TradingBot> bots) {
        public Group {
            bots = List.copyOf(bots);
        }
    }

    private final List<Group> groups;
    private final Clock clock;
    private WorldFeed world;

    public BotRunner withWorld(WorldFeed world) {
        this.world = world;
        return this;
    }

    public WorldFeed world() {
        return world;
    }

    public BotRunner(List<Group> groups, Clock clock) {
        this.groups = List.copyOf(groups);
        this.clock = clock;
    }

    /** One market only (M1 shape). */
    public BotRunner(List<TradingBot> bots, FairValue fairValue, Clock clock) {
        this(List.of(new Group(fairValue, bots)), clock);
    }

    public void tick() {
        if (clock.paused()) {
            return;
        }
        if (world != null) {
            world.refreshBonds();
        }
        for (int s = 0; s < clock.speed(); s++) {
            for (Group g : groups) {
                long fv = g.fairValue().step();
                for (TradingBot bot : g.bots()) {
                    bot.step(fv);
                }
            }
        }
    }

    public List<TradingBot> bots() {
        return groups.stream().flatMap(g -> g.bots().stream()).toList();
    }

    public List<Group> groups() {
        return groups;
    }

    /** Fair value of the first market. */
    public long fairValue() {
        return groups.getFirst().fairValue().value();
    }
}
