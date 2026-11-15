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
 * Intent 02 invariants over random flows on both instruments with stops, take-profits, leverage, savings and
 * interest:
 * №1 money is never created or destroyed (loans and interest move money from the bank account);
 * №4 replaying the journal gives exactly the same state;
 * №5 a conditional order fires only on a trade price (each print of a sweep, in order, is a "last trade price"
 *     in turn), never on a book quote, and only when its condition holds at that price;
 * №6 after every command no open leveraged position has equity at or below half its collateral.
 */
class M2aPropertiesTest {

    private static final List<String> PEOPLE = List.of("a", "b", "c", "d");
    private static final List<String> ASSETS = List.of("SPARK", "SILK", "AMBER");
    private static final long DAY = 5_000;

    @Property(tries = 150)
    void moneyIsConservedAndReservationsMatchOpenOrders(@ForAll long seed, @ForAll @IntRange(min = 1, max = 400) int steps) {
        List<Event> journal = new ArrayList<>();
        Exchange ex = randomFlow(seed, steps, journal, null);
        net.jqwik.api.statistics.Statistics.label("stop-out").collect(journal.stream().anyMatch(e -> e instanceof Event.MarginStopOut));
        net.jqwik.api.statistics.Statistics.label("stop fired").collect(journal.stream().anyMatch(e -> e instanceof Event.ConditionalTriggered));
        net.jqwik.api.statistics.Statistics.label("interest").collect(journal.stream().anyMatch(e -> e instanceof Event.InterestAccrued));

        for (String asset : ASSETS) {
            long deposited = journal.stream().filter(e -> e instanceof Event.FundsDeposited d && d.asset().equals(asset))
                    .mapToLong(e -> ((Event.FundsDeposited) e).amount()).sum();
            assertEquals(deposited, ex.ledger().totalOf(asset), asset);
        }
        for (String account : ex.ledger().accountIds()) {
            for (String asset : ASSETS) {
                assertTrue(ex.ledger().available(account, asset) >= 0, account + " " + asset);
                assertEquals(ex.reservedByOpenOrders(account, asset), ex.ledger().reserved(account, asset), account + " " + asset);
            }
        }
    }

    @Property(tries = 100)
    void replayingTheJournalRebuildsTheSameState(@ForAll long seed, @ForAll @IntRange(min = 1, max = 400) int steps) {
        List<Event> journal = new ArrayList<>();
        Exchange live = randomFlow(seed, steps, journal, null);

        Exchange replayed = Exchange.replay(Instrument.ALL, journal);

        assertEquals(live.fingerprint(), replayed.fingerprint());
    }

    @Property(tries = 150)
    void conditionalsFireOnlyOnALastTradePriceThatMeetsTheirCondition(@ForAll long seed,
                                                                       @ForAll @IntRange(min = 1, max = 400) int steps) {
        List<List<Event>> batches = new ArrayList<>();
        randomFlow(seed, steps, new ArrayList<>(), null, batches);

        java.util.Map<Long, Event.ConditionalPlaced> placed = new java.util.HashMap<>();
        java.util.Set<Long> armed = new java.util.HashSet<>();
        for (List<Event> batch : batches) {
            List<Event.TradeExecuted> printsSoFar = new ArrayList<>();
            for (Event e : batch) {
                switch (e) {
                    case Event.ConditionalPlaced p -> placed.put(p.conditionalId(), p);
                    case Event.TradeExecuted t -> printsSoFar.add(t);
                    case Event.ConditionalArmed a -> {
                        assertTrue(printed(printsSoFar, placed.get(a.conditionalId()).instrument(), a.lastPrice()), a.toString());
                        armed.add(a.conditionalId());
                    }
                    case Event.ConditionalTriggered t -> {
                        Event.ConditionalPlaced p = placed.get(t.conditionalId());
                        assertTrue(printed(printsSoFar, p.instrument(), t.lastPrice()), "fired on a trade of this command: " + t);
                        boolean sell = p.side() == Order.Side.SELL;
                        if (!armed.contains(p.conditionalId())) { // a stop leg
                            assertTrue(sell ? t.lastPrice() <= p.triggerPrice() : t.lastPrice() >= p.triggerPrice(), t + " for " + p);
                        }
                    }
                    default -> { }
                }
            }
        }
    }

    private static boolean printed(List<Event.TradeExecuted> prints, String instrument, long price) {
        return prints.stream().anyMatch(t -> t.instrument().equals(instrument) && t.price() == price);
    }

    @Property(tries = 150)
    void noOpenLeveragedPositionIsBelowHalfItsCollateral(@ForAll long seed, @ForAll @IntRange(min = 1, max = 400) int steps) {
        randomFlow(seed, steps, new ArrayList<>(), ex -> {
            for (String person : PEOPLE) {
                for (MarginView p : ex.positionsOf(person, 1_000)) {
                    if (p.status() == MarginView.Status.OPEN && p.lastPrice() != null) {
                        assertTrue(2 * p.equity() > p.collateral(), "should have been stopped out: " + p);
                    }
                }
            }
        });
    }

    /** A random but seeded flow; {@code afterEach} (optional) checks the state after every command. */
    static Exchange randomFlow(long seed, int steps, List<Event> journal, java.util.function.Consumer<Exchange> afterEach) {
        return randomFlow(seed, steps, journal, afterEach, new ArrayList<>());
    }

    /** {@code batches} receives the events of each command separately. */
    static Exchange randomFlow(long seed, int steps, List<Event> journal, java.util.function.Consumer<Exchange> afterEach,
                               List<List<Event>> batches) {
        Random r = new Random(seed);
        Exchange ex = new Exchange(Instrument.ALL);
        long ts = 0;
        journal.addAll(ex.execute(new Command.Deposit(Ledger.BANK_ACCOUNT, "SPARK", 10_000_000_000L), ts).events());
        journal.addAll(ex.execute(new Command.Deposit(Ledger.BANK_ACCOUNT, "AMBER", 1_000_000), ts).events());
        for (String a : PEOPLE) {
            journal.addAll(ex.execute(new Command.OpenAccount(a, a), ts).events());
            journal.addAll(ex.execute(new Command.Deposit(a, "SPARK", 50_000_000 + r.nextInt(50_000_000)), ts).events());
            journal.addAll(ex.execute(new Command.Deposit(a, "SILK", 100 + r.nextInt(500)), ts).events());
            journal.addAll(ex.execute(new Command.Deposit(a, "AMBER", 100 + r.nextInt(500)), ts).events());
        }
        List<Long> orders = new ArrayList<>();
        List<Long> conditionals = new ArrayList<>();
        List<Long> positions = new ArrayList<>();
        List<Long> deposits = new ArrayList<>();
        for (int i = 0; i < steps; i++) {
            ts += r.nextInt(2_000);
            String a = PEOPLE.get(r.nextInt(PEOPLE.size()));
            boolean fx = r.nextBoolean();
            String instrument = fx ? "AMBER-SPARK" : "SILK-SPARK";
            long centre = fx ? 50_000 : 10_000;
            long spreadOf = centre / 8; // wide enough to cross stops and stop-outs
            Order.Side side = r.nextBoolean() ? Order.Side.BUY : Order.Side.SELL;
            long price = centre - spreadOf + r.nextInt((int) (2 * spreadOf));
            int pick = r.nextInt(100);
            Command c;
            if (pick < 10 && !orders.isEmpty()) {
                c = new Command.CancelOrder(a, orders.get(r.nextInt(orders.size())));
            } else if (pick < 20) {
                Conditional.Kind kind = Conditional.Kind.values()[r.nextInt(4)];
                long trigger = centre - spreadOf + r.nextInt((int) (2 * spreadOf));
                long activation = side == Order.Side.SELL ? trigger + 1 + r.nextInt((int) spreadOf) : Math.max(1, trigger - 1 - r.nextInt((int) spreadOf));
                long limit = r.nextInt(3) == 0 ? 0 : Math.max(1, trigger + (side == Order.Side.SELL ? -1 : 1) * r.nextInt(50));
                c = new Command.PlaceConditional(a, instrument, kind, side, 1 + r.nextInt(20), trigger, limit, activation,
                        r.nextInt(100), r.nextInt(20) - 5);
            } else if (pick < 23 && !conditionals.isEmpty()) {
                c = new Command.CancelConditional(a, conditionals.get(r.nextInt(conditionals.size())));
            } else if (pick < 30) {
                c = new Command.OpenMargin(a, "AMBER-SPARK", side, 1 + r.nextInt(40), 1 + r.nextInt(4));
            } else if (pick < 33 && !positions.isEmpty()) {
                c = new Command.CloseMargin(a, positions.get(r.nextInt(positions.size())));
            } else if (pick < 36) {
                c = new Command.OpenSavings(a, "SPARK", 1 + r.nextInt(5_000_000), r.nextInt(3_000), DAY);
            } else if (pick < 38 && !deposits.isEmpty()) {
                c = new Command.CloseSavings(a, deposits.get(r.nextInt(deposits.size())));
            } else if (pick < 43) {
                c = new Command.AccrueInterest();
            } else {
                Order.Type type = pick < 55 ? Order.Type.MARKET : Order.Type.LIMIT;
                c = new Command.PlaceOrder(a, instrument, side, type, price, 1 + r.nextInt(60),
                        r.nextInt(5) == 0 ? "k" + r.nextInt(20) : null);
            }
            Outcome o = ex.execute(c, ts);
            if (o.accepted() && o.orderId() > 0) {
                switch (c) {
                    case Command.PlaceOrder p -> orders.add(o.orderId());
                    case Command.PlaceConditional p -> conditionals.add(o.orderId());
                    case Command.OpenMargin p -> positions.add(o.orderId());
                    case Command.OpenSavings p -> deposits.add(o.orderId());
                    default -> { }
                }
            }
            journal.addAll(o.events());
            batches.add(o.events());
            if (afterEach != null) {
                afterEach.accept(ex);
            }
        }
        return ex;
    }
}
