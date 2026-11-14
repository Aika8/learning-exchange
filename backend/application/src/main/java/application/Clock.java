package application;

/**
 * Port: where time comes from. The engine never reads a clock; the application stamps commands with
 * {@link #now()} (simulation milliseconds). See docs/adr/0006-single-writer-and-sim-clock.md.
 */
public interface Clock {

    long now();

    /** Paused and speed are meaningful only for the simulation clock; other clocks run at speed 1. */
    default boolean paused() {
        return false;
    }

    default int speed() {
        return 1;
    }
}
