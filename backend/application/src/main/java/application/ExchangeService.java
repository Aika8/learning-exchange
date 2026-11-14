package application;

import engine.Balance;
import engine.Command;
import engine.Event;
import engine.Exchange;
import engine.Instrument;
import engine.Order;
import engine.OrderView;
import engine.Outcome;
import engine.Rejection;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.regex.Pattern;

/**
 * The application service: stamps each command with simulation time, runs it on the {@link Sequencer}, journals the
 * events and tells the {@link MarketListener observers}. On start it replays the journal (ADR-0005).
 *
 * <p>Pattern: Ports &amp; Adapters — this is the hexagon's inside; REST, WebSocket, the file journal and the bots are
 * adapters around it. See docs/adr/0002-hexagonal-architecture.md.
 */
public final class ExchangeService implements TradingService, AutoCloseable {

    private static final Pattern NAME = Pattern.compile("[\\p{L}\\p{N} _-]{1,32}");

    private final Sequencer<Exchange> sequencer;
    private final Journal journal;
    private final Clock clock;
    private final Map<String, Long> startingBalance;
    private final List<MarketListener> listeners = new CopyOnWriteArrayList<>();

    /**
     * @param startingBalance what a new account receives, asset → minor units; journalled as deposits
     */
    public ExchangeService(List<Instrument> instruments, Journal journal, Clock clock, Map<String, Long> startingBalance) {
        List<Event> history = journal.readAll();
        Exchange exchange = Exchange.replay(instruments, history);
        restoreClock(clock, history);
        this.sequencer = new Sequencer<>("exchange", exchange);
        this.journal = journal;
        this.clock = clock;
        this.startingBalance = Map.copyOf(startingBalance);
    }

    @Override
    public Account login(String name) {
        String clean = name == null ? "" : name.strip();
        if (!NAME.matcher(clean).matches()) {
            throw new CommandRejected(Rejection.INVALID_NAME);
        }
        String id = accountId(clean);
        return sequencer.call(ex -> {
            if (!ex.hasAccount(id)) {
                run(ex, new Command.OpenAccount(id, clean));
                startingBalance.forEach((asset, amount) -> run(ex, new Command.Deposit(id, asset, amount)));
            }
            return new Account(id, ex.accountName(id).orElse(clean));
        });
    }

    @Override
    public Optional<Account> account(String accountId) {
        return sequencer.call(ex -> ex.accountName(accountId).map(n -> new Account(accountId, n)));
    }

    @Override
    public List<Balance> balances(String accountId) {
        return sequencer.call(ex -> ex.ledger().balances(accountId));
    }

    @Override
    public void deposit(String accountId, String asset, long amount) {
        sequencer.call(ex -> run(ex, new Command.Deposit(accountId, asset, amount)));
    }

    @Override
    public OrderView place(String accountId, String instrument, Order.Side side, Order.Type type, long price, long qty,
                           String idempotencyKey) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.PlaceOrder(accountId, instrument, side, type, price, qty, idempotencyKey));
            return ex.order(o.orderId()).orElseThrow();
        });
    }

    @Override
    public OrderView cancel(String accountId, long orderId) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.CancelOrder(accountId, orderId));
            return ex.order(o.orderId()).orElseThrow();
        });
    }

    @Override
    public List<OrderView> orders(String accountId, boolean openOnly, int limit) {
        return sequencer.call(ex -> ex.ordersOf(accountId, openOnly, limit));
    }

    @Override
    public List<Instrument> instruments() {
        return sequencer.call(Exchange::instruments);
    }

    @Override
    public BookSnapshot book(String instrument, int depth) {
        return sequencer.call(ex -> {
            requireInstrument(ex, instrument);
            return new BookSnapshot(instrument, ex.bids(instrument, depth), ex.asks(instrument, depth),
                    ex.lastPrice(instrument).orElse(null), clock.now());
        });
    }

    @Override
    public List<Event.TradeExecuted> trades(String instrument, int limit) {
        return sequencer.call(ex -> {
            requireInstrument(ex, instrument);
            return ex.recentTrades(instrument, limit);
        });
    }

    @Override
    public ClockState clock() {
        return new ClockState(clock.now(), clock.paused(), clock.speed());
    }

    @Override
    public ClockState setClock(boolean paused, int speed) {
        if (!(clock instanceof SimulationClock sim)) {
            throw new UnsupportedOperationException("this clock cannot be paused");
        }
        return sequencer.call(ex -> {
            sim.set(paused, speed);
            List<Event> events = List.of(new Event.ClockChanged(sim.now(), paused, speed));
            publish(events);
            return clock();
        });
    }

    @Override
    public void subscribe(MarketListener listener) {
        listeners.add(listener);
    }

    @Override
    public void close() throws InterruptedException {
        sequencer.close();
    }

    /** Lower-case name with spaces as dashes: "Aika" and "aika" are the same dev user. */
    public static String accountId(String name) {
        return "acc-" + name.strip().toLowerCase(Locale.ROOT).replace(' ', '-');
    }

    /** Runs on the sequencer thread: execute, journal, notify. A rejection changes nothing and is not journalled. */
    private Outcome run(Exchange ex, Command command) {
        Outcome o = ex.execute(command, clock.now());
        if (!o.accepted()) {
            throw new CommandRejected(o.rejection());
        }
        publish(o.events());
        return o;
    }

    private void publish(List<Event> events) {
        if (events.isEmpty()) {
            return;
        }
        journal.append(events);
        for (MarketListener l : listeners) {
            l.onEvents(events);
        }
    }

    private static void requireInstrument(Exchange ex, String instrument) {
        if (ex.instrument(instrument).isEmpty()) {
            throw new CommandRejected(Rejection.UNKNOWN_INSTRUMENT);
        }
    }

    private static void restoreClock(Clock clock, List<Event> history) {
        if (!(clock instanceof SimulationClock sim) || history.isEmpty()) {
            return;
        }
        long lastTs = history.getLast().ts();
        boolean paused = false;
        int speed = 1;
        for (Event e : history) {
            if (e instanceof Event.ClockChanged c) {
                paused = c.paused();
                speed = c.speed();
            }
        }
        sim.resumeFrom(lastTs, paused, speed);
    }
}
