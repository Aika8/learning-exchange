package engine;

/**
 * What a caller asks the exchange to do. Commands are plain data; {@link Exchange#execute} decides and answers with
 * {@link Event events}. Pattern: Command — requests are objects, so they can be queued by the single writer and
 * re-run on replay. See docs/adr/0005-event-sourcing-journal.md.
 */
public sealed interface Command {

    record OpenAccount(String account, String name) implements Command {}

    record Deposit(String account, String asset, long amount) implements Command {}

    /**
     * @param price          limit price in quote minor units; ignored (0) for market orders
     * @param idempotencyKey optional client key; a repeated key returns the first order instead of a new one
     */
    record PlaceOrder(String account, String instrument, Order.Side side, Order.Type type, long price, long qty,
                      String idempotencyKey) implements Command {}

    record CancelOrder(String account, long orderId) implements Command {}

    /** A stop or take-profit kept outside the book (ADR-0008). Unused prices are 0. */
    record PlaceConditional(String account, String instrument, Conditional.Kind kind, Order.Side side, long qty,
                            long triggerPrice, long limitPrice, long activationPrice, long offset,
                            long protectiveSpread) implements Command {}

    record CancelConditional(String account, long conditionalId) implements Command {}

    /** Opens a leveraged position at market; {@code side} BUY = long, SELL = short. */
    record OpenMargin(String account, String instrument, Order.Side side, long qty, int leverage) implements Command {}

    record CloseMargin(String account, long positionId) implements Command {}

    /** Moves {@code amount} of {@code asset} to a savings deposit that compounds daily at {@code rateBps} a year. */
    record OpenSavings(String account, String asset, long amount, long rateBps, long dayMillis) implements Command {}

    record CloseSavings(String account, long depositId) implements Command {}

    /** Pays interest for every whole bank day that has passed by the command's time. Sent by a timer. */
    record AccrueInterest() implements Command {}
}
