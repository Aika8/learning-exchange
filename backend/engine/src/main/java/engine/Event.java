package engine;

/**
 * Something that happened, in the order it happened. Events are the source of truth (ADR-0005): the journal
 * stores them, and replaying them rebuilds the state.
 *
 * <p>{@code ts} is simulation time in milliseconds, supplied by the caller; the engine never reads a clock.
 *
 * <p>Two kinds: <b>decisions</b> (the first event of each accepted command, plus {@link ClockChanged}) are
 * re-executed on replay; <b>consequences</b> (everything a command caused after its first event: trades, expiries,
 * fired stops, stop-outs…) are produced again by the deterministic engine and checked, not applied.
 * Consequences of one command always follow its decision directly in the journal.
 */
public sealed interface Event {

    long ts();

    record AccountOpened(long ts, String account, String name) implements Event {}

    record FundsDeposited(long ts, String account, String asset, long amount) implements Event {}

    /** {@code account} may be a sub-account of a leveraged position ({@code owner~m<id>}); see {@link Accounts}. */
    record OrderAccepted(long ts, long orderId, String account, String instrument, Order.Side side, Order.Type type,
                         long price, long qty, String idempotencyKey) implements Event {}

    /**
     * One execution. Fees are in the quote asset: the buyer pays {@code price*qty + buyerFee}, the seller receives
     * {@code price*qty - sellerFee}; both fees go to {@link Ledger#FEES_ACCOUNT}. {@code mid} is the middle of the
     * best bid and ask just before the aggressive order arrived (rounded down; 0 if one side was empty): the
     * statement uses it to show the spread each side paid.
     */
    record TradeExecuted(long ts, long tradeId, String instrument, long buyOrderId, long sellOrderId, String buyer,
                         String seller, long price, long qty, Order.Side aggressorSide, long buyerFee,
                         long sellerFee, long mid) implements Event {}

    record OrderCancelled(long ts, long orderId, String account, long remainingQty) implements Event {}

    /** The unfilled remainder of a market order: it never rests (intent 01, invariant 4). */
    record OrderExpired(long ts, long orderId, String account, long remainingQty) implements Event {}

    /** The simulation clock was paused, resumed or re-speeded. The engine ignores it; replay restores the clock. */
    record ClockChanged(long ts, boolean paused, int speed) implements Event {}

    // ---- conditional orders (ADR-0008) ----

    record ConditionalPlaced(long ts, long conditionalId, String account, String instrument, Conditional.Kind kind,
                             Order.Side side, long qty, long triggerPrice, long limitPrice, long activationPrice,
                             long offset, long protectiveSpread, String idempotencyKey) implements Event {}

    record ConditionalCancelled(long ts, long conditionalId, String account) implements Event {}

    /** A trailing take-profit reached its activation price and now follows the best price. */
    record ConditionalArmed(long ts, long conditionalId, String account, long lastPrice) implements Event {}

    /**
     * The rule fired on the last trade price {@code lastPrice}. {@code orderId} is the generated order, or 0 if it
     * was refused ({@code rejection}). Fired is not filled: the order's own status says how far it got.
     */
    record ConditionalTriggered(long ts, long conditionalId, String account, long lastPrice, long orderId,
                                String rejection) implements Event {}

    // ---- leverage (ADR-0008, stop-out) ----

    /** {@code collateral} came from the owner, the loans from {@link Ledger#BANK_ACCOUNT}. */
    record MarginPositionOpened(long ts, long positionId, String account, String instrument, Order.Side side,
                                long qty, int leverage, long collateral, long loanQuote, long loanBase,
                                String idempotencyKey) implements Event {}

    record MarginCloseRequested(long ts, long positionId, String account) implements Event {}

    /** Equity fell to half of the collateral at last trade price {@code lastPrice}: the exchange closes the position. */
    record MarginStopOut(long ts, long positionId, String account, long lastPrice, long equity, long collateral)
            implements Event {}

    /**
     * Flat again: loans repaid as far as possible, the rest returned to the owner. {@code badDebt*} is what the
     * position could not repay (a gap through the stop-out); the bank carries that loss.
     */
    record MarginPositionClosed(long ts, long positionId, String account, String reason, long returnedQuote,
                                long returnedBase, long badDebtQuote, long badDebtBase) implements Event {}

    // ---- savings ----

    record SavingsOpened(long ts, long depositId, String account, String asset, long amount, long rateBps,
                         long dayMillis, String idempotencyKey) implements Event {}

    /** Interest for {@code days} bank days, paid by {@link Ledger#BANK_ACCOUNT}, compounded into the deposit. */
    record InterestAccrued(long ts, long depositId, String account, long amount, int days, long balanceAfter)
            implements Event {}

    record SavingsClosed(long ts, long depositId, String account, long payout) implements Event {}

    // ---- M2b: disclosures (move no money), trading status, payouts (ADR-0021) ----

    /**
     * Information published to everyone: consensus forecasts, company reports, rate decisions, insider trades, market
     * regimes. It moves no money; the engine journals it as given, and read models (calendar, company card) and the
     * bots react to it. The generator that writes it is seeded, but replay never re-runs the generator: the
     * journalled disclosure itself is the decision.
     */
    sealed interface Disclosure extends Event {}

    /** Analysts' expectation for the coming report («Счётчики Гильдии»), published days before it. */
    record ConsensusPublished(long ts, String instrument, int season, long reportAt, long revenue, long netProfit,
                              long eps) implements Disclosure {}

    /**
     * A quarterly report, published while the instrument is halted ("at night"). Money in the quote asset's minor
     * units; {@code eps} per share; {@code guidanceEps} is management's forecast for the next season.
     */
    record EarningsReported(long ts, String instrument, int season, long revenue, long netProfit, long eps, long debt,
                            long operatingCashFlow, long dividendPerShare, long guidanceEps, long sharesOutstanding,
                            long consensusEps) implements Disclosure {}

    /** A dividend: holders at the ex-date are paid {@code perShare}; the price opens lower by about that much. */
    record DividendAnnounced(long ts, String instrument, long perShare, long exDate) implements Disclosure {}

    /** An insider (a director of the company) reported a trade in its shares. */
    record InsiderTradeDisclosed(long ts, String instrument, String insider, String role, Order.Side side, long qty,
                                 long price) implements Disclosure {}

    /** The central bank's calendar entry: decision {@code number} at {@code decisionAt}, with consensus and inflation. */
    record RateDecisionScheduled(long ts, int number, long decisionAt, long consensusBps, long inflationBps)
            implements Disclosure {}

    record RateDecided(long ts, int number, long rateBps, long previousBps, long consensusBps, long inflationBps)
            implements Disclosure {}

    /** World weather: a storm is a high-volatility regime; {@code volatilityPct} multiplies normal volatility. */
    record MarketRegimeChanged(long ts, String regime, int volatilityPct) implements Disclosure {}

    /** A paper ("учебная") position on a real-world quote (ADR-0015): a note, never an engine trade. */
    record PaperPositionOpened(long ts, long paperId, String account, String symbol, Order.Side side, long qty,
                               long price, long quotedAt, String source, String idempotencyKey) implements Disclosure {}

    record PaperPositionClosed(long ts, long paperId, String account, long price, long quotedAt) implements Disclosure {}

    /** Trading on {@code instrument} stopped or resumed (report night, maturity). Cancels are still allowed. */
    record TradingStatusChanged(long ts, String instrument, boolean open, String reason) implements Event {}

    enum PayoutKind { DIVIDEND, COUPON, REDEMPTION }

    /**
     * The issuer pays {@code perUnit} quote minor units for every unit held by anyone else; {@code units} and
     * {@code total} are what that came to. A redemption also takes the units back (the bond is repaid).
     * Followed by one {@link PayoutPaid} per holder.
     */
    record PayoutStarted(long ts, String instrument, PayoutKind kind, String issuer, long perUnit, long units, long total)
            implements Event {}

    record PayoutPaid(long ts, String instrument, PayoutKind kind, String holder, long units, long amount) implements Event {}

    /** The issuer could not pay a coupon: no more coupons; a later redemption pays only what is recovered. */
    record BondDefaulted(long ts, String instrument, String issuer) implements Event {}
}
