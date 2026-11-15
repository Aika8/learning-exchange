package engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.constraints.IntRange;
import org.junit.jupiter.api.Test;

/**
 * M2c engine rules (ADR-0022): trade-journal notes, dividends with ex/record/pay dates and tax withheld at source,
 * fund fees. Property: money is conserved through dividends and fund fees, and replay rebuilds the same state.
 */
class M2cTest {

    private static final String ISSUER = "issuer-silk";
    private final Exchange ex = new Exchange(Instrument.ALL);
    private final List<Event> journal = new ArrayList<>();
    private long ts;

    private Outcome ok(Command c) {
        Outcome o = ex.execute(c, ++ts);
        assertTrue(o.accepted(), () -> c + " -> " + o.rejection());
        journal.addAll(o.events());
        return o;
    }

    private void setUp() {
        for (String a : List.of("a", "b", ISSUER)) {
            ok(new Command.OpenAccount(a, a));
        }
        ok(new Command.Deposit("a", "SILK", 10));
        ok(new Command.Deposit("b", "SPARK", 10_000_000));
        ok(new Command.Deposit(ISSUER, "SPARK", 1_000_000));
    }

    @Test
    void aNoteIsJournalledOnceAndOnlyByTheOwner() {
        setUp();
        long id = ok(new Command.PlaceOrder("a", "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 10_000, 1, null)).orderId();
        assertEquals(Rejection.NOT_OWNER, ex.execute(new Command.AnnotateOrder("b", id, "x", null, null, 0), ts).rejection());
        Outcome o = ok(new Command.AnnotateOrder("a", id, "breakout", "TREND_UP", "FOMO", 500));
        assertEquals(new Event.OrderAnnotated(ts, id, "a", "breakout", "TREND_UP", "FOMO", 500), o.events().getFirst());
        assertEquals(Rejection.ALREADY_ANNOTATED,
                ex.execute(new Command.AnnotateOrder("a", id, "again", null, null, 0), ts).rejection());
        assertEquals(Rejection.UNKNOWN_ORDER, ex.execute(new Command.AnnotateOrder("a", 999, "x", null, null, 0), ts).rejection());
    }

    @Test
    void holdersAtTheExDateOpenArePaidOnThePayDateEvenIfTheySoldInBetween() {
        setUp();
        ok(new Command.PlaceOrder("a", "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 10_000, 4, null));
        ok(new Command.PlaceOrder("b", "SILK-SPARK", Order.Side.BUY, Order.Type.MARKET, 0, 4, null));
        // now a holds 6 (none reserved), b holds 4; the last price is 100.00
        long record = ts + 10;
        long payDate = ts + 50;
        Outcome exDate = ok(new Command.DividendExDate("SILK-SPARK", ISSUER, 300, record, payDate));
        assertEquals(new Event.DividendExDate(ts, "SILK-SPARK", ISSUER, 300, record, payDate, 10), exDate.events().getFirst());
        assertEquals(new Event.ReferencePriceAdjusted(ts, "SILK-SPARK", 10_000, 9_700, "EX_DIVIDEND"), exDate.events().getLast());
        assertEquals(9_700, ex.lastPrice("SILK-SPARK").orElseThrow());
        // a sells everything after the ex-date: still paid for 6
        ok(new Command.PlaceOrder("a", "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 9_700, 6, null));
        ok(new Command.PlaceOrder("b", "SILK-SPARK", Order.Side.BUY, Order.Type.MARKET, 0, 6, null));
        assertEquals(9_700, ex.lastPrice("SILK-SPARK").orElseThrow(), "a trade replaces the adjusted price");
        long aBefore = ex.ledger().available("a", "SPARK");
        long bBefore = ex.ledger().available("b", "SPARK");
        Outcome pay = ok(new Command.PayDividend("SILK-SPARK", 1_000));
        assertEquals(new Event.DividendPaymentStarted(ts, "SILK-SPARK", ISSUER, 300, 10, 3_000, 1_000), pay.events().getFirst());
        assertEquals(6 * 300 - 180, ex.ledger().available("a", "SPARK") - aBefore);
        assertEquals(4 * 300 - 120, ex.ledger().available("b", "SPARK") - bBefore);
        assertEquals(300, ex.ledger().available(Ledger.TAX_ACCOUNT, "SPARK"));
        assertEquals(Rejection.NOTHING_TO_PAY, ex.execute(new Command.PayDividend("SILK-SPARK", 1_000), ts).rejection());
        assertEquals(ex.fingerprint(), Exchange.replay(Instrument.ALL, journal).fingerprint());
    }

    @Test
    void aFundFeeMovesCashFromCustodyToTheManager() {
        ok(new Command.OpenAccount("fund-idx", "fund-idx"));
        ok(new Command.Deposit("fund-idx", "SPARK", 1_000));
        ok(new Command.ChargeFundFee("IDX-SPARK", "fund-idx", "manager-idx", "SPARK", 7, 1, 100_000, 100_000));
        assertEquals(993, ex.ledger().available("fund-idx", "SPARK"));
        assertEquals(7, ex.ledger().available("manager-idx", "SPARK"));
        assertEquals(Rejection.INSUFFICIENT_FUNDS,
                ex.execute(new Command.ChargeFundFee("IDX-SPARK", "fund-idx", "manager-idx", "SPARK", 5_000, 1, 0, 0), ts).rejection());
        assertEquals(ex.fingerprint(), Exchange.replay(Instrument.ALL, journal).fingerprint());
    }

    private static final List<String> PEOPLE = List.of("p1", "p2", "p3");

    @Property(tries = 200, shrinking = net.jqwik.api.ShrinkingMode.OFF)
    void dividendsAndFundFeesConserveMoneyAndReplay(@ForAll long seed, @ForAll @IntRange(min = 1, max = 120) int steps) {
        Random r = new Random(seed);
        Exchange live = new Exchange(Instrument.ALL);
        List<Event> log = new ArrayList<>();
        long t = 0;
        List<Command> setup = new ArrayList<>();
        for (String p : PEOPLE) {
            setup.add(new Command.OpenAccount(p, p));
            setup.add(new Command.Deposit(p, "SPARK", 5_000_000));
            setup.add(new Command.Deposit(p, "SILK", 1 + r.nextInt(60)));
        }
        setup.add(new Command.OpenAccount(ISSUER, ISSUER));
        setup.add(new Command.Deposit(ISSUER, "SPARK", 1 + r.nextInt(200_000)));
        setup.add(new Command.OpenAccount("fund-idx", "fund-idx"));
        setup.add(new Command.Deposit("fund-idx", "SPARK", 1 + r.nextInt(10_000)));
        for (Command c : setup) {
            log.addAll(live.execute(c, t).events());
        }
        for (int s = 0; s < steps; s++) {
            t += 1 + r.nextInt(10);
            String p = PEOPLE.get(r.nextInt(PEOPLE.size()));
            Command c = switch (r.nextInt(8)) {
                case 0, 1 -> new Command.PlaceOrder(p, "SILK-SPARK", r.nextBoolean() ? Order.Side.BUY : Order.Side.SELL,
                        Order.Type.LIMIT, 9_000 + r.nextInt(2_000), 1 + r.nextInt(5), null);
                case 2 -> new Command.PlaceOrder(p, "SILK-SPARK", r.nextBoolean() ? Order.Side.BUY : Order.Side.SELL,
                        Order.Type.MARKET, 0, 1 + r.nextInt(5), null);
                case 3 -> new Command.DividendExDate("SILK-SPARK", ISSUER, 1 + r.nextInt(800), t + r.nextInt(5), t + 5 + r.nextInt(5));
                case 4 -> new Command.PayDividend("SILK-SPARK", r.nextInt(2_000));
                case 5 -> new Command.ChargeFundFee("IDX-SPARK", "fund-idx", "manager-idx", "SPARK", r.nextInt(3_000), 1 + r.nextInt(3), 0, 0);
                case 6 -> new Command.AnnotateOrder(p, 1 + r.nextInt(20), "why", "RANGE", "CALM", r.nextInt(1_000));
                default -> new Command.CancelOrder(p, 1 + r.nextInt(20));
            };
            log.addAll(live.execute(c, t).events());
        }
        for (String asset : List.of("SPARK", "SILK")) {
            long deposited = log.stream().filter(e -> e instanceof Event.FundsDeposited d && d.asset().equals(asset))
                    .mapToLong(e -> ((Event.FundsDeposited) e).amount()).sum();
            assertEquals(deposited, live.ledger().totalOf(asset), asset);
        }
        for (String account : live.ledger().accountIds()) {
            assertTrue(live.ledger().available(account, "SPARK") >= 0);
        }
        for (Event e : log) {
            if (e instanceof Event.DividendPaymentStarted d) {
                long paid = log.stream().filter(x -> x instanceof Event.DividendPaid dp && dp.ts() == d.ts()
                        && dp.instrument().equals(d.instrument())).mapToLong(x -> ((Event.DividendPaid) x).gross()).sum();
                assertEquals(d.gross(), paid);
                assertEquals(d.units() * d.perShare(), d.gross());
            }
        }
        assertEquals(live.fingerprint(), Exchange.replay(Instrument.ALL, log).fingerprint());
    }
}
