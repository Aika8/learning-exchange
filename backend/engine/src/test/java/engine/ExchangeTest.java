package engine;

import static engine.Order.Side.BUY;
import static engine.Order.Side.SELL;
import static engine.Order.Type.LIMIT;
import static engine.Order.Type.MARKET;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Accounts, reservation and fees on SILK-SPARK (fee 10 bps on each side). */
class ExchangeTest {

    private static final String I = "SILK-SPARK";
    private Exchange ex;

    @BeforeEach
    void setUp() {
        ex = new Exchange(List.of(Instrument.SILK_SPARK));
        open("alice", 1_000_000, 0);
        open("bob", 0, 100);
    }

    @Test
    void limitBuyReservesNotionalPlusFee() {
        Outcome o = place("alice", BUY, LIMIT, 1_000, 10);

        assertTrue(o.accepted());
        assertEquals(10_010, ex.ledger().reserved("alice", "SPARK"));
        assertEquals(1_000_000 - 10_010, ex.ledger().available("alice", "SPARK"));
    }

    @Test
    void insufficientFundsIsRejectedAndChangesNothing() {
        Outcome o = place("bob", SELL, LIMIT, 1_000, 101);

        assertEquals(Rejection.INSUFFICIENT_FUNDS, o.rejection());
        assertEquals(100, ex.ledger().available("bob", "SILK"));
        assertTrue(ex.ordersOf("bob", false, 10).isEmpty());
    }

    @Test
    void tradeMovesGoodsAndMoneyAndChargesBothFees() {
        place("bob", SELL, LIMIT, 1_000, 10);
        Outcome buy = place("alice", BUY, LIMIT, 1_000, 10);

        Event.TradeExecuted t = (Event.TradeExecuted) buy.events().get(1);
        assertEquals(10, t.buyerFee());
        assertEquals(10, t.sellerFee());
        assertEquals(10, ex.ledger().available("alice", "SILK"));
        assertEquals(1_000_000 - 10_010, ex.ledger().available("alice", "SPARK"));
        assertEquals(0, ex.ledger().reserved("alice", "SPARK"));
        assertEquals(9_990, ex.ledger().available("bob", "SPARK"));
        assertEquals(90, ex.ledger().available("bob", "SILK"));
        assertEquals(20, ex.ledger().available(Ledger.FEES_ACCOUNT, "SPARK"));
    }

    @Test
    void buyFilledBelowItsLimitGetsTheDifferenceBack() {
        place("bob", SELL, LIMIT, 900, 10);
        place("alice", BUY, LIMIT, 1_000, 10);

        // paid 9 000 + fee 9; reserved 10 000 + 10 was released in full.
        assertEquals(1_000_000 - 9_009, ex.ledger().available("alice", "SPARK"));
        assertEquals(0, ex.ledger().reserved("alice", "SPARK"));
    }

    @Test
    void cancelReleasesTheRestOfTheReservation() {
        place("bob", SELL, LIMIT, 1_000, 4);
        Outcome buy = place("alice", BUY, LIMIT, 1_000, 10);
        Outcome cancel = ex.execute(new Command.CancelOrder("alice", buy.orderId()), 2);

        assertTrue(cancel.accepted());
        assertEquals(new Event.OrderCancelled(2, buy.orderId(), "alice", 6), cancel.events().getFirst());
        assertEquals(0, ex.ledger().reserved("alice", "SPARK"));
        assertEquals(1_000_000 - 4_004, ex.ledger().available("alice", "SPARK"));
        assertEquals(OrderView.Status.CANCELLED, ex.order(buy.orderId()).orElseThrow().status());
    }

    @Test
    void onlyTheOwnerCancels() {
        Outcome sell = place("bob", SELL, LIMIT, 1_000, 4);

        assertEquals(Rejection.NOT_OWNER, ex.execute(new Command.CancelOrder("alice", sell.orderId()), 2).rejection());
        assertEquals(Rejection.UNKNOWN_ORDER, ex.execute(new Command.CancelOrder("bob", 999), 2).rejection());
    }

    @Test
    void marketBuyReservesTheWalkedCostAndExpiresTheRemainder() {
        place("bob", SELL, LIMIT, 1_000, 3);
        place("bob", SELL, LIMIT, 1_100, 2);
        Outcome buy = place("alice", MARKET, 0, 10);

        assertEquals(5, ex.order(buy.orderId()).orElseThrow().filledQty());
        assertEquals(OrderView.Status.EXPIRED, ex.order(buy.orderId()).orElseThrow().status());
        assertTrue(buy.events().getLast() instanceof Event.OrderExpired);
        assertEquals(0, ex.ledger().reserved("alice", "SPARK"));
        assertEquals(1_000_000 - 5_200 - 3 - 2, ex.ledger().available("alice", "SPARK"));
    }

    @Test
    void marketOrderIntoAnEmptySideIsRejected() {
        assertEquals(Rejection.NO_LIQUIDITY, place("alice", MARKET, 0, 1).rejection());
    }

    @Test
    void sameIdempotencyKeyReturnsTheFirstOrder() {
        Outcome first = ex.execute(new Command.PlaceOrder("alice", I, BUY, LIMIT, 1_000, 1, "k1"), 1);
        Outcome again = ex.execute(new Command.PlaceOrder("alice", I, BUY, LIMIT, 1_000, 1, "k1"), 2);

        assertEquals(first.orderId(), again.orderId());
        assertTrue(again.events().isEmpty());
        assertEquals(1, ex.ordersOf("alice", false, 10).size());
    }

    @Test
    void ordersOfListsNewestFirstAndOpenOnlyDropsClosedOrders() {
        long a = place("alice", BUY, LIMIT, 1_000, 1).orderId();
        long b = place("alice", BUY, LIMIT, 1_001, 1).orderId();
        long c = place("alice", BUY, LIMIT, 1_002, 1).orderId();
        ex.execute(new Command.CancelOrder("alice", b), 10);

        assertEquals(List.of(c, a), ex.ordersOf("alice", true, 10).stream().map(OrderView::orderId).toList());
        assertEquals(List.of(c, b, a), ex.ordersOf("alice", false, 10).stream().map(OrderView::orderId).toList());
        assertEquals(List.of(c), ex.ordersOf("alice", false, 1).stream().map(OrderView::orderId).toList());
        assertEquals(ex.ledger().reserved("alice", "SPARK"), ex.reservedByOpenOrders("alice", "SPARK"));
        assertTrue(ex.ordersOf("nobody", true, 10).isEmpty());
    }

    @Test
    void unknownAccountAndInvalidOrdersAreRejected() {
        assertEquals(Rejection.UNKNOWN_ACCOUNT, place("nobody", BUY, LIMIT, 1, 1).rejection());
        assertEquals(Rejection.INVALID_ORDER, place("alice", BUY, LIMIT, 0, 1).rejection());
        assertEquals(Rejection.INVALID_ORDER, place("alice", BUY, LIMIT, 1, -1).rejection());
        assertFalse(ex.execute(new Command.OpenAccount("alice", "A"), 1).accepted());
    }

    private void open(String account, long spark, long silk) {
        ex.execute(new Command.OpenAccount(account, account), 0);
        if (spark > 0) {
            ex.execute(new Command.Deposit(account, "SPARK", spark), 0);
        }
        if (silk > 0) {
            ex.execute(new Command.Deposit(account, "SILK", silk), 0);
        }
    }

    private Outcome place(String account, Order.Side side, Order.Type type, long price, long qty) {
        return ex.execute(new Command.PlaceOrder(account, I, side, type, price, qty, null), 1);
    }

    private Outcome place(String account, Order.Type type, long price, long qty) {
        return place(account, BUY, type, price, qty);
    }
}
