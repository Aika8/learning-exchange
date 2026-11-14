package bots;

import java.util.Random;

/**
 * The hidden "true" price that market makers quote around: a seeded random walk in minor units. In M2 world events
 * (storms) will drive it; for the walking skeleton it only wanders, and never below {@code floor}.
 */
public final class FairValue {

    private final Random random;
    private final double volatilityBps;
    private final long floor;
    private long value;

    public FairValue(long start, double volatilityBps, long floor, long seed) {
        this.value = start;
        this.volatilityBps = volatilityBps;
        this.floor = floor;
        this.random = new Random(seed);
    }

    public long value() {
        return value;
    }

    public long step() {
        long move = Math.round(value * random.nextGaussian() * volatilityBps / 10_000.0);
        value = Math.max(floor, value + move);
        return value;
    }
}
