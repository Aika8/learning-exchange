package application;

/** Test clock: time moves only when the test says so. */
public final class ManualClock implements Clock {

    private long now;

    public ManualClock(long start) {
        this.now = start;
    }

    @Override
    public synchronized long now() {
        return now;
    }

    public synchronized void advance(long millis) {
        now += millis;
    }
}
