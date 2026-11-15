package engine;

/**
 * One conditional order (stop or take-profit) kept outside the book, as a broker server keeps it in QUIK
 * (vault: finance/stop-loss-take-profit.md). It watches the <b>last trade price</b> only, never book quotes
 * (intent 02, invariant 5). When it fires it says which ordinary order to submit; the order may still not fill.
 *
 * <p>Pattern: State machine — {@code WAITING → (ARMED) → TRIGGERED}, or {@code CANCELLED}. After the trigger the
 * displayed state follows the generated order: SUBMITTED, PARTIALLY_FILLED, FILLED, UNFILLED, or REJECTED.
 * "Triggered" never means "closed". See docs/adr/0008-conditional-orders-outside-book.md.
 *
 * <p>Direction: a SELL closes a long, so its stop fires when the price falls ({@code last ≤ trigger}) and its
 * take-profit arms when the price rises ({@code last ≥ activation}); a BUY is the mirror image.
 */
public final class Conditional {

    public enum Kind { STOP_LIMIT, STOP_MARKET, TRAILING_TP, TP_SL }

    /** Lifecycle of the rule itself. What happened to the generated order is in {@link Exchange#conditionalView}. */
    public enum Phase { WAITING, ARMED, TRIGGERED, CANCELLED }

    /** The ordinary order a fired rule submits. {@code price} is 0 for a market order. */
    public record Fire(Order.Type type, long price) {}

    final long id;
    final String account;
    final String instrument;
    final Kind kind;
    final Order.Side side;
    final long qty;
    final long triggerPrice;
    final long limitPrice;
    final long activationPrice;
    final long offset;
    final long protectiveSpread;
    final long createdTs;

    Phase phase = Phase.WAITING;
    long bestPrice;
    long triggeredTs;
    long triggerTradePrice;
    long orderId;
    String rejection;

    Conditional(long id, Command.PlaceConditional c, long ts) {
        this.id = id;
        this.account = c.account();
        this.instrument = c.instrument();
        this.kind = c.kind();
        this.side = c.side();
        this.qty = c.qty();
        this.triggerPrice = c.triggerPrice();
        this.limitPrice = c.limitPrice();
        this.activationPrice = c.activationPrice();
        this.offset = c.offset();
        this.protectiveSpread = c.protectiveSpread();
        this.createdTs = ts;
    }

    /** Checks the parameters of a new conditional order; null if fine. */
    static Rejection validate(Command.PlaceConditional c) {
        if (c.kind() == null || c.side() == null || c.qty() <= 0) {
            return Rejection.INVALID_ORDER;
        }
        boolean ok = switch (c.kind()) {
            case STOP_LIMIT -> c.triggerPrice() > 0 && c.limitPrice() > 0;
            case STOP_MARKET -> c.triggerPrice() > 0;
            case TRAILING_TP -> c.activationPrice() > 0 && c.offset() >= 0;
            case TP_SL -> c.activationPrice() > 0 && c.offset() >= 0 && c.triggerPrice() > 0 && c.limitPrice() >= 0
                    // the stop must be on the losing side of the take-profit
                    && (c.side() == Order.Side.SELL ? c.triggerPrice() < c.activationPrice() : c.triggerPrice() > c.activationPrice());
        };
        return ok ? null : Rejection.INVALID_ORDER;
    }

    boolean live() {
        return phase == Phase.WAITING || phase == Phase.ARMED;
    }

    /** What the last trade at {@code last} does to this rule. */
    sealed interface Step {}

    record Nothing() implements Step {}

    record Armed() implements Step {}

    record Fired(Fire order) implements Step {}

    /** Feeds one last-trade price. Mutates the phase and the best price; the caller submits the fired order. */
    Step onTrade(long last) {
        if (!live()) {
            return new Nothing();
        }
        boolean sell = side == Order.Side.SELL;
        return switch (kind) {
            case STOP_LIMIT -> stopHit(last, sell) ? fire(last, Order.Type.LIMIT, limitPrice) : new Nothing();
            case STOP_MARKET -> stopHit(last, sell) ? fire(last, Order.Type.MARKET, 0) : new Nothing();
            case TRAILING_TP -> trail(last, sell);
            case TP_SL -> {
                // OCO: once the take-profit armed, the stop is no longer checked.
                if (phase == Phase.WAITING && stopHit(last, sell)) {
                    yield limitPrice > 0 ? fire(last, Order.Type.LIMIT, limitPrice) : fire(last, Order.Type.MARKET, 0);
                }
                yield trail(last, sell);
            }
        };
    }

    private boolean stopHit(long last, boolean sell) {
        return sell ? last <= triggerPrice : last >= triggerPrice;
    }

    private Step trail(long last, boolean sell) {
        if (phase == Phase.WAITING) {
            if (sell ? last >= activationPrice : last <= activationPrice) {
                phase = Phase.ARMED;
                bestPrice = last;
                return new Armed();
            }
            return new Nothing();
        }
        bestPrice = sell ? Math.max(bestPrice, last) : Math.min(bestPrice, last);
        if (sell && last < bestPrice - offset) {
            return fire(last, Order.Type.LIMIT, last - protectiveSpread);
        }
        if (!sell && last > bestPrice + offset) {
            // Mirror of the sell case, capped at the "blocking level" activation + offset + spread (QUIK).
            return fire(last, Order.Type.LIMIT, Math.min(last + protectiveSpread, activationPrice + offset + protectiveSpread));
        }
        return new Nothing();
    }

    private Step fire(long last, Order.Type type, long price) {
        phase = Phase.TRIGGERED;
        triggerTradePrice = last;
        return new Fired(new Fire(type, price));
    }
}
