package application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Event;
import engine.Instrument;
import engine.Order;
import engine.OrderView;
import engine.Rejection;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ExchangeServiceTest {

    private static final List<Instrument> I = List.of(Instrument.SILK_SPARK);
    private static final Map<String, Long> START = Map.of("SPARK", 10_000_000L, "SILK", 1_000L);

    @Test
    void loginOpensAnAccountOnceWithTheStartingBalance() throws Exception {
        try (ExchangeService s = new ExchangeService(I, new InMemoryJournal(), new ManualClock(0), START)) {
            TradingService.Account a = s.login("Aika");
            TradingService.Account again = s.login("aika");

            assertEquals("acc-aika", a.accountId());
            assertEquals(a.accountId(), again.accountId());
            assertEquals(10_000_000L, s.balances(a.accountId()).stream()
                    .filter(b -> b.asset().equals("SPARK")).findFirst().orElseThrow().available());
        }
    }

    @Test
    void rejectedCommandsAreNotJournalled() throws Exception {
        InMemoryJournal journal = new InMemoryJournal();
        try (ExchangeService s = new ExchangeService(I, journal, new ManualClock(0), START)) {
            String a = s.login("a").accountId();
            int before = journal.readAll().size();
            CommandRejected e = assertThrows(CommandRejected.class,
                    () -> s.place(a, "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 100, 5_000, null));
            assertEquals(Rejection.INSUFFICIENT_FUNDS, e.reason());
            assertEquals(before, journal.readAll().size());
            assertThrows(CommandRejected.class, () -> s.login("bad/name"));
        }
    }

    @Test
    void restartReplaysTheJournalAndObserversSeeEvents() throws Exception {
        InMemoryJournal journal = new InMemoryJournal();
        ManualClock clock = new ManualClock(1_000);
        List<Event> seen = new ArrayList<>();
        String before;
        try (ExchangeService s = new ExchangeService(I, journal, clock, START)) {
            s.subscribe(seen::addAll);
            String a = s.login("a").accountId();
            String b = s.login("b").accountId();
            s.place(a, "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 10_000, 5, null);
            clock.advance(10);
            OrderView buy = s.place(b, "SILK-SPARK", Order.Side.BUY, Order.Type.LIMIT, 10_000, 8, "key-1");
            assertEquals(OrderView.Status.PARTIALLY_FILLED, buy.status());
            before = s.balances(a) + "|" + s.balances(b) + "|" + s.book("SILK-SPARK", 10);
        }
        assertTrue(seen.stream().anyMatch(e -> e instanceof Event.TradeExecuted));
        assertEquals(journal.readAll(), seen);

        try (ExchangeService s = new ExchangeService(I, journal, clock, START)) {
            String after = s.balances("acc-a") + "|" + s.balances("acc-b") + "|" + s.book("SILK-SPARK", 10);
            assertEquals(before, after);
            // The idempotency key survives the restart too.
            OrderView again = s.place("acc-b", "SILK-SPARK", Order.Side.BUY, Order.Type.LIMIT, 10_000, 8, "key-1");
            assertEquals(2, again.orderId());
        }
    }

    @Test
    void simulationClockPausesAndSpeedsUp() {
        long[] real = {0};
        SimulationClock c = new SimulationClock(() -> real[0], 1_000);
        real[0] = 100;
        assertEquals(1_100, c.now());
        c.set(false, 10);
        real[0] = 200;
        assertEquals(2_100, c.now());
        c.set(true, 10);
        real[0] = 10_000;
        assertEquals(2_100, c.now());
        c.set(false, 1);
        real[0] = 10_001;
        assertEquals(2_101, c.now());
        assertThrows(IllegalArgumentException.class, () -> c.set(false, 0));
    }
}
