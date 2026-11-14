package application;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.CompletionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import java.util.function.Function;

/**
 * Owns a piece of state and runs every command against it on one thread, in arrival order. Callers get a
 * {@link CompletableFuture}. There are no locks around the state because only this thread ever touches it.
 *
 * <p>Pattern: Single Writer (LMAX) / actor-like command queue. See docs/adr/0006-single-writer-and-sim-clock.md.
 * The race this prevents is shown by {@code engine.OrderBookRaceTest}.
 */
public final class Sequencer<S> implements AutoCloseable {

    private final S state;
    private final ExecutorService thread;

    public Sequencer(String name, S state) {
        this.state = state;
        this.thread = Executors.newSingleThreadExecutor(r -> Thread.ofPlatform().name("sequencer-" + name).daemon().unstarted(r));
    }

    public <T> CompletableFuture<T> submit(Function<S, T> command) {
        return CompletableFuture.supplyAsync(() -> command.apply(state), thread);
    }

    /** Submits and waits; for callers that are already on their own (virtual) thread. */
    public <T> T call(Function<S, T> command) {
        try {
            return submit(command).join();
        } catch (CompletionException e) {
            if (e.getCause() instanceof RuntimeException cause) {
                throw cause;
            }
            throw e;
        }
    }

    @Override
    public void close() throws InterruptedException {
        thread.shutdown();
        thread.awaitTermination(5, TimeUnit.SECONDS);
    }
}
