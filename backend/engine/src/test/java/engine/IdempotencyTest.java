package engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

/** A repeated Idempotency-Key returns the first stop, position or deposit; nothing new is created or journalled. */
class IdempotencyTest {

    private final Exchange ex = new Exchange(Instrument.ALL);
    private final List<Event> journal = new ArrayList<>();

    private Outcome run(Command c) {
        Outcome o = ex.execute(c, 1);
        assertTrue(o.accepted(), () -> c + " -> " + o.rejection());
        journal.addAll(o.events());
        return o;
    }

    @Test
    void repeatedKeysReturnTheFirstObject() {
        run(new Command.OpenAccount("a", "a"));
        run(new Command.OpenAccount("b", "b"));
        run(new Command.Deposit("a", "SPARK", 100_000_000));
        run(new Command.Deposit("b", "AMBER", 10_000));
        run(new Command.Deposit(Ledger.BANK_ACCOUNT, "SPARK", 100_000_000));
        run(new Command.Deposit(Ledger.BANK_ACCOUNT, "AMBER", 100_000));
        run(new Command.PlaceOrder("b", "AMBER-SPARK", Order.Side.SELL, Order.Type.LIMIT, 50_000, 1_000, null));

        var stop = new Command.PlaceConditional("a", "SILK-SPARK", Conditional.Kind.STOP_MARKET, Order.Side.SELL, 1,
                9_000, 0, 0, 0, 0, "k");
        long s1 = run(stop).orderId();
        Outcome again = run(stop);
        assertEquals(s1, again.orderId());
        assertTrue(again.events().isEmpty());

        var margin = new Command.OpenMargin("a", "AMBER-SPARK", Order.Side.BUY, 10, 4, "k");
        long m1 = run(margin).orderId();
        assertEquals(m1, run(margin).orderId());
        assertEquals(1, ex.positionsOf("a", 10).size());

        var savings = new Command.OpenSavings("a", "SPARK", 1_000, 1_400, 60_000, "k");
        long d1 = run(savings).orderId();
        assertEquals(d1, run(savings).orderId());
        assertEquals(1, ex.savingsOf("a").size());

        // another account may use the same key
        assertTrue(run(new Command.OpenSavings("b", "AMBER", 1, 0, 60_000, "k")).orderId() != d1);

        // keys survive replay
        Exchange replayed = Exchange.replay(Instrument.ALL, journal);
        assertEquals(ex.fingerprint(), replayed.fingerprint());
        assertTrue(replayed.execute(savings, 2).events().isEmpty());
    }
}
