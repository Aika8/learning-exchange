package application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Order;
import engine.OrderBook;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CompletableFuture;
import org.junit.jupiter.api.Test;

/**
 * The fix for the race shown in {@code engine.OrderBookRaceTest}: the same workload — 8 threads, each placing and
 * cancelling non-crossing orders — through the {@link Sequencer} always ends consistent.
 */
class SequencerTest {

    @Test
    void sameWorkloadThroughTheSequencerIsAlwaysConsistent() {
        try (Sequencer<OrderBook> seq = new Sequencer<>("test", new OrderBook())) {
            List<Thread> workers = new ArrayList<>();
            int threads = 8;
            int perThread = 2_000;
            for (int t = 0; t < threads; t++) {
                Order.Side side = t % 2 == 0 ? Order.Side.BUY : Order.Side.SELL;
                long price = side == Order.Side.BUY ? 100 - t : 200 + t;
                workers.add(Thread.ofVirtual().start(() -> {
                    for (int i = 0; i < perThread; i++) {
                        long id = seq.call(b -> b.submit(Order.limit(side, price, 1)).orderId());
                        boolean cancelled = seq.call(b -> b.cancel(id));
                        assertTrue(cancelled);
                    }
                }));
            }
            for (Thread w : workers) {
                w.join();
            }
            boolean empty = seq.call(b -> b.bids(Integer.MAX_VALUE).isEmpty() && b.asks(Integer.MAX_VALUE).isEmpty());
            assertTrue(empty);
            long nextId = seq.call(b -> b.submit(Order.limit(Order.Side.BUY, 1, 1)).orderId());
            assertEquals((long) threads * perThread + 1, nextId);
        } catch (InterruptedException e) {
            throw new AssertionError(e);
        }
    }

    @Test
    void commandsRunInSubmissionOrderOnOneThread() {
        try (Sequencer<List<Integer>> seq = new Sequencer<>("order", new ArrayList<>())) {
            List<CompletableFuture<Boolean>> fs = new ArrayList<>();
            for (int i = 0; i < 1_000; i++) {
                int n = i;
                fs.add(seq.submit(list -> list.add(n)));
            }
            fs.forEach(CompletableFuture::join);
            List<Integer> seen = seq.call(List::copyOf);
            for (int i = 0; i < 1_000; i++) {
                assertEquals(i, seen.get(i));
            }
            String name = seq.call(l -> Thread.currentThread().getName());
            assertTrue(name.startsWith("sequencer-order"));
        } catch (InterruptedException e) {
            throw new AssertionError(e);
        }
    }
}
