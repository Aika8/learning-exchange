package engine;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Deque;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * The exchange's write model: accounts ({@link Ledger}) plus one {@link OrderBook} per instrument. It turns
 * {@link Command commands} into {@link Event events} and is the only thing that changes balances or books.
 *
 * <p>Deterministic: the same commands with the same timestamps always give the same events, which is what makes
 * replay work (intent 02, invariant 4). No clock, no I/O, no threads.
 *
 * <p>Pattern: Event Sourcing (write side) — every change is described by an event, and {@link #replay} rebuilds the
 * state from them. See docs/adr/0005-event-sourcing-journal.md.
 *
 * <p>Not thread-safe: one sequencer thread owns it. See docs/adr/0006-single-writer-and-sim-clock.md.
 *
 * <p>M2a: conditional orders, stop-out and savings live here too, outside the books (ADR-0008). Every trade price
 * goes into a queue; after each command the queue is drained: each price is shown to the conditional orders and to
 * the margin monitor, whose orders may trade and add more prices (a cascade), all inside the same command.
 * Pattern: Observer (trade prices → stops and margin monitor), on the single writer so a cascade stays deterministic.
 */
public final class Exchange {

    private static final int TRADES_KEPT = 500;
    private static final int CASCADE_LIMIT = 100_000;
    private static final int MAX_ACCRUAL_DAYS = 36_500;

    private final Ledger ledger = new Ledger();
    private final Map<String, Market> markets = new LinkedHashMap<>();
    private final Map<Long, OrderState> orders = new HashMap<>();
    private final Map<String, Long> idempotency = new HashMap<>();
    private final Map<String, String> names = new LinkedHashMap<>();
    private final Map<Long, Conditional> conditionals = new LinkedHashMap<>();
    private final Map<Long, Position> positions = new LinkedHashMap<>();
    private final Map<Long, Savings> savings = new LinkedHashMap<>();
    private final Deque<PriceTick> pendingPrices = new ArrayDeque<>();
    private long nextOrderId = 1;
    private long nextTradeId = 1;
    private long nextConditionalId = 1;
    private long nextPositionId = 1;
    private long nextDepositId = 1;

    public Exchange(List<Instrument> instruments) {
        ledger.open(Ledger.FEES_ACCOUNT);
        ledger.open(Ledger.BANK_ACCOUNT);
        for (Instrument i : instruments) {
            markets.put(i.id(), new Market(i));
        }
    }

    /** Applies one command at simulation time {@code ts}. */
    public Outcome execute(Command command, long ts) {
        return switch (command) {
            case Command.OpenAccount c -> openAccount(c, ts);
            case Command.Deposit c -> deposit(c, ts);
            case Command.PlaceOrder c -> place(c, ts);
            case Command.CancelOrder c -> cancel(c, ts);
            case Command.PlaceConditional c -> placeConditional(c, ts);
            case Command.CancelConditional c -> cancelConditional(c, ts);
            case Command.OpenMargin c -> openMargin(c, ts);
            case Command.CloseMargin c -> closeMargin(c, ts);
            case Command.OpenSavings c -> openSavings(c, ts);
            case Command.CloseSavings c -> closeSavings(c, ts);
            case Command.AccrueInterest c -> accrueInterest(ts);
            case Command.Publish c -> Outcome.ok(List.of(c.disclosure()), 0);
            case Command.SetTradingStatus c -> setTradingStatus(c, ts);
            case Command.Payout c -> payout(c, ts);
            case Command.DeclareDefault c -> declareDefault(c, ts);
        };
    }

    /**
     * Rebuilds an exchange from a journal. Decisions are executed again; consequences (trades, expiries) must come
     * out exactly as journalled, otherwise the journal and the engine disagree and replay fails loudly.
     */
    public static Exchange replay(List<Instrument> instruments, Iterable<Event> journal) {
        Exchange exchange = new Exchange(instruments);
        Deque<Event> expected = new ArrayDeque<>();
        for (Event event : journal) {
            if (!expected.isEmpty()) {
                Event produced = expected.pollFirst();
                if (!event.equals(produced)) {
                    throw new IllegalStateException("replay diverged: journal has " + event + ", engine produced " + produced);
                }
                continue;
            }
            if (event instanceof Event.ClockChanged) {
                continue;
            }
            Command command = toCommand(event);
            Outcome outcome = exchange.execute(command, event.ts());
            if (!outcome.accepted() || outcome.events().isEmpty() || !outcome.events().getFirst().equals(event)) {
                throw new IllegalStateException("replay diverged at " + event + ": " + outcome);
            }
            expected.addAll(outcome.events().subList(1, outcome.events().size()));
        }
        if (!expected.isEmpty()) {
            throw new IllegalStateException("replay diverged: journal ends before " + expected.peekFirst());
        }
        return exchange;
    }

    // ---- queries ----

    public Ledger ledger() {
        return ledger;
    }

    public boolean hasAccount(String account) {
        return ledger.exists(account);
    }

    public Optional<String> accountName(String account) {
        return Optional.ofNullable(names.get(account));
    }

    public List<Instrument> instruments() {
        return markets.values().stream().map(m -> m.instrument).toList();
    }

    public Optional<Instrument> instrument(String id) {
        Market m = markets.get(id);
        return m == null ? Optional.empty() : Optional.of(m.instrument);
    }

    public List<OrderBook.Level> bids(String instrument, int depth) {
        return market(instrument).book.bids(depth);
    }

    public List<OrderBook.Level> asks(String instrument, int depth) {
        return market(instrument).book.asks(depth);
    }

    /** Price of the last trade, if any. */
    public Optional<Long> lastPrice(String instrument) {
        Market m = market(instrument);
        return m.trades.isEmpty() ? Optional.empty() : Optional.of(m.trades.getLast().price());
    }

    /** Most recent trades, newest first. */
    public List<Event.TradeExecuted> recentTrades(String instrument, int limit) {
        List<Event.TradeExecuted> all = market(instrument).trades;
        List<Event.TradeExecuted> out = new ArrayList<>(all.subList(Math.max(0, all.size() - limit), all.size()));
        Collections.reverse(out);
        return out;
    }

    public Optional<OrderView> order(long orderId) {
        OrderState s = orders.get(orderId);
        return s == null ? Optional.empty() : Optional.of(s.view());
    }

    /** Orders of one account, newest first; {@code openOnly} keeps NEW and PARTIALLY_FILLED. */
    public List<OrderView> ordersOf(String account, boolean openOnly, int limit) {
        return orders.values().stream()
                .filter(s -> s.account.equals(account))
                .map(OrderState::view)
                .filter(v -> !openOnly || v.open())
                .sorted((a, b) -> Long.compare(b.orderId(), a.orderId()))
                .limit(limit)
                .toList();
    }

    /** Quote reserved by open buys + base reserved by open sells of one account, as tracked per order. */
    public long reservedByOpenOrders(String account, String asset) {
        long sum = 0;
        for (OrderState s : orders.values()) {
            if (s.account.equals(account) && s.isOpen()) {
                Instrument i = markets.get(s.instrument).instrument;
                String reservedAsset = s.side == Order.Side.BUY ? i.quote() : i.base();
                if (reservedAsset.equals(asset)) {
                    sum += s.reservedLeft;
                }
            }
        }
        return sum;
    }

    public List<ConditionalView> conditionalsOf(String account, int limit) {
        List<ConditionalView> out = new ArrayList<>();
        for (Conditional k : conditionals.values()) {
            if (k.account.equals(account)) {
                out.add(conditionalView(k));
            }
        }
        Collections.reverse(out);
        return out.subList(0, Math.min(limit, out.size()));
    }

    public Optional<ConditionalView> conditional(long id) {
        Conditional k = conditionals.get(id);
        return k == null ? Optional.empty() : Optional.of(conditionalView(k));
    }

    /** Combines the rule's phase with what happened to the order it generated. */
    ConditionalView conditionalView(Conditional k) {
        ConditionalView.State state;
        long filled = 0;
        OrderState o = k.orderId == 0 ? null : orders.get(k.orderId);
        if (o != null) {
            filled = o.filled;
        }
        state = switch (k.phase) {
            case WAITING -> ConditionalView.State.WAITING;
            case ARMED -> ConditionalView.State.ARMED;
            case CANCELLED -> ConditionalView.State.CANCELLED;
            case TRIGGERED -> {
                if (o == null) {
                    yield k.rejection != null ? ConditionalView.State.REJECTED : ConditionalView.State.TRIGGERED;
                }
                yield switch (o.status) {
                    case NEW -> ConditionalView.State.SUBMITTED;
                    case PARTIALLY_FILLED -> ConditionalView.State.PARTIALLY_FILLED;
                    case FILLED -> ConditionalView.State.FILLED;
                    case CANCELLED, EXPIRED -> o.filled > 0 ? ConditionalView.State.PARTIALLY_FILLED : ConditionalView.State.UNFILLED;
                };
            }
        };
        boolean armedOnce = k.bestPrice != 0;
        boolean fired = k.phase == Conditional.Phase.TRIGGERED;
        return new ConditionalView(k.id, k.account, k.instrument, k.kind, k.side, k.qty, k.triggerPrice, k.limitPrice,
                k.activationPrice, k.offset, k.protectiveSpread, state, armedOnce ? k.bestPrice : null,
                fired ? k.triggeredTs : null, fired ? k.triggerTradePrice : null, k.orderId == 0 ? null : k.orderId,
                filled, k.rejection, k.createdTs);
    }

    public List<MarginView> positionsOf(String account, int limit) {
        List<MarginView> out = new ArrayList<>();
        for (Position p : positions.values()) {
            if (p.owner.equals(account)) {
                out.add(positionView(p));
            }
        }
        Collections.reverse(out);
        return out.subList(0, Math.min(limit, out.size()));
    }

    public Optional<MarginView> position(long id) {
        Position p = positions.get(id);
        return p == null ? Optional.empty() : Optional.of(positionView(p));
    }

    private MarginView positionView(Position p) {
        Instrument i = markets.get(p.instrument).instrument;
        Long last = lastPrice(p.instrument).orElse(null);
        long equity = p.status == MarginView.Status.CLOSED ? 0 : equity(p, last == null ? p.entryPrice : last);
        Long stopOutPrice = p.status == MarginView.Status.CLOSED ? null : stopOutPrice(p, i);
        return new MarginView(p.id, p.owner, p.instrument, p.side, p.qty, p.leverage, p.collateral, p.loanQuote,
                p.loanBase, p.entryPrice, last, equity, p.collateral / 2, stopOutPrice, p.status, p.closeReason,
                p.status == MarginView.Status.CLOSED ? p.returned : null,
                p.status == MarginView.Status.CLOSED ? p.badDebt : null, p.openedTs,
                p.status == MarginView.Status.CLOSED ? p.closedTs : null);
    }

    public List<SavingsView> savingsOf(String account) {
        List<SavingsView> out = new ArrayList<>();
        for (Savings d : savings.values()) {
            if (d.owner.equals(account)) {
                out.add(savingsView(d));
            }
        }
        Collections.reverse(out);
        return out;
    }

    public Optional<SavingsView> deposit(long id) {
        Savings d = savings.get(id);
        return d == null ? Optional.empty() : Optional.of(savingsView(d));
    }

    private SavingsView savingsView(Savings d) {
        long balance = d.open ? ledger.available(d.sub, d.asset) : d.payout;
        return new SavingsView(d.id, d.owner, d.asset, d.principal, balance, d.rateBps, d.open, d.openedTs,
                d.open ? null : d.closedTs);
    }

    /** A text fingerprint of the whole state, for "replay gives the same state" checks. */
    public String fingerprint() {
        StringBuilder sb = new StringBuilder();
        for (String account : ledger.accountIds()) {
            sb.append(account).append(ledger.balances(account)).append('\n');
        }
        for (Market m : markets.values()) {
            sb.append(m.instrument.id()).append(m.open ? " open" : " closed").append(m.defaulted ? " defaulted" : "").append(" bids ").append(m.book.bids(Integer.MAX_VALUE))
                    .append(" asks ").append(m.book.asks(Integer.MAX_VALUE)).append('\n');
        }
        orders.values().stream().map(OrderState::view).sorted((a, b) -> Long.compare(a.orderId(), b.orderId()))
                .forEach(v -> sb.append(v).append('\n'));
        conditionals.values().forEach(k -> sb.append(conditionalView(k)).append('\n'));
        positions.values().forEach(p -> sb.append(positionView(p)).append('\n'));
        savings.values().forEach(d -> sb.append(savingsView(d)).append(d.lastAccrualTs).append('\n'));
        return sb.append(nextOrderId).append('/').append(nextTradeId).append('/').append(nextConditionalId)
                .append('/').append(nextPositionId).append('/').append(nextDepositId).toString();
    }

    // ---- commands ----

    private Outcome openAccount(Command.OpenAccount c, long ts) {
        if (ledger.exists(c.account())) {
            return Outcome.rejected(Rejection.ACCOUNT_EXISTS);
        }
        ledger.open(c.account());
        names.put(c.account(), c.name());
        return Outcome.ok(List.of(new Event.AccountOpened(ts, c.account(), c.name())), 0);
    }

    private Outcome deposit(Command.Deposit c, long ts) {
        if (!ledger.exists(c.account())) {
            return Outcome.rejected(Rejection.UNKNOWN_ACCOUNT);
        }
        if (c.amount() <= 0 || c.asset() == null) {
            return Outcome.rejected(Rejection.INVALID_AMOUNT);
        }
        ledger.deposit(c.account(), c.asset(), c.amount());
        return Outcome.ok(List.of(new Event.FundsDeposited(ts, c.account(), c.asset(), c.amount())), 0);
    }

    private Outcome place(Command.PlaceOrder c, long ts) {
        if (!ledger.exists(c.account()) || Accounts.isSubAccount(c.account())) {
            return Outcome.rejected(Rejection.UNKNOWN_ACCOUNT);
        }
        String key = idempotencyKey("O", c.account(), c.idempotencyKey());
        if (key != null && idempotency.containsKey(key)) {
            return Outcome.ok(List.of(), idempotency.get(key));
        }
        if (closed(c.instrument())) {
            return Outcome.rejected(Rejection.MARKET_CLOSED);
        }
        List<Event> events = new ArrayList<>();
        Placed placed = placeInto(c, ts, events);
        if (placed.rejection() != null) {
            return Outcome.rejected(placed.rejection());
        }
        if (key != null) {
            idempotency.put(key, placed.orderId());
        }
        drain(ts, events);
        return Outcome.ok(events, placed.orderId());
    }

    private record Placed(long orderId, Rejection rejection) {}

    /**
     * Risk check, reservation, matching and settlement of one ordinary order, for people and for the exchange's own
     * generated orders (fired stops, margin opens and closes) alike: same checks, same fees. Appends its events;
     * trade prices go to {@link #pendingPrices} for {@link #drain}.
     */
    private Placed placeInto(Command.PlaceOrder c, long ts, List<Event> events) {
        Market m = markets.get(c.instrument());
        if (m == null) {
            return new Placed(0, Rejection.UNKNOWN_INSTRUMENT);
        }
        Order order;
        try {
            order = c.type() == Order.Type.LIMIT
                    ? Order.limit(c.side(), c.price(), c.qty())
                    : Order.market(c.side(), c.qty());
        } catch (IllegalArgumentException | NullPointerException e) {
            return new Placed(0, Rejection.INVALID_ORDER);
        }
        Instrument i = m.instrument;

        // Risk check: reserve the most this order can spend before it reaches the book.
        long reserve;
        String reserveAsset;
        try {
            if (c.side() == Order.Side.SELL) {
                if (c.type() == Order.Type.MARKET && m.book.bestBid().isEmpty()) {
                    return new Placed(0, Rejection.NO_LIQUIDITY);
                }
                reserveAsset = i.base();
                reserve = c.qty();
            } else {
                long notional;
                if (c.type() == Order.Type.LIMIT) {
                    notional = Math.multiplyExact(c.price(), c.qty());
                } else {
                    if (m.book.bestAsk().isEmpty()) {
                        return new Placed(0, Rejection.NO_LIQUIDITY);
                    }
                    notional = costToBuy(m.book, c.qty());
                }
                reserveAsset = i.quote();
                reserve = Math.addExact(notional, i.fee(notional));
            }
        } catch (ArithmeticException e) {
            return new Placed(0, Rejection.INVALID_ORDER);
        }
        if (!ledger.reserve(c.account(), reserveAsset, reserve)) {
            return new Placed(0, Rejection.INSUFFICIENT_FUNDS);
        }

        long mid = mid(m.book);
        long orderId = nextOrderId++;
        SubmitResult result = m.book.submit(order);
        m.byBookId.put(result.orderId(), orderId);
        OrderState taker = new OrderState(orderId, result.orderId(), c, reserve, ts);
        orders.put(orderId, taker);

        events.add(new Event.OrderAccepted(ts, orderId, c.account(), i.id(), c.side(), c.type(),
                c.type() == Order.Type.LIMIT ? c.price() : 0, c.qty(), c.idempotencyKey()));
        for (Trade t : result.trades()) {
            events.add(settle(m, t, ts, mid));
        }
        long remaining = taker.qty - taker.filled;
        if (c.type() == Order.Type.MARKET && remaining > 0) {
            taker.status = OrderView.Status.EXPIRED;
            events.add(new Event.OrderExpired(ts, orderId, c.account(), remaining));
        }
        if (!taker.isOpen()) {
            ledger.release(taker.account, reserveAsset, taker.reservedLeft);
            taker.reservedLeft = 0;
        }
        return new Placed(orderId, null);
    }

    /**
     * Shows every new trade price, in order, to the conditional orders and the margin monitor. Their orders may
     * trade and add prices; the loop runs until the cascade settles (ADR-0008).
     */
    private void drain(long ts, List<Event> events) {
        int steps = 0;
        while (!pendingPrices.isEmpty()) {
            if (++steps > CASCADE_LIMIT) {
                throw new IllegalStateException("cascade did not settle");
            }
            PriceTick tick = pendingPrices.pollFirst();
            for (Conditional k : List.copyOf(conditionals.values())) {
                if (!k.live() || !k.instrument.equals(tick.instrument())) {
                    continue;
                }
                switch (k.onTrade(tick.price())) {
                    case Conditional.Nothing n -> { }
                    case Conditional.Armed a -> events.add(new Event.ConditionalArmed(ts, k.id, k.account, tick.price()));
                    case Conditional.Fired f -> fire(k, f.order(), ts, events);
                }
            }
            for (Position p : List.copyOf(positions.values())) {
                if (!p.instrument.equals(tick.instrument()) || p.status == MarginView.Status.CLOSED) {
                    continue;
                }
                if (p.status == MarginView.Status.OPEN) {
                    long equity = equity(p, tick.price());
                    // Intent 02, invariant 6: close before the owner loses more than half of the collateral.
                    if (Math.multiplyExact(equity, 2) <= p.collateral) {
                        p.status = MarginView.Status.CLOSING;
                        p.closeReason = "STOP_OUT";
                        events.add(new Event.MarginStopOut(ts, p.id, p.owner, tick.price(), equity, p.collateral));
                        tryClose(p, ts, events);
                    }
                } else {
                    tryClose(p, ts, events);
                }
            }
        }
    }

    private void fire(Conditional k, Conditional.Fire f, long ts, List<Event> events) {
        k.triggeredTs = ts;
        int slot = events.size();
        events.add(null); // the trigger is told before the order it generated
        Placed placed = f.type() == Order.Type.LIMIT && f.price() <= 0
                ? new Placed(0, Rejection.INVALID_ORDER)
                : placeInto(new Command.PlaceOrder(k.account, k.instrument, k.side, f.type(), f.price(), k.qty, null), ts, events);
        k.orderId = placed.orderId();
        k.rejection = placed.rejection() == null ? null : placed.rejection().name();
        events.set(slot, new Event.ConditionalTriggered(ts, k.id, k.account, k.triggerTradePrice, k.orderId, k.rejection));
    }

    private static long mid(OrderBook book) {
        Optional<Long> bid = book.bestBid();
        Optional<Long> ask = book.bestAsk();
        return bid.isPresent() && ask.isPresent() ? (bid.get() + ask.get()) / 2 : 0;
    }

    private Event.TradeExecuted settle(Market m, Trade t, long ts, long mid) {
        Instrument i = m.instrument;
        OrderState buy = orders.get(m.byBookId.get(t.buyOrderId()));
        OrderState sell = orders.get(m.byBookId.get(t.sellOrderId()));
        long notional = Math.multiplyExact(t.price(), t.qty());
        long buyerFee = i.fee(notional);
        long sellerFee = i.fee(notional);

        ledger.settleFromReserved(buy.account, sell.account, i.quote(), notional - sellerFee);
        ledger.settleFromReserved(buy.account, Ledger.FEES_ACCOUNT, i.quote(), buyerFee + sellerFee);
        buy.reservedLeft -= notional + buyerFee;
        ledger.settleFromReserved(sell.account, buy.account, i.base(), t.qty());
        sell.reservedLeft -= t.qty();

        for (OrderState s : List.of(buy, sell)) {
            s.filled += t.qty();
            s.status = s.filled == s.qty ? OrderView.Status.FILLED : OrderView.Status.PARTIALLY_FILLED;
        }
        // A resting order that is now complete gives back what its reservation did not need.
        for (OrderState s : List.of(buy, sell)) {
            if (s.status == OrderView.Status.FILLED && s.reservedLeft > 0) {
                ledger.release(s.account, s.side == Order.Side.BUY ? i.quote() : i.base(), s.reservedLeft);
                s.reservedLeft = 0;
            }
        }

        Event.TradeExecuted e = new Event.TradeExecuted(ts, nextTradeId++, i.id(), buy.orderId, sell.orderId,
                buy.account, sell.account, t.price(), t.qty(), t.aggressorSide(), buyerFee, sellerFee, mid);
        m.trades.add(e);
        pendingPrices.addLast(new PriceTick(i.id(), t.price()));
        if (m.trades.size() > TRADES_KEPT) {
            m.trades.removeFirst();
        }
        return e;
    }

    private Outcome cancel(Command.CancelOrder c, long ts) {
        OrderState s = orders.get(c.orderId());
        if (s == null) {
            return Outcome.rejected(Rejection.UNKNOWN_ORDER);
        }
        if (!s.account.equals(c.account())) {
            return Outcome.rejected(Rejection.NOT_OWNER);
        }
        if (!s.isOpen()) {
            return Outcome.rejected(Rejection.NOT_OPEN);
        }
        Market m = markets.get(s.instrument);
        if (!m.book.cancel(s.bookId)) {
            throw new IllegalStateException("open order not in book: " + s.orderId);
        }
        Instrument i = m.instrument;
        ledger.release(s.account, s.side == Order.Side.BUY ? i.quote() : i.base(), s.reservedLeft);
        s.reservedLeft = 0;
        s.status = OrderView.Status.CANCELLED;
        return Outcome.ok(List.of(new Event.OrderCancelled(ts, s.orderId, s.account, s.qty - s.filled)), s.orderId);
    }

    // ---- conditional orders ----

    private Outcome placeConditional(Command.PlaceConditional c, long ts) {
        if (!ledger.exists(c.account()) || Accounts.isSubAccount(c.account())) {
            return Outcome.rejected(Rejection.UNKNOWN_ACCOUNT);
        }
        if (!markets.containsKey(c.instrument())) {
            return Outcome.rejected(Rejection.UNKNOWN_INSTRUMENT);
        }
        if (closed(c.instrument())) {
            return Outcome.rejected(Rejection.MARKET_CLOSED);
        }
        String key = idempotencyKey("C", c.account(), c.idempotencyKey());
        if (key != null && idempotency.containsKey(key)) {
            return Outcome.ok(List.of(), idempotency.get(key));
        }
        Rejection invalid = Conditional.validate(c);
        if (invalid != null) {
            return Outcome.rejected(invalid);
        }
        long id = nextConditionalId++;
        conditionals.put(id, new Conditional(id, c, ts));
        remember(key, id);
        return Outcome.ok(List.of(new Event.ConditionalPlaced(ts, id, c.account(), c.instrument(), c.kind(), c.side(),
                c.qty(), c.triggerPrice(), c.limitPrice(), c.activationPrice(), c.offset(), c.protectiveSpread(),
                c.idempotencyKey())), id);
    }

    private Outcome cancelConditional(Command.CancelConditional c, long ts) {
        Conditional k = conditionals.get(c.conditionalId());
        if (k == null) {
            return Outcome.rejected(Rejection.UNKNOWN_ORDER);
        }
        if (!k.account.equals(c.account())) {
            return Outcome.rejected(Rejection.NOT_OWNER);
        }
        if (!k.live()) {
            return Outcome.rejected(Rejection.NOT_OPEN);
        }
        k.phase = Conditional.Phase.CANCELLED;
        return Outcome.ok(List.of(new Event.ConditionalCancelled(ts, k.id, k.account)), k.id);
    }

    // ---- leverage ----

    private Outcome openMargin(Command.OpenMargin c, long ts) {
        if (!ledger.exists(c.account()) || Accounts.isSubAccount(c.account())) {
            return Outcome.rejected(Rejection.UNKNOWN_ACCOUNT);
        }
        String key = idempotencyKey("M", c.account(), c.idempotencyKey());
        if (key != null && idempotency.containsKey(key)) {
            return Outcome.ok(List.of(), idempotency.get(key));
        }
        if (closed(c.instrument())) {
            return Outcome.rejected(Rejection.MARKET_CLOSED);
        }
        Market m = markets.get(c.instrument());
        if (m == null) {
            return Outcome.rejected(Rejection.UNKNOWN_INSTRUMENT);
        }
        Instrument i = m.instrument;
        if (i.maxLeverage() < 2 || c.leverage() < 1 || c.leverage() > i.maxLeverage()) {
            return Outcome.rejected(Rejection.LEVERAGE_NOT_ALLOWED);
        }
        if (c.side() == null || c.qty() <= 0) {
            return Outcome.rejected(Rejection.INVALID_ORDER);
        }
        long collateral;
        long loanQuote = 0;
        long loanBase = 0;
        try {
            if (c.side() == Order.Side.BUY) {
                if (depth(m.book.asks(Integer.MAX_VALUE)) < c.qty()) {
                    return Outcome.rejected(Rejection.NO_LIQUIDITY);
                }
                long notional = costToBuy(m.book, c.qty());
                long own = Math.ceilDiv(notional, c.leverage());
                collateral = Math.addExact(own, i.fee(notional)); // the fee is paid from my own money
                loanQuote = notional - own;
            } else {
                if (depth(m.book.bids(Integer.MAX_VALUE)) < c.qty()) {
                    return Outcome.rejected(Rejection.NO_LIQUIDITY);
                }
                collateral = Math.ceilDiv(proceedsOfSell(m.book, c.qty()), c.leverage());
                loanBase = c.qty();
            }
        } catch (ArithmeticException e) {
            return Outcome.rejected(Rejection.INVALID_ORDER);
        }
        if (ledger.available(c.account(), i.quote()) < collateral
                || ledger.available(Ledger.BANK_ACCOUNT, i.quote()) < loanQuote
                || ledger.available(Ledger.BANK_ACCOUNT, i.base()) < loanBase) {
            return Outcome.rejected(Rejection.INSUFFICIENT_FUNDS);
        }

        long id = nextPositionId++;
        String sub = Accounts.marginAccount(c.account(), id);
        ledger.open(sub);
        List<Event> events = new ArrayList<>();
        events.add(new Event.MarginPositionOpened(ts, id, c.account(), i.id(), c.side(), c.qty(), c.leverage(),
                collateral, loanQuote, loanBase, c.idempotencyKey()));
        remember(key, id);
        ledger.transferAvailable(c.account(), sub, i.quote(), collateral);
        ledger.transferAvailable(Ledger.BANK_ACCOUNT, sub, i.quote(), loanQuote);
        ledger.transferAvailable(Ledger.BANK_ACCOUNT, sub, i.base(), loanBase);
        Position p = new Position(id, c.account(), sub, i.id(), c.side(), c.qty(), c.leverage(), collateral, loanQuote,
                loanBase, ts);
        positions.put(id, p);

        int from = events.size();
        Placed placed = placeInto(new Command.PlaceOrder(sub, i.id(), c.side(), Order.Type.MARKET, 0, c.qty(), null), ts, events);
        if (placed.rejection() != null) {
            throw new IllegalStateException("margin open order refused: " + placed.rejection());
        }
        long notional = 0;
        long filled = 0;
        for (Event e : events.subList(from, events.size())) {
            if (e instanceof Event.TradeExecuted t && (t.buyOrderId() == placed.orderId() || t.sellOrderId() == placed.orderId())) {
                notional += t.price() * t.qty();
                filled += t.qty();
            }
        }
        p.entryPrice = filled == 0 ? 0 : notional / filled;
        drain(ts, events);
        return Outcome.ok(events, id);
    }

    private Outcome closeMargin(Command.CloseMargin c, long ts) {
        Position p = positions.get(c.positionId());
        if (p == null) {
            return Outcome.rejected(Rejection.UNKNOWN_POSITION);
        }
        if (!p.owner.equals(c.account())) {
            return Outcome.rejected(Rejection.NOT_OWNER);
        }
        if (p.status != MarginView.Status.OPEN) {
            return Outcome.rejected(Rejection.NOT_OPEN);
        }
        List<Event> events = new ArrayList<>();
        events.add(new Event.MarginCloseRequested(ts, p.id, p.owner));
        p.status = MarginView.Status.CLOSING;
        p.closeReason = "CLOSED";
        tryClose(p, ts, events);
        drain(ts, events);
        return Outcome.ok(events, p.id);
    }

    /** Equity of a position if the last trade were at {@code price}: what is held minus what is owed. */
    private long equity(Position p, long price) {
        Instrument i = markets.get(p.instrument).instrument;
        long quote = ledger.available(p.sub, i.quote()) + ledger.reserved(p.sub, i.quote());
        long base = ledger.available(p.sub, i.base()) + ledger.reserved(p.sub, i.base());
        return quote - p.loanQuote + Math.multiplyExact(base - p.loanBase, price);
    }

    /** The last trade price at which {@code 2 × equity ≤ collateral}; null if the position carries no price risk. */
    private Long stopOutPrice(Position p, Instrument i) {
        long quote = ledger.available(p.sub, i.quote()) + ledger.reserved(p.sub, i.quote());
        long net = ledger.available(p.sub, i.base()) + ledger.reserved(p.sub, i.base()) - p.loanBase;
        if (net == 0) {
            return null;
        }
        long rhs = p.collateral - 2 * (quote - p.loanQuote); // 2·net·price ≤ rhs
        long price = net > 0 ? Math.floorDiv(rhs, 2 * net) : Math.ceilDiv(rhs, 2 * net);
        return price > 0 ? price : null;
    }

    /** Sends the closing market order if one can trade now, then settles if the position is flat. */
    private void tryClose(Position p, long ts, List<Event> events) {
        Market m = markets.get(p.instrument);
        Instrument i = m.instrument;
        if (p.side == Order.Side.BUY) {
            long base = ledger.available(p.sub, i.base());
            if (base > 0 && m.book.bestBid().isPresent()) {
                placeInto(new Command.PlaceOrder(p.sub, i.id(), Order.Side.SELL, Order.Type.MARKET, 0, base, null), ts, events);
            }
            if (ledger.available(p.sub, i.base()) == 0) {
                settle(p, i, ts, events);
            }
        } else {
            long need = p.loanBase - ledger.available(p.sub, i.base());
            if (need > 0 && m.book.bestAsk().isPresent()) {
                long qty = affordable(m.book, i, need, ledger.available(p.sub, i.quote()));
                if (qty > 0) {
                    placeInto(new Command.PlaceOrder(p.sub, i.id(), Order.Side.BUY, Order.Type.MARKET, 0, qty, null), ts, events);
                }
            }
            need = p.loanBase - ledger.available(p.sub, i.base());
            boolean cannotBuyMore = m.book.bestAsk().isPresent()
                    && affordable(m.book, i, 1, ledger.available(p.sub, i.quote())) == 0;
            if (need <= 0 || cannotBuyMore) {
                settle(p, i, ts, events);
            }
        }
    }

    /** Repays the bank as far as possible and returns the rest to the owner. */
    private void settle(Position p, Instrument i, long ts, List<Event> events) {
        long quote = ledger.available(p.sub, i.quote());
        long base = ledger.available(p.sub, i.base());
        long repayQuote = Math.min(p.loanQuote, quote);
        long repayBase = Math.min(p.loanBase, base);
        ledger.transferAvailable(p.sub, Ledger.BANK_ACCOUNT, i.quote(), repayQuote);
        ledger.transferAvailable(p.sub, Ledger.BANK_ACCOUNT, i.base(), repayBase);
        ledger.transferAvailable(p.sub, p.owner, i.quote(), quote - repayQuote);
        ledger.transferAvailable(p.sub, p.owner, i.base(), base - repayBase);
        p.status = MarginView.Status.CLOSED;
        p.returned = quote - repayQuote;
        p.badDebt = p.loanQuote - repayQuote;
        p.closedTs = ts;
        events.add(new Event.MarginPositionClosed(ts, p.id, p.owner, p.closeReason, quote - repayQuote, base - repayBase,
                p.loanQuote - repayQuote, p.loanBase - repayBase));
    }

    // ---- savings ----

    private Outcome openSavings(Command.OpenSavings c, long ts) {
        if (!ledger.exists(c.account()) || Accounts.isSubAccount(c.account())) {
            return Outcome.rejected(Rejection.UNKNOWN_ACCOUNT);
        }
        String key = idempotencyKey("S", c.account(), c.idempotencyKey());
        if (key != null && idempotency.containsKey(key)) {
            return Outcome.ok(List.of(), idempotency.get(key));
        }
        if (c.asset() == null || c.amount() <= 0 || c.rateBps() < 0 || c.rateBps() > 10_000 || c.dayMillis() <= 0) {
            return Outcome.rejected(Rejection.INVALID_AMOUNT);
        }
        if (ledger.available(c.account(), c.asset()) < c.amount()) {
            return Outcome.rejected(Rejection.INSUFFICIENT_FUNDS);
        }
        long id = nextDepositId++;
        String sub = Accounts.savingsAccount(c.account(), id);
        ledger.open(sub);
        ledger.transferAvailable(c.account(), sub, c.asset(), c.amount());
        savings.put(id, new Savings(id, c.account(), sub, c.asset(), c.amount(), c.rateBps(), c.dayMillis(), ts));
        remember(key, id);
        return Outcome.ok(List.of(new Event.SavingsOpened(ts, id, c.account(), c.asset(), c.amount(), c.rateBps(),
                c.dayMillis(), c.idempotencyKey())), id);
    }

    private Outcome closeSavings(Command.CloseSavings c, long ts) {
        Savings d = savings.get(c.depositId());
        if (d == null) {
            return Outcome.rejected(Rejection.UNKNOWN_DEPOSIT);
        }
        if (!d.owner.equals(c.account())) {
            return Outcome.rejected(Rejection.NOT_OWNER);
        }
        if (!d.open) {
            return Outcome.rejected(Rejection.NOT_OPEN);
        }
        long payout = ledger.available(d.sub, d.asset);
        ledger.transferAvailable(d.sub, d.owner, d.asset, payout);
        d.open = false;
        d.payout = payout;
        d.closedTs = ts;
        return Outcome.ok(List.of(new Event.SavingsClosed(ts, d.id, d.owner, payout)), d.id);
    }

    /**
     * Compound interest, daily: each whole bank day adds {@code balance × rate / 365}, rounded down, to the balance,
     * so the next day earns interest on interest. Paid by the bank account: money moves, it is not created.
     * A deposit whose interest rounds to zero keeps its last accrual time, so batching days never changes the sum.
     */
    private Outcome accrueInterest(long ts) {
        List<Event> events = new ArrayList<>();
        for (Savings d : savings.values()) {
            if (!d.open) {
                continue;
            }
            long days = Math.min((ts - d.lastAccrualTs) / d.dayMillis, MAX_ACCRUAL_DAYS);
            if (days <= 0) {
                continue;
            }
            long balance = ledger.available(d.sub, d.asset);
            long total = 0;
            for (long day = 0; day < days; day++) {
                long interest = Math.multiplyExact(balance, d.rateBps) / (10_000L * 365);
                balance += interest;
                total += interest;
            }
            if (total == 0 || ledger.available(Ledger.BANK_ACCOUNT, d.asset) < total) {
                continue;
            }
            ledger.transferAvailable(Ledger.BANK_ACCOUNT, d.sub, d.asset, total);
            d.lastAccrualTs += days * d.dayMillis;
            events.add(new Event.InterestAccrued(ts, d.id, d.owner, total, (int) days, balance));
        }
        return Outcome.ok(events, 0);
    }

    // ---- M2b: trading status, payouts, default (ADR-0021) ----

    private boolean closed(String instrument) {
        Market m = markets.get(instrument);
        return m != null && !m.open;
    }

    public boolean isOpen(String instrument) {
        return !closed(instrument);
    }

    public boolean isDefaulted(String instrument) {
        Market m = markets.get(instrument);
        return m != null && m.defaulted;
    }

    private Outcome setTradingStatus(Command.SetTradingStatus c, long ts) {
        Market m = markets.get(c.instrument());
        if (m == null) {
            return Outcome.rejected(Rejection.UNKNOWN_INSTRUMENT);
        }
        if (m.open == c.open()) {
            return Outcome.ok(List.of(), 0);
        }
        m.open = c.open();
        return Outcome.ok(List.of(new Event.TradingStatusChanged(ts, c.instrument(), c.open(), c.reason())), 0);
    }

    /**
     * Pays every holder of the instrument's base asset (available + reserved, everyone but the issuer and the
     * exchange's own accounts) {@code perUnit} each, from the issuer's available quote asset. Money moves, it is never
     * created: if the issuer cannot pay the whole amount, nothing is paid and the command is refused. A redemption
     * first cancels the open orders on the instrument (releasing reserved units), then takes the units back.
     */
    private Outcome payout(Command.Payout c, long ts) {
        Market m = markets.get(c.instrument());
        if (m == null) {
            return Outcome.rejected(Rejection.UNKNOWN_INSTRUMENT);
        }
        if (!ledger.exists(c.issuer()) || c.perUnit() < 0 || (c.perUnit() == 0 && c.kind() != Event.PayoutKind.REDEMPTION)) {
            return Outcome.rejected(Rejection.INVALID_AMOUNT);
        }
        if (m.defaulted && c.kind() == Event.PayoutKind.COUPON) {
            return Outcome.rejected(Rejection.DEFAULTED);
        }
        Instrument i = m.instrument;
        java.util.Map<String, Long> holders = new java.util.TreeMap<>();
        long units = 0;
        for (String account : ledger.accountIds()) {
            if (account.equals(c.issuer()) || account.equals(Ledger.FEES_ACCOUNT) || account.equals(Ledger.BANK_ACCOUNT)) {
                continue;
            }
            long held = ledger.available(account, i.base()) + ledger.reserved(account, i.base());
            if (held > 0) {
                holders.put(account, held);
                units += held;
            }
        }
        long total;
        try {
            total = Math.multiplyExact(units, c.perUnit());
        } catch (ArithmeticException e) {
            return Outcome.rejected(Rejection.INVALID_AMOUNT);
        }
        if (ledger.available(c.issuer(), i.quote()) < total) {
            return Outcome.rejected(Rejection.INSUFFICIENT_FUNDS);
        }
        List<Event> events = new ArrayList<>();
        events.add(new Event.PayoutStarted(ts, i.id(), c.kind(), c.issuer(), c.perUnit(), units, total));
        if (c.kind() == Event.PayoutKind.REDEMPTION) {
            for (OrderState o : orders.values().stream().filter(o -> o.isOpen() && o.instrument.equals(i.id()))
                    .sorted(java.util.Comparator.comparingLong(o -> o.orderId)).toList()) {
                events.addAll(cancel(new Command.CancelOrder(o.account, o.orderId), ts).events());
            }
            m.open = false;
        }
        for (var h : holders.entrySet()) {
            long amount = h.getValue() * c.perUnit();
            if (amount > 0) {
                ledger.transferAvailable(c.issuer(), h.getKey(), i.quote(), amount);
            }
            if (c.kind() == Event.PayoutKind.REDEMPTION) {
                ledger.transferAvailable(h.getKey(), c.issuer(), i.base(), h.getValue());
            }
            events.add(new Event.PayoutPaid(ts, i.id(), c.kind(), h.getKey(), h.getValue(), amount));
        }
        if (c.kind() == Event.PayoutKind.REDEMPTION) {
            events.add(new Event.TradingStatusChanged(ts, i.id(), false, "REDEEMED"));
        }
        return Outcome.ok(events, 0);
    }

    private Outcome declareDefault(Command.DeclareDefault c, long ts) {
        Market m = markets.get(c.instrument());
        if (m == null) {
            return Outcome.rejected(Rejection.UNKNOWN_INSTRUMENT);
        }
        if (m.defaulted) {
            return Outcome.rejected(Rejection.DEFAULTED);
        }
        m.defaulted = true;
        return Outcome.ok(List.of(new Event.BondDefaulted(ts, c.instrument(), c.issuer())), 0);
    }

    /** What buying {@code qty} at market costs now, walking the asks (only the available part if the book is thin). */
    private static long costToBuy(OrderBook book, long qty) {
        long cost = 0;
        long left = qty;
        for (OrderBook.Level level : book.asks(Integer.MAX_VALUE)) {
            if (left == 0) {
                break;
            }
            long take = Math.min(left, level.qty());
            cost = Math.addExact(cost, Math.multiplyExact(take, level.price()));
            left -= take;
        }
        return cost;
    }

    /** What selling {@code qty} at market brings now, walking the bids, before the fee. */
    private static long proceedsOfSell(OrderBook book, long qty) {
        long sum = 0;
        long left = qty;
        for (OrderBook.Level level : book.bids(Integer.MAX_VALUE)) {
            if (left == 0) {
                break;
            }
            long take = Math.min(left, level.qty());
            sum = Math.addExact(sum, Math.multiplyExact(take, level.price()));
            left -= take;
        }
        return sum;
    }

    private static long depth(List<OrderBook.Level> side) {
        long sum = 0;
        for (OrderBook.Level l : side) {
            sum += l.qty();
        }
        return sum;
    }

    /** The largest quantity up to {@code max} whose market cost plus fee fits in {@code cash}. */
    private static long affordable(OrderBook book, Instrument i, long max, long cash) {
        long lo = 0;
        long hi = Math.min(max, depth(book.asks(Integer.MAX_VALUE)));
        while (lo < hi) {
            long mid = (lo + hi + 1) / 2;
            long cost = costToBuy(book, mid);
            if (cost + i.fee(cost) <= cash) {
                lo = mid;
            } else {
                hi = mid - 1;
            }
        }
        return lo;
    }

    private static Command toCommand(Event e) {
        return switch (e) {
            case Event.AccountOpened a -> new Command.OpenAccount(a.account(), a.name());
            case Event.FundsDeposited d -> new Command.Deposit(d.account(), d.asset(), d.amount());
            case Event.OrderAccepted o -> new Command.PlaceOrder(o.account(), o.instrument(), o.side(), o.type(),
                    o.price(), o.qty(), o.idempotencyKey());
            case Event.OrderCancelled o -> new Command.CancelOrder(o.account(), o.orderId());
            case Event.ConditionalPlaced c -> new Command.PlaceConditional(c.account(), c.instrument(), c.kind(),
                    c.side(), c.qty(), c.triggerPrice(), c.limitPrice(), c.activationPrice(), c.offset(), c.protectiveSpread(),
                    c.idempotencyKey());
            case Event.ConditionalCancelled c -> new Command.CancelConditional(c.account(), c.conditionalId());
            case Event.MarginPositionOpened m -> new Command.OpenMargin(m.account(), m.instrument(), m.side(), m.qty(), m.leverage(),
                    m.idempotencyKey());
            case Event.MarginCloseRequested m -> new Command.CloseMargin(m.account(), m.positionId());
            case Event.SavingsOpened s -> new Command.OpenSavings(s.account(), s.asset(), s.amount(), s.rateBps(), s.dayMillis(),
                    s.idempotencyKey());
            case Event.SavingsClosed s -> new Command.CloseSavings(s.account(), s.depositId());
            case Event.InterestAccrued i -> new Command.AccrueInterest();
            case Event.Disclosure d -> new Command.Publish(d);
            case Event.TradingStatusChanged t -> new Command.SetTradingStatus(t.instrument(), t.open(), t.reason());
            case Event.PayoutStarted p -> new Command.Payout(p.instrument(), p.kind(), p.issuer(), p.perUnit());
            case Event.BondDefaulted b -> new Command.DeclareDefault(b.instrument(), b.issuer());
            case Event.PayoutPaid p -> throw unexpected(p);
            case Event.ClockChanged c -> throw new IllegalStateException("not a command: " + c);
            case Event.TradeExecuted t -> throw unexpected(t);
            case Event.OrderExpired o -> throw unexpected(o);
            case Event.ConditionalArmed c -> throw unexpected(c);
            case Event.ConditionalTriggered c -> throw unexpected(c);
            case Event.MarginStopOut m -> throw unexpected(m);
            case Event.MarginPositionClosed m -> throw unexpected(m);
        };
    }

    /**
     * Pattern: Idempotency key — a client retrying a POST after a timeout must not open a second stop, position or
     * deposit. Keys are scoped by account and by kind of command, so one key can't clash across endpoints.
     */
    private static String idempotencyKey(String kind, String account, String clientKey) {
        return clientKey == null || clientKey.isBlank() ? null : kind + "|" + account + "|" + clientKey;
    }

    private void remember(String key, long id) {
        if (key != null) {
            idempotency.put(key, id);
        }
    }

    private static IllegalStateException unexpected(Event consequence) {
        return new IllegalStateException("replay diverged: consequence without its command: " + consequence);
    }

    private Market market(String instrument) {
        Market m = markets.get(instrument);
        if (m == null) {
            throw new IllegalArgumentException("unknown instrument: " + instrument);
        }
        return m;
    }

    private record PriceTick(String instrument, long price) {}

    /** A leveraged position: its sub-account holds collateral, loans and whatever the orders bought or sold. */
    private static final class Position {
        final long id;
        final String owner;
        final String sub;
        final String instrument;
        final Order.Side side;
        final long qty;
        final int leverage;
        final long collateral;
        final long loanQuote;
        final long loanBase;
        final long openedTs;
        long entryPrice;
        MarginView.Status status = MarginView.Status.OPEN;
        String closeReason;
        long returned;
        long badDebt;
        long closedTs;

        Position(long id, String owner, String sub, String instrument, Order.Side side, long qty, int leverage,
                 long collateral, long loanQuote, long loanBase, long openedTs) {
            this.id = id;
            this.owner = owner;
            this.sub = sub;
            this.instrument = instrument;
            this.side = side;
            this.qty = qty;
            this.leverage = leverage;
            this.collateral = collateral;
            this.loanQuote = loanQuote;
            this.loanBase = loanBase;
            this.openedTs = openedTs;
        }
    }

    private static final class Savings {
        final long id;
        final String owner;
        final String sub;
        final String asset;
        final long principal;
        final long rateBps;
        final long dayMillis;
        final long openedTs;
        long lastAccrualTs;
        boolean open = true;
        long payout;
        long closedTs;

        Savings(long id, String owner, String sub, String asset, long principal, long rateBps, long dayMillis, long ts) {
            this.id = id;
            this.owner = owner;
            this.sub = sub;
            this.asset = asset;
            this.principal = principal;
            this.rateBps = rateBps;
            this.dayMillis = dayMillis;
            this.openedTs = ts;
            this.lastAccrualTs = ts;
        }
    }

    private static final class Market {
        final Instrument instrument;
        boolean open = true;
        boolean defaulted;
        final OrderBook book = new OrderBook();
        final Map<Long, Long> byBookId = new HashMap<>();
        final List<Event.TradeExecuted> trades = new ArrayList<>();

        Market(Instrument instrument) {
            this.instrument = instrument;
        }
    }

    private static final class OrderState {
        final long orderId;
        final long bookId;
        final String account;
        final String instrument;
        final Order.Side side;
        final Order.Type type;
        final long price;
        final long qty;
        final long createdTs;
        long filled;
        long reservedLeft;
        OrderView.Status status = OrderView.Status.NEW;

        OrderState(long orderId, long bookId, Command.PlaceOrder c, long reserved, long ts) {
            this.orderId = orderId;
            this.bookId = bookId;
            this.account = c.account();
            this.instrument = c.instrument();
            this.side = c.side();
            this.type = c.type();
            this.price = c.type() == Order.Type.LIMIT ? c.price() : 0;
            this.qty = c.qty();
            this.reservedLeft = reserved;
            this.createdTs = ts;
        }

        boolean isOpen() {
            return status == OrderView.Status.NEW || status == OrderView.Status.PARTIALLY_FILLED;
        }

        OrderView view() {
            return new OrderView(orderId, account, instrument, side, type, price, qty, filled, status, createdTs);
        }
    }
}
