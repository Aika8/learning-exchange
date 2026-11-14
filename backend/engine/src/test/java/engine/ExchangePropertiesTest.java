package engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.constraints.IntRange;

/**
 * Intent 02 invariants over random order flows:
 * №1 money is never created or destroyed by trading (fees move to the fees account);
 * №4 replaying the journal gives exactly the same state.
 * Plus: no balance goes negative, and the ledger's reserved amount equals what the open orders hold.
 */
class ExchangePropertiesTest {

    private static final List<String> ACCOUNTS = List.of("a", "b", "c", "d");

    @Property(tries = 200)
    void tradingConservesEveryAssetAndReservationsMatchOpenOrders(@ForAll long seed, @ForAll @IntRange(min = 1, max = 400) int steps) {
        List<Event> journal = new ArrayList<>();
        Exchange ex = randomFlow(seed, steps, journal);

        long sparkDeposited = journal.stream().filter(e -> e instanceof Event.FundsDeposited d && d.asset().equals("SPARK"))
                .mapToLong(e -> ((Event.FundsDeposited) e).amount()).sum();
        long silkDeposited = journal.stream().filter(e -> e instanceof Event.FundsDeposited d && d.asset().equals("SILK"))
                .mapToLong(e -> ((Event.FundsDeposited) e).amount()).sum();
        assertEquals(sparkDeposited, ex.ledger().totalOf("SPARK"));
        assertEquals(silkDeposited, ex.ledger().totalOf("SILK"));

        for (String a : ACCOUNTS) {
            for (String asset : List.of("SPARK", "SILK")) {
                assertTrue(ex.ledger().available(a, asset) >= 0);
                assertEquals(ex.reservedByOpenOrders(a, asset), ex.ledger().reserved(a, asset), a + " " + asset);
            }
        }
    }

    @Property(tries = 100)
    void replayingTheJournalRebuildsTheSameState(@ForAll long seed, @ForAll @IntRange(min = 1, max = 400) int steps) {
        List<Event> journal = new ArrayList<>();
        Exchange live = randomFlow(seed, steps, journal);

        Exchange replayed = Exchange.replay(List.of(Instrument.SILK_SPARK), journal);

        assertEquals(live.fingerprint(), replayed.fingerprint());
    }

    static Exchange randomFlow(long seed, int steps, List<Event> journal) {
        Random r = new Random(seed);
        Exchange ex = new Exchange(List.of(Instrument.SILK_SPARK));
        long ts = 0;
        for (String a : ACCOUNTS) {
            journal.addAll(ex.execute(new Command.OpenAccount(a, a), ts).events());
            journal.addAll(ex.execute(new Command.Deposit(a, "SPARK", 1_000_000 + r.nextInt(1_000_000)), ts).events());
            journal.addAll(ex.execute(new Command.Deposit(a, "SILK", 100 + r.nextInt(500)), ts).events());
        }
        List<Long> ids = new ArrayList<>();
        for (int i = 0; i < steps; i++) {
            ts += r.nextInt(1_000);
            String a = ACCOUNTS.get(r.nextInt(ACCOUNTS.size()));
            Command c;
            int pick = r.nextInt(10);
            if (pick < 2 && !ids.isEmpty()) {
                c = new Command.CancelOrder(a, ids.get(r.nextInt(ids.size())));
            } else {
                Order.Side side = r.nextBoolean() ? Order.Side.BUY : Order.Side.SELL;
                Order.Type type = pick < 4 ? Order.Type.MARKET : Order.Type.LIMIT;
                c = new Command.PlaceOrder(a, "SILK-SPARK", side, type, 9_000 + r.nextInt(2_000), 1 + r.nextInt(60),
                        r.nextInt(5) == 0 ? "k" + r.nextInt(20) : null);
            }
            Outcome o = ex.execute(c, ts);
            if (o.accepted() && o.orderId() > 0) {
                ids.add(o.orderId());
            }
            journal.addAll(o.events());
        }
        return ex;
    }
}
