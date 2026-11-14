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
 */
public final class Exchange {

    private static final int TRADES_KEPT = 500;

    private final Ledger ledger = new Ledger();
    private final Map<String, Market> markets = new LinkedHashMap<>();
    private final Map<Long, OrderState> orders = new HashMap<>();
    private final Map<String, Long> idempotency = new HashMap<>();
    private final Map<String, String> names = new LinkedHashMap<>();
    private long nextOrderId = 1;
    private long nextTradeId = 1;

    public Exchange(List<Instrument> instruments) {
        ledger.open(Ledger.FEES_ACCOUNT);
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
            if (!event.isDecision()) {
                Event produced = expected.pollFirst();
                if (!event.equals(produced)) {
                    throw new IllegalStateException("replay diverged: journal has " + event + ", engine produced " + produced);
                }
                continue;
            }
            if (!expected.isEmpty()) {
                throw new IllegalStateException("replay diverged: engine produced unjournalled " + expected.peekFirst());
            }
            Command command = toCommand(event);
            if (command == null) {
                continue;
            }
            Outcome outcome = exchange.execute(command, event.ts());
            if (!outcome.accepted() || !outcome.events().getFirst().equals(event)) {
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

    /** A text fingerprint of the whole state, for "replay gives the same state" checks. */
    public String fingerprint() {
        StringBuilder sb = new StringBuilder();
        for (String account : ledger.accountIds()) {
            sb.append(account).append(ledger.balances(account)).append('\n');
        }
        for (Market m : markets.values()) {
            sb.append(m.instrument.id()).append(" bids ").append(m.book.bids(Integer.MAX_VALUE))
                    .append(" asks ").append(m.book.asks(Integer.MAX_VALUE)).append('\n');
        }
        orders.values().stream().map(OrderState::view).sorted((a, b) -> Long.compare(a.orderId(), b.orderId()))
                .forEach(v -> sb.append(v).append('\n'));
        return sb.append(nextOrderId).append('/').append(nextTradeId).toString();
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
        if (!ledger.exists(c.account())) {
            return Outcome.rejected(Rejection.UNKNOWN_ACCOUNT);
        }
        String key = c.idempotencyKey() == null || c.idempotencyKey().isBlank() ? null : c.account() + "|" + c.idempotencyKey();
        if (key != null && idempotency.containsKey(key)) {
            return Outcome.ok(List.of(), idempotency.get(key));
        }
        Market m = markets.get(c.instrument());
        if (m == null) {
            return Outcome.rejected(Rejection.UNKNOWN_INSTRUMENT);
        }
        Order order;
        try {
            order = c.type() == Order.Type.LIMIT
                    ? Order.limit(c.side(), c.price(), c.qty())
                    : Order.market(c.side(), c.qty());
        } catch (IllegalArgumentException | NullPointerException e) {
            return Outcome.rejected(Rejection.INVALID_ORDER);
        }
        Instrument i = m.instrument;

        // Risk check: reserve the most this order can spend before it reaches the book.
        long reserve;
        String reserveAsset;
        try {
            if (c.side() == Order.Side.SELL) {
                if (c.type() == Order.Type.MARKET && m.book.bestBid().isEmpty()) {
                    return Outcome.rejected(Rejection.NO_LIQUIDITY);
                }
                reserveAsset = i.base();
                reserve = c.qty();
            } else {
                long notional;
                if (c.type() == Order.Type.LIMIT) {
                    notional = Math.multiplyExact(c.price(), c.qty());
                } else {
                    if (m.book.bestAsk().isEmpty()) {
                        return Outcome.rejected(Rejection.NO_LIQUIDITY);
                    }
                    notional = costToBuy(m.book, c.qty());
                }
                reserveAsset = i.quote();
                reserve = Math.addExact(notional, i.fee(notional));
            }
        } catch (ArithmeticException e) {
            return Outcome.rejected(Rejection.INVALID_ORDER);
        }
        if (!ledger.reserve(c.account(), reserveAsset, reserve)) {
            return Outcome.rejected(Rejection.INSUFFICIENT_FUNDS);
        }

        long orderId = nextOrderId++;
        SubmitResult result = m.book.submit(order);
        m.byBookId.put(result.orderId(), orderId);
        OrderState taker = new OrderState(orderId, result.orderId(), c, reserve, ts);
        orders.put(orderId, taker);
        if (key != null) {
            idempotency.put(key, orderId);
        }

        List<Event> events = new ArrayList<>();
        events.add(new Event.OrderAccepted(ts, orderId, c.account(), i.id(), c.side(), c.type(),
                c.type() == Order.Type.LIMIT ? c.price() : 0, c.qty(), c.idempotencyKey()));
        for (Trade t : result.trades()) {
            events.add(settle(m, t, ts));
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
        return Outcome.ok(events, orderId);
    }

    private Event.TradeExecuted settle(Market m, Trade t, long ts) {
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
                buy.account, sell.account, t.price(), t.qty(), t.aggressorSide(), buyerFee, sellerFee);
        m.trades.add(e);
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

    private static Command toCommand(Event e) {
        return switch (e) {
            case Event.AccountOpened a -> new Command.OpenAccount(a.account(), a.name());
            case Event.FundsDeposited d -> new Command.Deposit(d.account(), d.asset(), d.amount());
            case Event.OrderAccepted o -> new Command.PlaceOrder(o.account(), o.instrument(), o.side(), o.type(),
                    o.price(), o.qty(), o.idempotencyKey());
            case Event.OrderCancelled o -> new Command.CancelOrder(o.account(), o.orderId());
            case Event.ClockChanged ignored -> null;
            case Event.TradeExecuted ignored -> null;
            case Event.OrderExpired ignored -> null;
        };
    }

    private Market market(String instrument) {
        Market m = markets.get(instrument);
        if (m == null) {
            throw new IllegalArgumentException("unknown instrument: " + instrument);
        }
        return m;
    }

    private static final class Market {
        final Instrument instrument;
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
