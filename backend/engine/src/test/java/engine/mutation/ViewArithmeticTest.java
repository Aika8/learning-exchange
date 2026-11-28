package engine.mutation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Accounts;
import engine.Balance;
import engine.Order;
import engine.OrderView;
import engine.SavingsView;
import org.junit.jupiter.api.Test;

/** The small sums the read views and order parameters compute (LE-019). */
class ViewArithmeticTest {

    @Test
    void aBalanceTotalIsAvailablePlusReserved() {
        assertEquals(130, new Balance("SPARK", 100, 30).total());
    }

    @Test
    void savingsInterestIsBalanceMinusPrincipal() {
        assertEquals(25, new SavingsView(1, "acc~s1", "SPARK", 1_000, 1_025, 250, true, 0, null).interest());
    }

    private static OrderView order(OrderView.Status status) {
        return new OrderView(1, "acc", "SILK-SPARK", Order.Side.BUY, Order.Type.LIMIT, 100, 10, 4, status, 0);
    }

    @Test
    void remainingQuantityIsWhatIsNotFilledYet() {
        assertEquals(6, order(OrderView.Status.PARTIALLY_FILLED).remainingQty());
    }

    @Test
    void onlyNewAndPartlyFilledOrdersAreOpen() {
        assertTrue(order(OrderView.Status.NEW).open());
        assertTrue(order(OrderView.Status.PARTIALLY_FILLED).open());
        assertFalse(order(OrderView.Status.FILLED).open());
        assertFalse(order(OrderView.Status.CANCELLED).open());
        assertFalse(order(OrderView.Status.EXPIRED).open());
    }

    @Test
    void theOwnerOfASubAccountIsTheNameBeforeTheSeparator() {
        assertEquals("acc-aika", Accounts.owner(Accounts.marginAccount("acc-aika", 3)));
        assertEquals("acc-aika", Accounts.owner(Accounts.savingsAccount("acc-aika", 1)));
        assertEquals("acc-aika", Accounts.owner("acc-aika"));
    }

    @Test
    void aMarketOrderNeedsASideAndAPositiveQuantity() {
        assertThrows(IllegalArgumentException.class, () -> Order.market(null, 1));
        assertThrows(IllegalArgumentException.class, () -> Order.market(Order.Side.BUY, 0));
        assertThrows(IllegalArgumentException.class, () -> Order.limit(Order.Side.BUY, 100, 0));
        assertEquals(Order.Type.MARKET, Order.market(Order.Side.SELL, 1).type());
        assertEquals(Order.Type.LIMIT, Order.limit(Order.Side.SELL, 100, 1).type());
    }
}
