package engine;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.Test;

/**
 * The test intent 01 asked for before deciding on concurrency: several threads calling one {@link OrderBook}
 * directly break it. Each thread places a non-crossing order and cancels it again, so a correct book ends empty with
 * one id per submit. Under a race we see lost or duplicated ids, a leftover order, or an exception.
 *
 * <p>This test asserts that the race <b>is</b> observable (it documents the problem). The fix — one sequencer
 * thread per book — is tested in the application module (SequencerTest). See docs/adr/0006-single-writer-and-sim-clock.md.
 */
class OrderBookRaceTest {

    @Test
    void concurrentCallersCorruptAnUnguardedBook() throws Exception {
        boolean broken = false;
        for (int attempt = 0; attempt < 20 && !broken; attempt++) {
            broken = runOnce(8, 5_000);
        }
        assertTrue(broken, "expected the unguarded book to show a race at least once in 20 attempts");
    }

    /** Returns true if the book ended in a state a single thread could never produce. */
    private static boolean runOnce(int threads, int perThread) throws Exception {
        OrderBook book = new OrderBook();
        AtomicBoolean failed = new AtomicBoolean();
        AtomicLong maxId = new AtomicLong();
        CountDownLatch start = new CountDownLatch(1);
        List<Thread> workers = new ArrayList<>();
        for (int t = 0; t < threads; t++) {
            Order.Side side = t % 2 == 0 ? Order.Side.BUY : Order.Side.SELL;
            long price = side == Order.Side.BUY ? 100 - t : 200 + t;
            // Daemon: a race can corrupt the book's maps so that a thread loops forever; it must not keep the JVM alive.
            Thread w = Thread.ofPlatform().daemon().start(() -> {
                try {
                    start.await();
                    for (int i = 0; i < perThread; i++) {
                        long id = book.submit(Order.limit(side, price, 1)).orderId();
                        maxId.accumulateAndGet(id, Math::max);
                        if (!book.cancel(id)) {
                            failed.set(true);
                        }
                    }
                } catch (RuntimeException | InterruptedException e) {
                    failed.set(true);
                }
            });
            workers.add(w);
        }
        start.countDown();
        // A thread stuck in a corrupted map is a race too: give up on it instead of joining forever.
        long deadline = System.nanoTime() + java.util.concurrent.TimeUnit.SECONDS.toNanos(10);
        for (Thread w : workers) {
            long left = deadline - System.nanoTime();
            if (left <= 0 || !w.join(java.time.Duration.ofNanos(left))) {
                return true;
            }
        }
        long submits = (long) threads * perThread;
        return failed.get()
                || maxId.get() != submits
                || !book.bids(Integer.MAX_VALUE).isEmpty()
                || !book.asks(Integer.MAX_VALUE).isEmpty();
    }
}
