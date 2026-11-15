package engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.constraints.IntRange;
import org.junit.jupiter.api.Test;

/**
 * M2b engine rules (ADR-0021): trading halts, dividends, coupons, redemption and default.
 * Properties: money is conserved by every payout and by default; replay rebuilds the same state.
 */
class M2bTest {

    private static final String ISSUER = "issuer-gbnd";
    private final Exchange ex = new Exchange(Instrument.ALL);
    private final List<Event> journal = new ArrayList<>();

    private Outcome ok(Command c) {
        Outcome o = ex.execute(c, journal.size());
        assertTrue(o.accepted(), () -> c + " -> " + o.rejection());
        journal.addAll(o.events());
        return o;
    }

    private void setUp() {
        for (String a : List.of("a", "b", ISSUER)) {
            ok(new Command.OpenAccount(a, a));
        }
        ok(new Command.Deposit("a", "GBND", 10));
        ok(new Command.Deposit("b", "GBND", 5));
        ok(new Command.Deposit("b", "SPARK", 10_000_000));
        ok(new Command.Deposit(ISSUER, "SPARK", 2_500));
    }

    @Test
    void aHaltedMarketRefusesNewOrdersButAllowsCancels() {
        setUp();
        long id = ok(new Command.PlaceOrder("a", "GBND-SPARK", Order.Side.SELL, Order.Type.LIMIT, 90_000, 1, null)).orderId();
        ok(new Command.SetTradingStatus("GBND-SPARK", false, "REPORT"));
        Outcome refused = ex.execute(new Command.PlaceOrder("b", "GBND-SPARK", Order.Side.BUY, Order.Type.MARKET, 0, 1, null), 1);
        assertEquals(Rejection.MARKET_CLOSED, refused.rejection());
        assertEquals(Rejection.MARKET_CLOSED, ex.execute(new Command.PlaceConditional("a", "GBND-SPARK",
                Conditional.Kind.STOP_MARKET, Order.Side.SELL, 1, 80_000, 0, 0, 0, 0), 1).rejection());
        ok(new Command.CancelOrder("a", id));
        ok(new Command.SetTradingStatus("GBND-SPARK", true, "OPEN"));
        assertTrue(ex.isOpen("GBND-SPARK"));
    }

    @Test
    void aCouponIsPaidPerBondHeldIncludingBondsInOpenOrders() {
        setUp();
        ok(new Command.PlaceOrder("a", "GBND-SPARK", Order.Side.SELL, Order.Type.LIMIT, 90_000, 4, null));
        Outcome o = ok(new Command.Payout("GBND-SPARK", Event.PayoutKind.COUPON, ISSUER, 100));
        assertEquals(new Event.PayoutStarted(journal.indexOf(o.events().getFirst()), "GBND-SPARK", Event.PayoutKind.COUPON,
                ISSUER, 100, 15, 1_500), o.events().getFirst());
        assertEquals(1_000, ex.ledger().available("a", "SPARK"));
        assertEquals(1_000, ex.ledger().available(ISSUER, "SPARK"));
    }

    @Test
    void anIssuerThatCannotPayDefaultsAndRedeemsAtRecovery() {
        setUp();
        ok(new Command.Payout("GBND-SPARK", Event.PayoutKind.COUPON, ISSUER, 100));
        Outcome cannot = ex.execute(new Command.Payout("GBND-SPARK", Event.PayoutKind.COUPON, ISSUER, 100), 9);
        assertEquals(Rejection.INSUFFICIENT_FUNDS, cannot.rejection());
        ok(new Command.DeclareDefault("GBND-SPARK", ISSUER));
        assertEquals(Rejection.DEFAULTED, ex.execute(new Command.Payout("GBND-SPARK", Event.PayoutKind.COUPON, ISSUER, 1), 9).rejection());

        ok(new Command.PlaceOrder("a", "GBND-SPARK", Order.Side.SELL, Order.Type.LIMIT, 30_000, 2, null));
        ok(new Command.Payout("GBND-SPARK", Event.PayoutKind.REDEMPTION, ISSUER, 66)); // recovery: 1 000 left / 15 bonds
        assertEquals(0, ex.ledger().available("a", "GBND") + ex.ledger().reserved("a", "GBND"));
        assertEquals(15, ex.ledger().available(ISSUER, "GBND"));
        assertFalse(ex.isOpen("GBND-SPARK"));
        assertTrue(ex.ordersOf("a", true, 10).isEmpty(), "redemption cancels open orders");
        assertEquals(ex.fingerprint(), Exchange.replay(Instrument.ALL, journal).fingerprint());
    }

    @Test
    void disclosuresAreJournalledAsTheyAre() {
        var report = new Event.EarningsReported(5, "FORGE-SPARK", 1, 1_000, 100, 10, 50, 120, 3, 11, 10, 9);
        assertEquals(List.of(report), ex.execute(new Command.Publish(report), 99).events());
    }

    // ---- properties ----

    private static final List<String> PEOPLE = List.of("p1", "p2", "p3");
    private static final List<String> ASSETS = List.of("SPARK", "FORGE", "HBND", "GBND");
    private static final List<String> INSTRUMENTS = List.of("FORGE-SPARK", "HBND-SPARK", "GBND-SPARK");

    @Property(tries = 200)
    void payoutsAndDefaultConserveMoneyAndReplay(@ForAll long seed, @ForAll @IntRange(min = 1, max = 300) int steps) {
        Random r = new Random(seed);
        Exchange live = new Exchange(Instrument.ALL);
        List<Event> log = new ArrayList<>();
        long ts = 0;
        List<Command> setup = new ArrayList<>();
        for (String p : PEOPLE) {
            setup.add(new Command.OpenAccount(p, p));
            setup.add(new Command.Deposit(p, "SPARK", 5_000_000));
            setup.add(new Command.Deposit(p, "FORGE", 50));
            setup.add(new Command.Deposit(p, "HBND", 20));
            setup.add(new Command.Deposit(p, "GBND", 20));
        }
        for (String i : List.of("issuer-forge", "issuer-hbnd", "issuer-gbnd")) {
            setup.add(new Command.OpenAccount(i, i));
            setup.add(new Command.Deposit(i, "SPARK", 1 + r.nextInt(2_000_000)));
        }
        for (Command c : setup) {
            log.addAll(live.execute(c, ts).events());
        }
        for (int s = 0; s < steps; s++) {
            ts += 1 + r.nextInt(10);
            String inst = INSTRUMENTS.get(r.nextInt(INSTRUMENTS.size()));
            String issuer = "issuer-" + inst.substring(0, inst.indexOf('-')).toLowerCase();
            String p = PEOPLE.get(r.nextInt(PEOPLE.size()));
            Command c = switch (r.nextInt(10)) {
                case 0, 1, 2 -> new Command.PlaceOrder(p, inst, r.nextBoolean() ? Order.Side.BUY : Order.Side.SELL,
                        Order.Type.LIMIT, 90_000 + r.nextInt(20_000), 1 + r.nextInt(5), null);
                case 3 -> new Command.PlaceOrder(p, inst, r.nextBoolean() ? Order.Side.BUY : Order.Side.SELL,
                        Order.Type.MARKET, 0, 1 + r.nextInt(5), null);
                case 4 -> new Command.CancelOrder(p, 1 + r.nextInt(40));
                case 5 -> new Command.SetTradingStatus(inst, r.nextBoolean(), "TEST");
                case 6 -> new Command.Payout(inst, Event.PayoutKind.DIVIDEND, issuer, 1 + r.nextInt(500));
                case 7 -> new Command.Payout(inst, Event.PayoutKind.COUPON, issuer, 1 + r.nextInt(2_000));
                case 8 -> r.nextInt(5) == 0 ? new Command.Payout(inst, Event.PayoutKind.REDEMPTION, issuer, r.nextInt(5_000))
                        : new Command.DeclareDefault(inst, issuer);
                default -> new Command.Publish(new Event.MarketRegimeChanged(ts, "STORM", 300));
            };
            log.addAll(live.execute(c, ts).events());
        }
        for (String asset : ASSETS) {
            long deposited = log.stream().filter(e -> e instanceof Event.FundsDeposited d && d.asset().equals(asset))
                    .mapToLong(e -> ((Event.FundsDeposited) e).amount()).sum();
            assertEquals(deposited, live.ledger().totalOf(asset), asset);
        }
        for (String account : live.ledger().accountIds()) {
            for (String asset : ASSETS) {
                assertTrue(live.ledger().available(account, asset) >= 0);
                assertEquals(live.reservedByOpenOrders(account, asset), live.ledger().reserved(account, asset));
            }
        }
        for (Event e : log) {
            if (e instanceof Event.PayoutStarted ps) {
                assertEquals(ps.units() * ps.perUnit(), ps.total());
            }
        }
        assertEquals(live.fingerprint(), Exchange.replay(Instrument.ALL, log).fingerprint());
    }
}
