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
                            long protectiveSpread, String idempotencyKey) implements Command {
        public PlaceConditional(String account, String instrument, Conditional.Kind kind, Order.Side side, long qty,
                                long triggerPrice, long limitPrice, long activationPrice, long offset,
                                long protectiveSpread) {
            this(account, instrument, kind, side, qty, triggerPrice, limitPrice, activationPrice, offset, protectiveSpread, null);
        }
    }

    record CancelConditional(String account, long conditionalId) implements Command {}

    /** Opens a leveraged position at market; {@code side} BUY = long, SELL = short. */
    record OpenMargin(String account, String instrument, Order.Side side, long qty, int leverage,
                      String idempotencyKey) implements Command {
        public OpenMargin(String account, String instrument, Order.Side side, long qty, int leverage) {
            this(account, instrument, side, qty, leverage, null);
        }
    }

    record CloseMargin(String account, long positionId) implements Command {}

    /** Moves {@code amount} of {@code asset} to a savings deposit that compounds daily at {@code rateBps} a year. */
    record OpenSavings(String account, String asset, long amount, long rateBps, long dayMillis,
                       String idempotencyKey) implements Command {
        public OpenSavings(String account, String asset, long amount, long rateBps, long dayMillis) {
            this(account, asset, amount, rateBps, dayMillis, null);
        }
    }

    record CloseSavings(String account, long depositId) implements Command {}

    /** Pays interest for every whole bank day that has passed by the command's time. Sent by a timer. */
    record AccrueInterest() implements Command {}

    // ---- M2b (ADR-0021) ----

    /** Journals a disclosure as it is; it moves no money. */
    record Publish(Event.Disclosure disclosure) implements Command {}

    record SetTradingStatus(String instrument, boolean open, String reason) implements Command {}

    /** Dividend, coupon or redemption: {@code issuer} pays {@code perUnit} for each unit held by others. */
    record Payout(String instrument, Event.PayoutKind kind, String issuer, long perUnit) implements Command {}

    record DeclareDefault(String instrument, String issuer) implements Command {}

    // ---- M2c (ADR-0022) ----

    /** Attaches the owner's trade-journal note to an order (once). */
    record AnnotateOrder(String account, long orderId, String why, String marketState, String mood, long plannedRisk)
            implements Command {}

    /** At the open of the ex-date: fixes who is paid and adjusts the reference price. */
    record DividendExDate(String instrument, String issuer, long perShare, long recordDate, long payDate)
            implements Command {}

    /** At the pay date: pays the oldest fixed, unpaid dividend of the instrument, withholding {@code taxBps}. */
    record PayDividend(String instrument, long taxBps) implements Command {}

    /** Moves a fund's fee from custody to manager; the amount is decided by the caller from prices (journalled). */
    record ChargeFundFee(String fund, String custody, String manager, String asset, long amount, int days, long nav,
                         long basketValue) implements Command {}
}
