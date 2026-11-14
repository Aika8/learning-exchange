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
}
