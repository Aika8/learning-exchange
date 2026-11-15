package engine;

/**
 * Read view of a conditional order. {@code state} combines the rule's phase with the generated order:
 * WAITING, ARMED, TRIGGERED, SUBMITTED, PARTIALLY_FILLED, FILLED, UNFILLED, REJECTED, CANCELLED.
 */
public record ConditionalView(long conditionalId, String account, String instrument, Conditional.Kind kind,
                              Order.Side side, long qty, long triggerPrice, long limitPrice, long activationPrice,
                              long offset, long protectiveSpread, State state, Long bestPrice, Long triggeredTs,
                              Long triggerTradePrice, Long orderId, long filledQty, String rejection, long createdTs) {

    public enum State { WAITING, ARMED, TRIGGERED, SUBMITTED, PARTIALLY_FILLED, FILLED, UNFILLED, REJECTED, CANCELLED }
}
