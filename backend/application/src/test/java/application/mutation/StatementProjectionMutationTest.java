package application.mutation;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.StatementProjection;
import application.StatementProjection.Kind;
import application.StatementProjection.Line;
import application.StatementProjection.Statement;
import engine.Event;
import engine.Instrument;
import engine.Ledger;
import engine.Order;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** Statement read model fed with events directly: each test pins one rule of the statement (LE-020). */
class StatementProjectionMutationTest {

    private static final String ME = "acc-me";
    private static final String MM = "acc-mm";
    private static final String SILK = "SILK-SPARK";
    /** An instrument whose quote is not SPARK, so the quote of a line is visibly looked up. */
    private static final Instrument OAK_ROPE = new Instrument("OAK-ROPE", "OAK", "ROPE", 10);

    private final StatementProjection p = new StatementProjection(List.of(Instrument.SILK_SPARK, OAK_ROPE));

    private void feed(Event... events) {
        p.onEvents(List.of(events));
    }

    private List<Line> lines(String owner) {
        return p.statement(owner, 0, Long.MAX_VALUE).lines();
    }

    private Line only(String owner, Kind kind) {
        List<Line> found = lines(owner).stream().filter(l -> l.kind() == kind).toList();
        assertEquals(1, found.size(), kind + " lines: " + found);
        return found.get(0);
    }

    private static Event.TradeExecuted trade(long ts, String instrument, String buyer, String seller, long price, long qty,
                                             long buyerFee, long sellerFee, long mid) {
        return new Event.TradeExecuted(ts, ts, instrument, 1, 2, buyer, seller, price, qty, Order.Side.BUY, buyerFee,
                sellerFee, mid);
    }

    @Test
    void aMarginPositionShowsCollateralOutAndTheCloseShowsProfitOverIt() {
        feed(new Event.MarginPositionOpened(1, 7, ME, "OAK-ROPE", Order.Side.BUY, 10, 4, 1_000, 3_000, 0, "k"),
                new Event.MarginStopOut(2, 7, ME, 90, 100, 1_000),
                new Event.MarginPositionClosed(3, 7, ME, "stop-out", 1_300, 0, 0, 0));
        Line open = only(ME, Kind.MARGIN_OPEN);
        assertEquals(-1_000, open.amount());
        assertEquals("ROPE", open.asset());
        assertTrue(open.margin());
        Line stop = only(ME, Kind.STOP_OUT);
        assertEquals(90L, stop.price());
        assertEquals("OAK-ROPE", stop.instrument());
        Line close = only(ME, Kind.MARGIN_CLOSE);
        assertEquals(1_300, close.amount());
        assertEquals(300, close.realisedPnl(), "returned 1300 − collateral 1000");
        assertEquals("ROPE", close.asset());
    }

    @Test
    void aStopOutOfAnUnknownPositionIsQuotedInSpark() {
        feed(new Event.MarginStopOut(2, 99, ME, 90, 100, 1_000));
        Line stop = only(ME, Kind.STOP_OUT);
        assertNull(stop.instrument());
        assertEquals("SPARK", stop.asset());
    }

    @Test
    void savingsShowMoneyOutOnOpenAndThePayoutOnClose() {
        feed(new Event.FundsDeposited(0, ME, "SPARK", 1_000),
                new Event.SavingsOpened(1, 3, ME, "SPARK", 5_000, 500, 60_000, "k"),
                new Event.InterestAccrued(2, 3, ME, 25, 1, 5_025),
                new Event.SavingsClosed(3, 3, ME, 5_025));
        assertEquals(-5_000, only(ME, Kind.SAVINGS_OPEN).amount());
        assertEquals(5_025, only(ME, Kind.SAVINGS_CLOSE).amount());
        assertEquals(25, p.statement(ME, 0, Long.MAX_VALUE).totals().interest(), "only the interest line counts");
    }

    @Test
    void aDividendTaxedAtSourceShowsGrossAndTaxAndIsNotTaxedTwice() {
        feed(new Event.DividendPaid(1, "OAK-ROPE", ME, 10, 2_000, 200));
        Line gross = only(ME, Kind.DIVIDEND);
        assertEquals(2_000, gross.amount());
        assertEquals("ROPE", gross.asset());
        assertEquals(-200, only(ME, Kind.DIVIDEND_TAX).amount());
        StatementProjection.Totals t = p.statement(ME, 0, Long.MAX_VALUE).totals();
        assertEquals(2_000, t.payouts());
        assertEquals(200, t.taxWithheld());
        assertEquals(0, t.tax(), "10% of 2000 already withheld");
    }

    @Test
    void anUntaxedDividendHasNoTaxLineAndIsTaxedInTheStatement() {
        feed(new Event.DividendPaid(1, SILK, ME, 10, 2_000, 0));
        assertEquals(List.of(Kind.DIVIDEND), lines(ME).stream().map(Line::kind).toList());
        assertEquals(200, p.statement(ME, 0, Long.MAX_VALUE).totals().tax());
    }

    @Test
    void dividendsToSubAccountsAndExchangeAccountsAreNotOnAnyStatement() {
        feed(new Event.DividendPaid(1, SILK, ME + "~m1", 10, 2_000, 200),
                new Event.DividendPaid(1, SILK, Ledger.FEES_ACCOUNT, 10, 2_000, 200));
        assertTrue(lines(ME).isEmpty());
        assertTrue(lines(Ledger.FEES_ACCOUNT).isEmpty());
    }

    @Test
    void couponsAndPayoutDividendsAreIncomeLines() {
        feed(new Event.PayoutPaid(1, SILK, Event.PayoutKind.COUPON, ME, 10, 150),
                new Event.PayoutPaid(2, SILK, Event.PayoutKind.DIVIDEND, ME, 10, 50));
        assertEquals(150, only(ME, Kind.COUPON).amount());
        assertEquals(50, only(ME, Kind.DIVIDEND).amount());
        assertEquals(200, p.statement(ME, 0, Long.MAX_VALUE).totals().payouts());
    }

    @Test
    void payoutsToSubAccountsAndExchangeAccountsAreNotOnAnyStatement() {
        feed(new Event.PayoutPaid(1, SILK, Event.PayoutKind.COUPON, ME + "~m1", 10, 150),
                new Event.PayoutPaid(1, SILK, Event.PayoutKind.COUPON, Ledger.BANK_ACCOUNT, 10, 150));
        assertTrue(lines(ME).isEmpty());
        assertTrue(lines(Ledger.BANK_ACCOUNT).isEmpty());
    }

    @Test
    void aRedemptionSellsTheBondsBackAtThePerUnitPriceAndRealisesAgainstTheCost() {
        feed(trade(1, SILK, ME, MM, 90, 10, 0, 0, 0),
                new Event.PayoutPaid(2, SILK, Event.PayoutKind.REDEMPTION, ME, 10, 1_000));
        Line r = only(ME, Kind.REDEMPTION);
        assertEquals(100L, r.price(), "1000 / 10 units");
        assertEquals(1_000, r.amount());
        assertEquals(100, r.realisedPnl(), "1000 − cost 900");
    }

    @Test
    void aRedemptionOfNoUnitsHasPriceZero() {
        feed(new Event.PayoutPaid(2, SILK, Event.PayoutKind.REDEMPTION, ME, 0, 0));
        assertEquals(0L, only(ME, Kind.REDEMPTION).price());
    }

    @Test
    void aBaseAssetDepositedAfterATradeEntersTheBasisAtTheLastPrice() {
        feed(trade(1, SILK, MM, "acc-x", 100, 1, 0, 0, 0),
                new Event.FundsDeposited(2, ME, "SILK", 10),
                trade(3, SILK, MM, ME, 120, 10, 0, 0, 0));
        assertEquals(200, only(ME, Kind.TRADE).realisedPnl(), "1200 − 10 × 100");
    }

    @Test
    void baseAssetsDepositedBeforeAnyTradeEnterTheBasisAtTheFirstPrice() {
        feed(new Event.FundsDeposited(1, ME, "SILK", 10),
                new Event.FundsDeposited(1, "acc-you", "SILK", 5),
                trade(2, SILK, MM, "acc-x", 100, 1, 0, 0, 0),
                trade(3, SILK, MM, ME, 120, 10, 0, 0, 0),
                trade(4, SILK, MM, "acc-you", 120, 5, 0, 0, 0));
        assertEquals(200, only(ME, Kind.TRADE).realisedPnl(), "1200 − 10 × 100");
        assertEquals(100, only("acc-you", Kind.TRADE).realisedPnl(), "600 − 5 × 100");
    }

    @Test
    void theBuyerPaysNotionalPlusFeeAndTheSellerGetsNotionalMinusFeeWithSpreadAgainstTheMid() {
        feed(trade(1, SILK, ME, MM, 101, 10, 3, 2, 100));
        Line buy = only(ME, Kind.TRADE);
        assertEquals(-1_013, buy.amount());
        assertEquals(10, buy.spreadPaid(), "(101 − 100) × 10");
        Line sell = only(MM, Kind.TRADE);
        assertEquals(1_008, sell.amount());
        assertEquals(100L, sell.mid());
        assertEquals(-10, sell.spreadPaid(), "(100 − 101) × 10: the seller got more than the mid");
        assertEquals(5, p.statement(ME, 0, Long.MAX_VALUE).totals().fees() + p.statement(MM, 0, Long.MAX_VALUE).totals().fees());
    }

    @Test
    void aTradeWithoutAMidHasNoMidAndNoSpread() {
        feed(trade(1, SILK, ME, MM, 101, 10, 0, 0, 0));
        assertNull(only(ME, Kind.TRADE).mid());
        assertNull(only(MM, Kind.TRADE).mid());
        assertEquals(0, only(MM, Kind.TRADE).spreadPaid());
    }

    @Test
    void theSpreadTotalSumsTheLines() {
        feed(trade(1, SILK, ME, MM, 101, 10, 0, 0, 100), trade(2, SILK, ME, MM, 102, 10, 0, 0, 100));
        assertEquals(30, p.statement(ME, 0, Long.MAX_VALUE).totals().spreadPaid());
    }

    @Test
    void marginTradesRealiseNothingAndLeaveTheOwnBasisAlone() {
        feed(trade(1, SILK, ME, MM, 100, 10, 0, 0, 0),
                trade(2, SILK, ME + "~m1", MM, 50, 10, 0, 0, 0),
                trade(3, SILK, MM, ME + "~m1", 200, 10, 0, 0, 0),
                trade(4, SILK, MM, ME, 120, 10, 0, 0, 0));
        List<Line> trades = lines(ME);
        assertTrue(trades.get(1).margin());
        assertEquals(0, trades.get(2).realisedPnl(), "a margin sell realises nothing here");
        assertTrue(trades.get(2).margin());
        assertFalse(trades.get(3).margin());
        assertEquals(200, trades.get(3).realisedPnl(), "1200 − 10 × 100: the margin buy at 50 is not in the basis");
    }

    @Test
    void averageCostCarriesTheRestOfTheBasisToTheNextSale() {
        feed(trade(1, SILK, ME, MM, 100, 10, 0, 0, 0),
                trade(2, SILK, MM, ME, 110, 5, 0, 0, 0),
                trade(3, SILK, MM, ME, 110, 5, 0, 0, 0));
        List<Line> l = lines(ME);
        assertEquals(50, l.get(1).realisedPnl());
        assertEquals(50, l.get(2).realisedPnl());
    }

    @Test
    void sellingMoreThanTheBasisHoldsRealisesNothingOnceItIsEmpty() {
        feed(trade(1, SILK, ME, MM, 100, 10, 0, 0, 0),
                trade(2, SILK, MM, ME, 110, 10, 0, 0, 0),
                trade(3, SILK, MM, ME, 110, 10, 0, 0, 0));
        assertEquals(0, lines(ME).get(2).realisedPnl());
    }

    @Test
    void thePeriodIncludesItsStartAndExcludesItsEnd() {
        feed(new Event.FundsDeposited(10, ME, "SPARK", 1), new Event.FundsDeposited(20, ME, "SPARK", 2));
        Statement s = p.statement(ME, 10, 20);
        assertEquals(List.of(10L), s.lines().stream().map(Line::ts).toList());
    }

    @Test
    void depositsToExchangeAccountsAreNotOnAnyStatement() {
        feed(new Event.FundsDeposited(1, Ledger.TAX_ACCOUNT, "SPARK", 1));
        assertTrue(lines(Ledger.TAX_ACCOUNT).isEmpty());
    }

    @Test
    void theStatementKeepsExactlyTheNewestLines() {
        List<Event> many = new ArrayList<>();
        int kept = 20_000;
        for (int i = 0; i <= kept; i++) {
            many.add(new Event.FundsDeposited(i, ME, "SPARK", 1));
        }
        p.onEvents(many);
        List<Line> l = lines(ME);
        assertEquals(kept, l.size());
        assertEquals(1L, l.get(0).ts(), "the oldest one dropped out");
    }
}
