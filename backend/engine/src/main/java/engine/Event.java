package engine;

/**
 * Something that happened, in the order it happened. Events are the source of truth (ADR-0005): the journal
 * stores them, and replaying them rebuilds the state.
 *
 * <p>{@code ts} is simulation time in milliseconds, supplied by the caller; the engine never reads a clock.
 *
 * <p>Two kinds: <b>decisions</b> ({@link AccountOpened}, {@link FundsDeposited}, {@link OrderAccepted},
 * {@link OrderCancelled}, {@link ClockChanged}) are re-executed on replay; <b>consequences</b> ({@link TradeExecuted},
 * {@link OrderExpired}) are produced again by the deterministic engine and checked, not applied.
 */
public sealed interface Event {

    long ts();

    record AccountOpened(long ts, String account, String name) implements Event {}

    record FundsDeposited(long ts, String account, String asset, long amount) implements Event {}

    record OrderAccepted(long ts, long orderId, String account, String instrument, Order.Side side, Order.Type type,
                         long price, long qty, String idempotencyKey) implements Event {}

    /**
     * One execution. Fees are in the quote asset: the buyer pays {@code price*qty + buyerFee}, the seller receives
     * {@code price*qty - sellerFee}; both fees go to {@link Ledger#FEES_ACCOUNT}.
     */
    record TradeExecuted(long ts, long tradeId, String instrument, long buyOrderId, long sellOrderId, String buyer,
                         String seller, long price, long qty, Order.Side aggressorSide, long buyerFee,
                         long sellerFee) implements Event {}

    record OrderCancelled(long ts, long orderId, String account, long remainingQty) implements Event {}

    /** The unfilled remainder of a market order: it never rests (intent 01, invariant 4). */
    record OrderExpired(long ts, long orderId, String account, long remainingQty) implements Event {}

    /** The simulation clock was paused, resumed or re-speeded. The engine ignores it; replay restores the clock. */
    record ClockChanged(long ts, boolean paused, int speed) implements Event {}

    default boolean isDecision() {
        return !(this instanceof TradeExecuted || this instanceof OrderExpired);
    }
}
