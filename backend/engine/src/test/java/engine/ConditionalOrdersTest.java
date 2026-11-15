package engine;

import static engine.Order.Side.BUY;
import static engine.Order.Side.SELL;
import static engine.Order.Type.LIMIT;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Conditional orders (ADR-0008, vault finance/stop-loss-take-profit.md): they fire on the last trade price only,
 * and "fired" is not "filled".
 */
class ConditionalOrdersTest {

    private static final String I = "SILK-SPARK";
    private Exchange ex;
    private long ts;

    @BeforeEach
    void setUp() {
        ex = new Exchange(List.of(Instrument.SILK_SPARK));
        for (String a : List.of("alice", "maker", "taker")) {
            run(new Command.OpenAccount(a, a));
            run(new Command.Deposit(a, "SPARK", 100_000_000));
            run(new Command.Deposit(a, "SILK", 1_000));
        }
    }

    @Test
    void stopIgnoresBookQuotesAndFiresOnTheLastTradePrice() {
        long id = stop(Conditional.Kind.STOP_MARKET, SELL, 5, 950, 0);
        trade(1_000);
        // A bid below the stop is only a quote: no trade happened there, so the stop must not fire.
        place("maker", BUY, 940, 50);
        assertEquals(ConditionalView.State.WAITING, state(id));

        trade(950);

        ConditionalView v = ex.conditional(id).orElseThrow();
        assertEquals(ConditionalView.State.FILLED, v.state());
        assertEquals(950L, v.triggerTradePrice());
        assertEquals(5, v.filledQty());
    }

    @Test
    void stopLimitThroughAGapIsTriggeredButNotFilled() {
        long id = stop(Conditional.Kind.STOP_LIMIT, SELL, 5, 950, 940);
        trade(1_000);

        trade(900); // the market jumped over both the stop and the limit price

        ConditionalView v = ex.conditional(id).orElseThrow();
        assertEquals(ConditionalView.State.SUBMITTED, v.state(), "fired, its sell at 9.40 rests above the market");
        assertEquals(0, v.filledQty());
        assertEquals(900L, v.triggerTradePrice());
        assertTrue(ex.order(v.orderId()).orElseThrow().open());
    }

    @Test
    void trailingTakeProfitFollowsTheBestPriceAndFiresOnAPullBack() {
        // The QUIK example: TP ≥ 1110, offset 5, protective spread 2; 1120 → 1125 → 1135 → 1130 sells at 1128.
        long id = run(new Command.PlaceConditional("alice", I, Conditional.Kind.TRAILING_TP, SELL, 3, 0, 0, 1_110, 5, 2)).orderId();
        trade(1_100);
        assertEquals(ConditionalView.State.WAITING, state(id));
        trade(1_120);
        assertEquals(ConditionalView.State.ARMED, state(id));
        trade(1_125);
        trade(1_135);
        trade(1_131); // pull-back of 4 ≤ offset: keep following
        assertEquals(ConditionalView.State.ARMED, state(id));

        Outcome o = trade(1_129);

        ConditionalView v = ex.conditional(id).orElseThrow();
        assertEquals(1_135L, v.bestPrice());
        assertEquals(1_129L, v.triggerTradePrice());
        assertEquals(1_127, ex.order(v.orderId()).orElseThrow().price(), "break price 1129 − spread 2");
        assertTrue(o.events().stream().anyMatch(e -> e instanceof Event.ConditionalTriggered));
    }

    @Test
    void ocoStopIsNotCheckedOnceTheTakeProfitArmed() {
        long id = run(new Command.PlaceConditional("alice", I, Conditional.Kind.TP_SL, SELL, 3, 900, 890, 1_100, 1_000, 0)).orderId();
        trade(1_000);
        trade(1_100); // TP armed; offset 1000 means it will not fire on any pull-back here
        assertEquals(ConditionalView.State.ARMED, state(id));

        trade(890); // below the stop: an un-armed TP_SL would have fired

        assertEquals(ConditionalView.State.ARMED, state(id));
    }

    @Test
    void ocoFiresItsStopWhenTheStopComesFirst() {
        long id = run(new Command.PlaceConditional("alice", I, Conditional.Kind.TP_SL, SELL, 3, 900, 0, 1_100, 5, 0)).orderId();
        trade(1_000);
        place("maker", BUY, 880, 10);

        trade(900);

        ConditionalView v = ex.conditional(id).orElseThrow();
        assertEquals(ConditionalView.State.FILLED, v.state(), "limit 0 = market stop leg");
    }

    @Test
    void stopsCascadeWithinOneCommand() {
        long first = stop(Conditional.Kind.STOP_MARKET, SELL, 5, 950, 0);
        long second = run(new Command.PlaceConditional("maker", I, Conditional.Kind.STOP_MARKET, SELL, 5, 0 + 920, 0, 0, 0, 0)).orderId();
        trade(1_000);
        place("taker", BUY, 940, 1);
        place("taker", BUY, 910, 20);

        trade(950); // fires the first; its market sell trades at 940 then 910, which fires the second

        assertEquals(ConditionalView.State.FILLED, state(first));
        assertEquals(ConditionalView.State.FILLED, state(second));
    }

    @Test
    void firedStopWithoutMoneyIsRejected() {
        run(new Command.OpenAccount("poor", "poor"));
        long id = run(new Command.PlaceConditional("poor", I, Conditional.Kind.STOP_MARKET, SELL, 5, 950, 0, 0, 0, 0)).orderId();
        trade(1_000);
        place("maker", BUY, 900, 10);

        trade(950);

        ConditionalView v = ex.conditional(id).orElseThrow();
        assertEquals(ConditionalView.State.REJECTED, v.state());
        assertEquals("INSUFFICIENT_FUNDS", v.rejection());
    }

    @Test
    void cancelledStopNeverFires() {
        long id = stop(Conditional.Kind.STOP_MARKET, SELL, 5, 950, 0);
        run(new Command.CancelConditional("alice", id));
        trade(900);
        assertEquals(ConditionalView.State.CANCELLED, state(id));
        assertEquals(Rejection.NOT_OPEN, ex.execute(new Command.CancelConditional("alice", id), ts).rejection());
    }

    @Test
    void ocoNeedsTheStopOnTheLosingSide() {
        Outcome o = ex.execute(new Command.PlaceConditional("alice", I, Conditional.Kind.TP_SL, SELL, 3, 1_200, 0, 1_100, 5, 0), ts);
        assertEquals(Rejection.INVALID_ORDER, o.rejection());
    }

    private long stop(Conditional.Kind kind, Order.Side side, long qty, long trigger, long limit) {
        return run(new Command.PlaceConditional("alice", I, kind, side, qty, trigger, limit, 0, 0, 0)).orderId();
    }

    private ConditionalView.State state(long id) {
        return ex.conditional(id).orElseThrow().state();
    }

    /** One trade of 1 SILK at {@code price} between the maker and the taker. */
    private Outcome trade(long price) {
        place("maker", SELL, price, 1);
        return place("taker", BUY, price, 1);
    }

    private Outcome place(String account, Order.Side side, long price, long qty) {
        return run(new Command.PlaceOrder(account, I, side, LIMIT, price, qty, null));
    }

    private Outcome run(Command c) {
        Outcome o = ex.execute(c, ++ts);
        assertTrue(o.accepted(), c + " → " + o.rejection());
        return o;
    }
}
