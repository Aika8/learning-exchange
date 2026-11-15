package application;

import static engine.Order.Side.BUY;
import static engine.Order.Side.SELL;
import static engine.Order.Type.LIMIT;
import static engine.Order.Type.MARKET;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Instrument;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** The statement projection: fee and spread on every trade, average-cost profit, 10% tax, rebuilt on restart. */
class StatementProjectionTest {

    private static final Map<String, Long> START = Map.of("SPARK", 10_000_000L);

    @Test
    void tradeLinesShowFeeAndSpreadAgainstTheMidAndTaxIsTenPercentOfRealisedProfit() throws Exception {
        InMemoryJournal journal = new InMemoryJournal();
        ManualClock clock = new ManualClock(1_000);
        try (ExchangeService s = new ExchangeService(Instrument.ALL, journal, clock, START)) {
            String me = s.login("me").accountId();
            String mm = s.login("mm").accountId();
            s.deposit(mm, "SILK", 100);
            // Book: 99.00 / 101.00, mid 100.00.
            s.place(mm, "SILK-SPARK", BUY, LIMIT, 9_900, 10, null);
            s.place(mm, "SILK-SPARK", SELL, LIMIT, 10_100, 10, null);

            s.place(me, "SILK-SPARK", BUY, MARKET, 0, 10, null); // pays 1.00 over mid on each of 10
            clock.advance(1_000);
            s.place(mm, "SILK-SPARK", BUY, LIMIT, 11_000, 10, null); // the price went up
            s.place(me, "SILK-SPARK", SELL, MARKET, 0, 10, null);

            StatementProjection.Statement st = s.statement(me, 0, Long.MAX_VALUE);
            StatementProjection.Line buy = st.lines().stream().filter(l -> l.side() == BUY).findFirst().orElseThrow();
            assertEquals(10_000L, buy.mid());
            assertEquals(1_000, buy.spreadPaid(), "(101.00 − 100.00) × 10");
            assertEquals(101, buy.fee(), "10 bps of 1010.00, rounded down");
            StatementProjection.Line sell = st.lines().stream().filter(l -> l.side() == SELL).findFirst().orElseThrow();
            long proceeds = 110_000 - 110;
            assertEquals(proceeds - (101_000 + 101), sell.realisedPnl());
            assertEquals(sell.realisedPnl(), st.totals().realisedPnl());
            assertEquals(st.totals().realisedPnl() / 10, st.totals().tax());
            assertEquals(101 + 110, st.totals().fees());
        }
    }

    @Test
    void aLossMeansNoTaxAndThePeriodFilterApplies() throws Exception {
        ManualClock clock = new ManualClock(1_000);
        try (ExchangeService s = new ExchangeService(Instrument.ALL, new InMemoryJournal(), clock, START)) {
            String me = s.login("me").accountId();
            String mm = s.login("mm").accountId();
            s.deposit(mm, "SILK", 100);
            s.place(mm, "SILK-SPARK", SELL, LIMIT, 10_000, 10, null);
            s.place(me, "SILK-SPARK", BUY, MARKET, 0, 10, null);
            clock.advance(10_000);
            s.place(mm, "SILK-SPARK", BUY, LIMIT, 9_000, 10, null);
            s.place(me, "SILK-SPARK", SELL, MARKET, 0, 10, null);

            StatementProjection.Statement all = s.statement(me, 0, Long.MAX_VALUE);
            assertTrue(all.totals().realisedPnl() < 0);
            assertEquals(0, all.totals().tax());
            assertEquals(1, s.statement(me, 5_000, Long.MAX_VALUE).lines().size(), "only the sell is in the period");
        }
    }

    @Test
    void theStatementIsRebuiltFromTheJournalOnRestart() throws Exception {
        InMemoryJournal journal = new InMemoryJournal();
        ManualClock clock = new ManualClock(1_000);
        StatementProjection.Statement before;
        try (ExchangeService s = new ExchangeService(Instrument.ALL, journal, clock, START)) {
            String me = s.login("me").accountId();
            String mm = s.login("mm").accountId();
            s.deposit(mm, "AMBER", 1_000);
            s.place(mm, "AMBER-SPARK", SELL, LIMIT, 50_000, 100, null);
            s.openMargin(me, "AMBER-SPARK", BUY, 10, 4);
            s.openSavings(me, 1_000_000);
            clock.advance(5 * 60_000);
            s.accrueInterest();
            before = s.statement(me, 0, Long.MAX_VALUE);
        }
        try (ExchangeService again = new ExchangeService(Instrument.ALL, journal, clock, START)) {
            assertEquals(before, again.statement("acc-me", 0, Long.MAX_VALUE));
            List<StatementProjection.Kind> kinds = before.lines().stream().map(StatementProjection.Line::kind).distinct().toList();
            assertTrue(kinds.containsAll(List.of(StatementProjection.Kind.DEPOSIT, StatementProjection.Kind.MARGIN_OPEN,
                    StatementProjection.Kind.TRADE, StatementProjection.Kind.SAVINGS_OPEN, StatementProjection.Kind.INTEREST)), kinds.toString());
            assertTrue(before.totals().interest() > 0);
        }
    }
}
