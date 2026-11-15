package application;

import engine.Balance;
import engine.Conditional;
import engine.ConditionalView;
import engine.Ledger;
import engine.MarginView;
import engine.SavingsView;
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
    private final StatementProjection statements;
    private final SavingsProduct savingsProduct;

    /** Bank capital, savings product: the M2a settings. */
    public record Options(Map<String, Long> bankCapital, SavingsProduct savings) {
        public static final Options DEFAULT = new Options(
                Map.of("SPARK", 100_000_000_000L, "AMBER", 10_000_000L), new SavingsProduct("SPARK", 1_400, 60_000));
    }

    public ExchangeService(List<Instrument> instruments, Journal journal, Clock clock, Map<String, Long> startingBalance) {
        this(instruments, journal, clock, startingBalance, Options.DEFAULT);
    }

    /**
     * @param startingBalance what a new account receives, asset → minor units; journalled as deposits
     * @param options         bank capital (journalled as deposits the first time) and the savings product
     */
    public ExchangeService(List<Instrument> instruments, Journal journal, Clock clock, Map<String, Long> startingBalance,
                           Options options) {
        List<Event> history = journal.readAll();
        Exchange exchange = Exchange.replay(instruments, history);
        restoreClock(clock, history);
        this.statements = new StatementProjection(instruments);
        statements.onEvents(history);
        this.sequencer = new Sequencer<>("exchange", exchange);
        this.journal = journal;
        this.clock = clock;
        this.startingBalance = Map.copyOf(startingBalance);
        this.savingsProduct = options.savings();
        sequencer.call(ex -> {
            options.bankCapital().entrySet().stream().sorted(Map.Entry.comparingByKey()).forEach(c -> {
                if (ex.ledger().available(Ledger.BANK_ACCOUNT, c.getKey()) + ex.ledger().reserved(Ledger.BANK_ACCOUNT, c.getKey()) == 0) {
                    run(ex, new Command.Deposit(Ledger.BANK_ACCOUNT, c.getKey(), c.getValue()));
                }
            });
            return null;
        });
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
    public ConditionalView placeConditional(String accountId, String instrument, Conditional.Kind kind, Order.Side side,
                                            long qty, long triggerPrice, long limitPrice, long activationPrice,
                                            long offset, long protectiveSpread, String idempotencyKey) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.PlaceConditional(accountId, instrument, kind, side, qty, triggerPrice,
                    limitPrice, activationPrice, offset, protectiveSpread, idempotencyKey));
            return ex.conditional(o.orderId()).orElseThrow();
        });
    }

    @Override
    public ConditionalView cancelConditional(String accountId, long conditionalId) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.CancelConditional(accountId, conditionalId));
            return ex.conditional(o.orderId()).orElseThrow();
        });
    }

    @Override
    public List<ConditionalView> conditionals(String accountId, int limit) {
        return sequencer.call(ex -> ex.conditionalsOf(accountId, limit));
    }

    @Override
    public MarginView openMargin(String accountId, String instrument, Order.Side side, long qty, int leverage,
                                 String idempotencyKey) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.OpenMargin(accountId, instrument, side, qty, leverage, idempotencyKey));
            return ex.position(o.orderId()).orElseThrow();
        });
    }

    @Override
    public MarginView closeMargin(String accountId, long positionId) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.CloseMargin(accountId, positionId));
            return ex.position(o.orderId()).orElseThrow();
        });
    }

    @Override
    public List<MarginView> positions(String accountId, int limit) {
        return sequencer.call(ex -> ex.positionsOf(accountId, limit));
    }

    @Override
    public SavingsProduct savingsProduct() {
        return savingsProduct;
    }

    @Override
    public SavingsView openSavings(String accountId, long amount, String idempotencyKey) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.OpenSavings(accountId, savingsProduct.asset(), amount, savingsProduct.rateBps(),
                    savingsProduct.dayMillis(), idempotencyKey));
            return ex.deposit(o.orderId()).orElseThrow();
        });
    }

    @Override
    public SavingsView closeSavings(String accountId, long depositId) {
        return sequencer.call(ex -> {
            Outcome o = run(ex, new Command.CloseSavings(accountId, depositId));
            return ex.deposit(o.orderId()).orElseThrow();
        });
    }

    @Override
    public List<SavingsView> savings(String accountId) {
        return sequencer.call(ex -> ex.savingsOf(accountId));
    }

    @Override
    public void accrueInterest() {
        sequencer.call(ex -> run(ex, new Command.AccrueInterest()));
    }

    @Override
    public StatementProjection.Statement statement(String accountId, long from, long to) {
        return sequencer.call(ex -> statements.statement(accountId, from, to));
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
        statements.onEvents(events);
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
