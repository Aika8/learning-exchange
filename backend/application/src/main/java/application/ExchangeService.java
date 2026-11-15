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
import application.economy.EconomyProjection;
import application.economy.EconomyQueries;
import application.economy.EconomySchedule;
import application.economy.EconomyViews;
import application.economy.Securities;
import application.realworld.PaperBook;
import application.realworld.RealMarketData;
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
    private final EconomyProjection economy = new EconomyProjection();
    private final PaperBook paper = new PaperBook();
    private final CandleProjection candles;
    private final RealMarketData realData;
    private final EconomySchedule schedule;
    private final long depositMarginBps;
    private long economyCursor;

    /**
     * Bank capital, the savings product (its rate is the starting deposit rate; it then follows the policy rate),
     * the economy's seed, issuers' cash (journalled once, like bank capital) and the real-world data adapter.
     */
    public record Options(Map<String, Long> bankCapital, SavingsProduct savings, long economySeed,
                          Map<String, Long> issuerCash, RealMarketData realData) {

        /** GBND's issuer has cash for about three and a half coupons on the bots' float: it defaults on the fourth. */
        public static final Map<String, Long> ISSUER_CASH = Map.of("issuer-silk", 5_000_000_000L,
                "issuer-forge", 5_000_000_000L, "issuer-hbnd", 1_000_000_000L, "issuer-gbnd", 45_000_000L);

        public static final Options DEFAULT = new Options(
                Map.of("SPARK", 100_000_000_000L, "AMBER", 10_000_000L), new SavingsProduct("SPARK", 1_400, 60_000));

        /** M2a shape: no issuers (no dividends or coupons), no real data. */
        public Options(Map<String, Long> bankCapital, SavingsProduct savings) {
            this(bankCapital, savings, 42, Map.of(), RealMarketData.NONE);
        }
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
        this.economy.onEvents(history);
        this.paper.onEvents(history);
        this.candles = new CandleProjection(options.savings().dayMillis());
        candles.onEvents(history);
        this.realData = options.realData();
        this.schedule = new EconomySchedule(options.economySeed(), economy.epoch().orElse(clock.now()),
                options.savings().dayMillis());
        this.economyCursor = economy.epoch().isPresent() ? economy.lastEconomyTs() : schedule.epoch() - 1;
        this.depositMarginBps = EconomySchedule.START_RATE_BPS - options.savings().rateBps();
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
            options.issuerCash().entrySet().stream().sorted(Map.Entry.comparingByKey()).forEach(c -> {
                if (!ex.hasAccount(c.getKey())) {
                    run(ex, new Command.OpenAccount(c.getKey(), c.getKey()));
                    run(ex, new Command.Deposit(c.getKey(), "SPARK", c.getValue()));
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

    /** The deposit rate follows the central bank: policy rate minus the bank's margin (M2b, world bible §5b). */
    @Override
    public SavingsProduct savingsProduct() {
        long rate = sequencer.call(ex -> Math.max(0, economy.policyRateBps() - depositMarginBps));
        return new SavingsProduct(savingsProduct.asset(), rate, savingsProduct.dayMillis());
    }

    @Override
    public SavingsView openSavings(String accountId, long amount, String idempotencyKey) {
        return sequencer.call(ex -> {
            long rate = Math.max(0, economy.policyRateBps() - depositMarginBps);
            Outcome o = run(ex, new Command.OpenSavings(accountId, savingsProduct.asset(), amount, rate,
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

    // ---- M2b: economy (ADR-0021) ----

    @Override
    public void runEconomy() {
        sequencer.call(ex -> {
            long now = clock.now();
            for (EconomySchedule.Item item : schedule.between(economyCursor, now)) {
                runItem(ex, item);
                economyCursor = item.at();
            }
            return null;
        });
    }

    /** Turns one schedule item into commands, deciding against the current state (who holds what, who can pay). */
    private void runItem(Exchange ex, EconomySchedule.Item item) {
        long at = item.at();
        switch (item) {
            case EconomySchedule.Publish p -> runAt(ex, new Command.Publish(p.disclosure()), at);
            case EconomySchedule.TradingStatus t -> runAt(ex, new Command.SetTradingStatus(t.instrument(), t.open(), t.reason()), at);
            case EconomySchedule.Dividend d -> runAt(ex, new Command.Payout(d.instrument(), Event.PayoutKind.DIVIDEND, d.issuer(), d.perShare()), at);
            case EconomySchedule.Insider i -> ex.lastPrice(i.instrument()).ifPresent(price -> runAt(ex, new Command.Publish(
                    new Event.InsiderTradeDisclosed(at, i.instrument(), i.insider(), i.role(), i.side(), i.qty(), price)), at));
            case EconomySchedule.Coupon c -> {
                if (ex.isDefaulted(c.instrument())) {
                    return;
                }
                Outcome o = runAt(ex, new Command.Payout(c.instrument(), Event.PayoutKind.COUPON, c.bond().issuer(),
                        c.bond().couponPerUnit()), at);
                if (o.rejection() == Rejection.INSUFFICIENT_FUNDS) {
                    runAt(ex, new Command.DeclareDefault(c.instrument(), c.bond().issuer()), at);
                }
            }
            case EconomySchedule.Maturity m -> {
                Securities.Bond b = m.bond();
                long units = unitsHeld(ex, b.instrument(), b.issuer());
                long cash = ex.ledger().available(b.issuer(), "SPARK");
                if (!ex.isDefaulted(b.instrument()) && cash < Math.multiplyExact(units, b.faceValue())) {
                    runAt(ex, new Command.DeclareDefault(b.instrument(), b.issuer()), at);
                }
                long perUnit = ex.isDefaulted(b.instrument()) ? (units == 0 ? 0 : Math.min(b.faceValue(), cash / units)) : b.faceValue();
                runAt(ex, new Command.Payout(b.instrument(), Event.PayoutKind.REDEMPTION, b.issuer(), perUnit), at);
            }
        }
    }

    private static long unitsHeld(Exchange ex, String instrument, String issuer) {
        String base = ex.instrument(instrument).orElseThrow().base();
        long units = 0;
        for (String a : ex.ledger().accountIds()) {
            if (!a.equals(issuer) && !a.equals(Ledger.FEES_ACCOUNT) && !a.equals(Ledger.BANK_ACCOUNT)) {
                units += ex.ledger().available(a, base) + ex.ledger().reserved(a, base);
            }
        }
        return units;
    }

    /** Like {@link #run} at a given time, but a refusal is an answer, not an error (the economy decides on it). */
    private Outcome runAt(Exchange ex, Command command, long ts) {
        Outcome o = ex.execute(command, ts);
        if (o.accepted()) {
            publish(o.events());
        }
        return o;
    }

    @Override
    public boolean tradingOpen(String instrument) {
        return sequencer.call(ex -> ex.isOpen(instrument));
    }

    @Override
    public List<EconomyViews.CalendarEntry> calendar(long from, long to) {
        return sequencer.call(ex -> EconomyQueries.calendar(schedule, economy, from, to, economyCursor));
    }

    @Override
    public EconomyViews.Macro macro() {
        return sequencer.call(ex -> EconomyQueries.macro(economy, depositMarginBps));
    }

    @Override
    public List<EconomyViews.Company> companies() {
        return sequencer.call(ex -> Securities.COMPANIES.stream()
                .map(c -> EconomyQueries.company(c, economy, schedule, ex.lastPrice(c.instrument()).orElse(null),
                        ex.isOpen(c.instrument()), clock.now()))
                .toList());
    }

    @Override
    public List<EconomyViews.Bond> bonds() {
        return sequencer.call(ex -> Securities.BONDS.stream()
                .map(b -> EconomyQueries.bond(b, economy, schedule, ex.lastPrice(b.instrument()).orElse(null), clock.now()))
                .toList());
    }

    @Override
    public List<CandleProjection.Candle> candles(String instrument, int limit) {
        return sequencer.call(ex -> {
            requireInstrument(ex, instrument);
            return candles.candles(instrument, limit);
        });
    }

    // ---- M2b: real world (ADR-0015) ----

    @Override
    public List<RealMarketData.Quote> realQuotes() {
        return realData.quotes();
    }

    @Override
    public List<RealMarketData.Point> realHistory(String symbol) {
        return realData.history(symbol);
    }

    @Override
    public Optional<RealMarketData.BaseRate> realBaseRate() {
        return realData.baseRate();
    }

    @Override
    public List<PaperBook.Position> paperPositions(String accountId) {
        return sequencer.call(ex -> paper.of(accountId));
    }

    @Override
    public PaperBook.Position openPaper(String accountId, String symbol, Order.Side side, long qty, String idempotencyKey) {
        RealMarketData.Quote q = realData.quote(symbol).orElseThrow(() -> new CommandRejected(Rejection.UNKNOWN_INSTRUMENT));
        return sequencer.call(ex -> {
            if (!ex.hasAccount(accountId)) {
                throw new CommandRejected(Rejection.UNKNOWN_ACCOUNT);
            }
            Optional<Long> seen = paper.byKey(accountId, idempotencyKey);
            if (seen.isPresent()) {
                return paper.get(seen.get()).orElseThrow();
            }
            if (qty <= 0 || side == null) {
                throw new CommandRejected(Rejection.INVALID_AMOUNT);
            }
            long id = paper.nextId();
            runAt(ex, new Command.Publish(new Event.PaperPositionOpened(clock.now(), id, accountId, symbol, side, qty,
                    q.price(), q.asOf(), q.source().id(), idempotencyKey)), clock.now());
            return paper.get(id).orElseThrow();
        });
    }

    @Override
    public PaperBook.Position closePaper(String accountId, long paperId) {
        return sequencer.call(ex -> {
            PaperBook.Position p = paper.get(paperId).orElseThrow(() -> new CommandRejected(Rejection.UNKNOWN_POSITION));
            if (!p.account().equals(accountId)) {
                throw new CommandRejected(Rejection.NOT_OWNER);
            }
            if (!p.open()) {
                throw new CommandRejected(Rejection.NOT_OPEN);
            }
            RealMarketData.Quote q = realData.quote(p.symbol()).orElseThrow(() -> new CommandRejected(Rejection.UNKNOWN_INSTRUMENT));
            runAt(ex, new Command.Publish(new Event.PaperPositionClosed(clock.now(), paperId, accountId, q.price(), q.asOf())),
                    clock.now());
            return paper.get(paperId).orElseThrow();
        });
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
        economy.onEvents(events);
        paper.onEvents(events);
        candles.onEvents(events);
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
