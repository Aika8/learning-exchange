package application;

import java.util.function.LongSupplier;

/**
 * Simulation time that can be paused and sped up: {@code sim = anchorSim + (real - anchorReal) × speed}.
 * Changing pause or speed re-anchors, so simulation time never jumps.
 *
 * <p>Pattern: Clock abstraction (injected time) — real time is just another supplier, so tests drive it by hand.
 * See docs/adr/0006-single-writer-and-sim-clock.md.
 */
public final class SimulationClock implements Clock {

    public static final int MAX_SPEED = 60;

    private final LongSupplier realMillis;
    private long anchorReal;
    private long anchorSim;
    private boolean paused;
    private int speed = 1;

    public SimulationClock(LongSupplier realMillis, long startSim) {
        this.realMillis = realMillis;
        this.anchorReal = realMillis.getAsLong();
        this.anchorSim = startSim;
    }

    @Override
    public synchronized long now() {
        if (paused) {
            return anchorSim;
        }
        return anchorSim + (realMillis.getAsLong() - anchorReal) * speed;
    }

    @Override
    public synchronized boolean paused() {
        return paused;
    }

    @Override
    public synchronized int speed() {
        return speed;
    }

    public synchronized void set(boolean paused, int speed) {
        if (speed < 1 || speed > MAX_SPEED) {
            throw new IllegalArgumentException("speed must be 1.." + MAX_SPEED + ": " + speed);
        }
        long simNow = now();
        this.anchorReal = realMillis.getAsLong();
        this.anchorSim = simNow;
        this.paused = paused;
        this.speed = speed;
    }

    /** Used on replay: continue from the journalled simulation time, never going back. */
    public synchronized void resumeFrom(long sim, boolean paused, int speed) {
        this.anchorReal = realMillis.getAsLong();
        this.anchorSim = Math.max(sim, now());
        this.paused = paused;
        this.speed = speed;
    }
}
