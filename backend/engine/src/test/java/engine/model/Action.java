package engine.model;

import engine.Order;

/** One step of a generated order flow against a single {@link engine.OrderBook}. */
public sealed interface Action permits Action.SubmitLimit, Action.SubmitMarket, Action.Cancel {

    /** Submit a limit order. */
    record SubmitLimit(Order.Side side, long price, long qty) implements Action {}

    /** Submit a market order. */
    record SubmitMarket(Order.Side side, long qty) implements Action {}

    /**
     * Cancel the {@code pickIndex}-th order still resting (in arrival order), modulo their count.
     * A no-op when nothing rests.
     */
    record Cancel(int pickIndex) implements Action {}
}
