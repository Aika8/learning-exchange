package engine.mutation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Balance;
import engine.Ledger;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Every ledger movement refuses a non-positive amount, so money is never created by a sign slip (LE-019). */
class LedgerAmountsTest {

    private final Ledger ledger = new Ledger();

    @BeforeEach
    void twoAccountsWithMoney() {
        ledger.open("a");
        ledger.open("b");
        ledger.deposit("a", "SPARK", 1_000);
        ledger.reserve("a", "SPARK", 300);
    }

    @Test
    void aZeroDepositIsRefused() {
        assertThrows(IllegalArgumentException.class, () -> ledger.deposit("a", "SPARK", 0));
        assertEquals(700, ledger.available("a", "SPARK"));
    }

    @Test
    void aZeroReservationIsRefused() {
        assertThrows(IllegalArgumentException.class, () -> ledger.reserve("a", "SPARK", 0));
    }

    @Test
    void aNegativeReleaseIsRefused() {
        assertThrows(IllegalArgumentException.class, () -> ledger.release("a", "SPARK", -5));
        assertEquals(300, ledger.reserved("a", "SPARK"));
    }

    @Test
    void aNegativeSettlementIsRefused() {
        assertThrows(IllegalArgumentException.class, () -> ledger.settleFromReserved("a", "b", "SPARK", -5));
        assertEquals(0, ledger.available("b", "SPARK"));
    }

    @Test
    void aNegativeTransferIsRefused() {
        assertThrows(IllegalArgumentException.class, () -> ledger.transferAvailable("a", "b", "SPARK", -5));
        assertEquals(0, ledger.available("b", "SPARK"));
    }

    @Test
    void balancesListEveryAssetOfAnAccount() {
        ledger.deposit("a", "AMBER", 7);
        List<Balance> balances = ledger.balances("a");
        assertEquals(List.of(new Balance("AMBER", 7, 0), new Balance("SPARK", 700, 300)), balances);
        assertTrue(ledger.balances("nobody").isEmpty());
    }
}
