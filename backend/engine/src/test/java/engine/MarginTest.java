package engine;

import static engine.Order.Side.BUY;
import static engine.Order.Side.SELL;
import static engine.Order.Type.LIMIT;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/**
 * Leverage ×4 on the FX pair with stop-out at 50% of the collateral (intent 02, invariant 6; vault
 * finance/fx-market-kz.md). AMBER-SPARK: price 50 000 = 500.00 SPARK per AMBER, fee 5 bps.
 */
class MarginTest {

    private static final String FX = "AMBER-SPARK";
    private Exchange ex;
    private long ts;

    @BeforeEach
    void setUp() {
        ex = new Exchange(Instrument.ALL);
        run(new Command.Deposit(Ledger.BANK_ACCOUNT, "SPARK", 1_000_000_000));
        run(new Command.Deposit(Ledger.BANK_ACCOUNT, "AMBER", 1_000_000));
        for (String a : List.of("aika", "maker", "taker")) {
            run(new Command.OpenAccount(a, a));
            run(new Command.Deposit(a, "SPARK", 100_000_000));
            run(new Command.Deposit(a, "AMBER", 10_000));
        }
    }

    @Test
    void longTimesFourBorrowsThreeQuartersAndTheFeeComesFromCollateral() {
        place("maker", SELL, 50_000, 100);

        long id = run(new Command.OpenMargin("aika", FX, BUY, 100, 4)).orderId();

        MarginView p = ex.position(id).orElseThrow();
        assertEquals(1_250_000 + 2_500, p.collateral(), "5 000 000 / 4 + fee 5 bps");
        assertEquals(3_750_000, p.loanQuote());
        assertEquals(50_000, p.entryPrice());
        assertEquals(MarginView.Status.OPEN, p.status());
        assertEquals(100_000_000 - 1_252_500, ex.ledger().available("aika", "SPARK"));
        // 2·(0 − 3 750 000) + 2·100·price ≤ 1 252 500  ⇒  price ≤ 437.62
        assertEquals(43_762L, p.stopOutPrice());
    }

    @Test
    void stopOutClosesTheLongWhenEquityFallsToHalfTheCollateral() {
        place("maker", SELL, 50_000, 100);
        long id = run(new Command.OpenMargin("aika", FX, BUY, 100, 4)).orderId();
        long before = ex.ledger().available("aika", "SPARK");
        place("taker", BUY, 43_000, 200); // bids the stop-out will sell into

        trade(43_800); // above the stop-out price: still open
        assertEquals(MarginView.Status.OPEN, ex.position(id).orElseThrow().status());

        Outcome o = trade(43_762);

        MarginView p = ex.position(id).orElseThrow();
        assertEquals(MarginView.Status.CLOSED, p.status());
        assertEquals("STOP_OUT", p.closeReason());
        Event.MarginStopOut stopOut = (Event.MarginStopOut) o.events().stream()
                .filter(e -> e instanceof Event.MarginStopOut).findFirst().orElseThrow();
        assertTrue(2 * stopOut.equity() <= p.collateral());
        assertTrue(2 * stopOut.equity() > p.collateral() - 2 * 100, "fired at the first price that crossed half");
        // Sold at 430.00 (the bids), repaid 3 750 000, the rest came back.
        long proceeds = 43_000L * 100 - Instrument.AMBER_SPARK.fee(43_000L * 100);
        assertEquals(proceeds - 3_750_000, p.returned());
        assertEquals(before + p.returned(), ex.ledger().available("aika", "SPARK"));
        assertEquals(0, p.badDebt());
    }

    @Test
    void closingInProfitReturnsCollateralPlusGain() {
        place("maker", SELL, 50_000, 100);
        long id = run(new Command.OpenMargin("aika", FX, BUY, 100, 4)).orderId();
        place("taker", BUY, 51_000, 100);

        run(new Command.CloseMargin("aika", id));

        MarginView p = ex.position(id).orElseThrow();
        long proceeds = 51_000L * 100 - Instrument.AMBER_SPARK.fee(51_000L * 100);
        assertEquals(proceeds - 3_750_000, p.returned());
        assertTrue(p.returned() - p.collateral() > 0, "+2% price × 4 ≈ +8% on collateral, minus fees");
    }

    @Test
    void shortIsStoppedOutWhenThePriceRises() {
        place("taker", BUY, 50_000, 100);
        long id = run(new Command.OpenMargin("aika", FX, SELL, 100, 4)).orderId();
        MarginView open = ex.position(id).orElseThrow();
        assertEquals(100, open.loanBase());
        assertEquals(1_250_000, open.collateral());
        assertNotNull(open.stopOutPrice());
        place("maker", SELL, 57_000, 200);

        trade(open.stopOutPrice() - 10);
        assertEquals(MarginView.Status.OPEN, ex.position(id).orElseThrow().status());
        trade(open.stopOutPrice());

        MarginView p = ex.position(id).orElseThrow();
        assertEquals(MarginView.Status.CLOSED, p.status());
        assertEquals("STOP_OUT", p.closeReason());
        assertEquals(0, ex.ledger().available(Accounts.marginAccount("aika", id), "AMBER"));
    }

    @Test
    void aGapThroughTheStopOutLeavesBadDebtWithTheBankNotNewMoney() {
        place("maker", SELL, 50_000, 100);
        long id = run(new Command.OpenMargin("aika", FX, BUY, 100, 4)).orderId();
        place("taker", BUY, 30_000, 100); // the only bids are far below

        trade(43_000);

        MarginView p = ex.position(id).orElseThrow();
        assertEquals(MarginView.Status.CLOSED, p.status());
        assertEquals(0, p.returned());
        assertTrue(p.badDebt() > 0);
    }

    @Test
    void stockHasNoLeverage() {
        place("maker", SELL, 50_000, 100);
        assertEquals(Rejection.LEVERAGE_NOT_ALLOWED, ex.execute(new Command.OpenMargin("aika", "SILK-SPARK", BUY, 1, 2), ++ts).rejection());
        assertEquals(Rejection.LEVERAGE_NOT_ALLOWED, ex.execute(new Command.OpenMargin("aika", FX, BUY, 1, 5), ++ts).rejection());
    }

    @Test
    void thinBookIsRefused() {
        place("maker", SELL, 50_000, 10);
        assertEquals(Rejection.NO_LIQUIDITY, ex.execute(new Command.OpenMargin("aika", FX, BUY, 11, 4), ++ts).rejection());
    }

    /** One trade of 1 AMBER at {@code price} between the maker and the taker. */
    private Outcome trade(long price) {
        place("maker", SELL, price, 1);
        return place("taker", BUY, price, 1);
    }

    private Outcome place(String account, Order.Side side, long price, long qty) {
        return run(new Command.PlaceOrder(account, FX, side, LIMIT, price, qty, null));
    }

    private Outcome run(Command c) {
        Outcome o = ex.execute(c, ++ts);
        assertTrue(o.accepted(), c + " → " + o.rejection());
        return o;
    }
}
