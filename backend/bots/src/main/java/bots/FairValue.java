package bots;

import java.util.Random;

/**
 * The hidden "true" price that market makers quote around: a seeded random walk in minor units, never below
 * {@code floor}. World events move it (M2b, ADR-0007): a storm multiplies its volatility, a report surprise or a rate
 * surprise makes it {@link #jump}, a dividend lowers it at the ex-date, and a bond's walk is pulled toward the price its
 * yield implies ({@link #anchor}).
 *
 * <p>Written by the market-data thread (events) and read by the bots thread, so it is synchronised.
 */
public final class FairValue {

    private final Random random;
    private final double volatilityBps;
    private final long floor;
    private long value;
    private int volatilityPct = 100;
    private Long anchor;

    public FairValue(long start, double volatilityBps, long floor, long seed) {
        this.value = start;
        this.volatilityBps = volatilityBps;
        this.floor = floor;
        this.random = new Random(seed);
    }

    public synchronized long value() {
        return value;
    }

    public synchronized long step() {
        long move = Math.round(value * random.nextGaussian() * volatilityBps * volatilityPct / 100 / 10_000.0);
        if (anchor != null) {
            move += (anchor - value) / 20; // 5% of the way back to the anchor each step
        }
        value = Math.max(floor, value + move);
        return value;
    }

    /** Moves the value by {@code bps} basis points at once (a gap). */
    public synchronized void jump(long bps) {
        value = Math.max(floor, value + Math.multiplyExact(value, bps) / 10_000);
    }

    /** Moves the value by {@code amount} minor units at once (a dividend paid out). */
    public synchronized void shift(long amount) {
        value = Math.max(floor, value + amount);
    }

    /** 100 = normal; a storm is 200–400. */
    public synchronized void volatilityPct(int pct) {
        this.volatilityPct = Math.max(1, pct);
    }

    public synchronized void anchor(Long price) {
        this.anchor = price;
    }
}
