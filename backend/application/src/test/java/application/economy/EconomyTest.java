package application.economy;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.ExchangeService;
import application.InMemoryJournal;
import application.ManualClock;
import engine.Event;
import engine.Instrument;
import engine.Order;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.constraints.IntRange;
import org.junit.jupiter.api.Test;

/** M2b economy: schedule determinism, reports at night, rate decisions, coupons and default, bond maths, restart. */
class EconomyTest {

    private static final long DAY = 60_000;
    private static final long YEAR = EconomySchedule.YEAR_DAYS * DAY;

    @Property(tries = 50)
    void theScheduleIsTheSameWhicheverWayTheWindowIsCut(@ForAll long seed, @ForAll @IntRange(min = 1, max = 200) int cuts) {
        EconomySchedule whole = new EconomySchedule(seed, 1_000, DAY);
        EconomySchedule parts = new EconomySchedule(seed, 1_000, DAY);
        List<EconomySchedule.Item> joined = new ArrayList<>();
        long step = 2 * YEAR / cuts;
        for (long t = 0; t < 2 * YEAR; t += step) {
            joined.addAll(parts.between(t, Math.min(2 * YEAR, t + step)));
        }
        assertEquals(whole.between(0, 2 * YEAR).stream().filter(i -> i.at() > step * 0).toList().size(),
                joined.size() + whole.between(0, 0).size());
        assertEquals(whole.between(0, 2 * YEAR).toString(), joined.toString());
    }

    @Test
    void eightRateDecisionsAYearAndReportsComeOutWhileTheStockIsHalted() {
        List<EconomySchedule.Item> year = new EconomySchedule(7, 0, DAY).between(0, YEAR);
        assertEquals(8, year.stream().filter(i -> i.kind().equals("RATE_DECISION")).count());
        for (EconomySchedule.Item i : year) {
            if (i.kind().equals("EARNINGS")) {
                long haltedAt = year.stream().filter(h -> h instanceof EconomySchedule.TradingStatus t && !t.open()
                        && i.instrument().equals(t.instrument()) && h.at() < i.at()).mapToLong(EconomySchedule.Item::at).max().orElseThrow();
                long reopen = year.stream().filter(h -> h instanceof EconomySchedule.TradingStatus t && t.open()
                        && i.instrument().equals(t.instrument()) && h.at() > i.at()).mapToLong(EconomySchedule.Item::at).min().orElseThrow();
                assertTrue(haltedAt < i.at() && i.at() < reopen);
                long consensusAt = year.stream().filter(c -> c.kind().equals("CONSENSUS") && i.instrument().equals(c.instrument())
                        && c.at() < i.at()).mapToLong(EconomySchedule.Item::at).max().orElseThrow();
                assertTrue(i.at() - consensusAt >= 4 * DAY, "consensus comes days before the report");
            }
        }
    }

    @Test
    void bondMathsAgree() {
        // at a yield equal to its coupon a bond is worth its face value
        assertEquals(100_000, BondMath.price(100_000, 3_250, 4, 12, 1_300), 2);
        long p = BondMath.price(100_000, 3_250, 4, 12, 1_800);
        assertTrue(p < 100_000, "higher yield, lower price");
        assertEquals(1_800, BondMath.yieldToMaturity(p, 100_000, 3_250, 4, 12), 1);
        long d12 = BondMath.modifiedDurationX100(100_000, 3_250, 4, 12, 1_300);
        long d4 = BondMath.modifiedDurationX100(100_000, 3_250, 4, 4, 1_300);
        assertTrue(d12 > d4 && d12 < 300, "longer bonds have longer duration, below their maturity: " + d12);
    }

    private static Map<String, Long> start() {
        return Map.of("SPARK", 10_000_000L, "FORGE", 10L, "SILK", 10L, "HBND", 5L, "GBND", 5L);
    }

    @Test
    void aYearOfEconomyConservesMoneyDefaultsTheWeakIssuerAndSurvivesARestart() throws Exception {
        InMemoryJournal journal = new InMemoryJournal();
        ManualClock clock = new ManualClock(1_000_000);
        // GBND issuer cash: three coupons for the float of 3 people × 5 bonds, then default on the fourth
        long coupon = Securities.bond("GBND-SPARK").orElseThrow().couponPerUnit();
        Map<String, Long> issuers = Map.of("issuer-silk", 1_000_000_000L, "issuer-forge", 1_000_000_000L,
                "issuer-hbnd", 1_000_000_000L, "issuer-gbnd", 3 * 15 * coupon + 100);
        ExchangeService.Options opts = new ExchangeService.Options(ExchangeService.Options.DEFAULT.bankCapital(),
                ExchangeService.Options.DEFAULT.savings(), 11, issuers, application.realworld.RealMarketData.NONE);
        String before;
        try (ExchangeService s = new ExchangeService(Instrument.ALL, journal, clock, start(), opts)) {
            for (String p : List.of("a", "b", "c")) {
                s.login(p);
            }
            s.place("acc-a", "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 10_000, 1, null);
            s.place("acc-b", "SILK-SPARK", Order.Side.BUY, Order.Type.MARKET, 0, 1, null);
            long start = s.savingsProduct().rateBps();
            for (int d = 0; d < 400; d++) {
                clock.advance(DAY);
                s.runEconomy();
            }
            var macro = s.macro();
            assertEquals(8, macro.decisions().stream().filter(x -> x.ts() <= 1_000_000 + YEAR).count());
            assertEquals(macro.policyRateBps() - (EconomySchedule.START_RATE_BPS - start), s.savingsProduct().rateBps());
            var gbnd = s.bonds().stream().filter(b -> b.instrument().equals("GBND-SPARK")).findFirst().orElseThrow();
            assertEquals("DEFAULTED", gbnd.status());
            assertEquals(3, gbnd.couponsPaid());
            var hbnd = s.bonds().stream().filter(b -> b.instrument().equals("HBND-SPARK")).findFirst().orElseThrow();
            assertEquals("ACTIVE", hbnd.status());
            assertTrue(hbnd.couponsPaid() >= 4);
            var silk = s.companies().getFirst();
            assertTrue(silk.reports().size() >= 4);
            assertTrue(silk.peX100() != null && silk.dividendYieldBps() != null);
            assertTrue(s.statement("acc-a", 0, Long.MAX_VALUE).totals().payouts() > 0, "coupons and dividends in the statement");
            before = s.companies() + "" + s.bonds() + s.macro() + s.balances("acc-a");
        }
        List<Event> events = journal.readAll();
        long deposited = events.stream().filter(e -> e instanceof Event.FundsDeposited d && d.asset().equals("SPARK"))
                .mapToLong(e -> ((Event.FundsDeposited) e).amount()).sum();
        assertEquals(deposited, engine.Exchange.replay(Instrument.ALL, events).ledger().totalOf("SPARK"));

        int size = events.size();
        try (ExchangeService again = new ExchangeService(Instrument.ALL, journal, clock, start(), opts)) {
            again.runEconomy();
            assertEquals(size, journal.readAll().size(), "a restart does not publish anything twice");
            assertEquals(before, again.companies() + "" + again.bonds() + again.macro() + again.balances("acc-a"));
            assertFalse(again.calendar(clock.now(), clock.now() + YEAR).isEmpty());
            assertTrue(again.calendar(clock.now(), clock.now() + YEAR).stream()
                    .noneMatch(c -> !c.done() && (c.kind().equals("STORM") || c.actual() != null && c.kind().equals("EARNINGS"))),
                    "the future calendar does not leak results or weather");
        }
    }
}
