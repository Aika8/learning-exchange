package application;

import engine.Accounts;
import engine.Event;
import engine.Instrument;
import engine.Ledger;
import engine.Order;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The statement read model: every operation of a person with its fee, the spread paid against the mid, realised
 * profit (average-cost method) and the 10% tax on the period's realised profit. Built only from journalled events —
 * on start from the whole journal, then from each new batch — and never consulted by the write side.
 *
 * <p>Pattern: Event Sourcing projection / CQRS read model. See docs/adr/0005-event-sourcing-journal.md.
 *
 * <p>Not thread-safe: fed and queried on the sequencer thread.
 */
public final class StatementProjection implements MarketListener {

    /** 10% income tax on realised trading profit (vault: finance/fx-market-kz.md, ИПН). */
    public static final long TAX_RATE_BPS = 1_000;
    /** Lines kept per person; older ones drop out (bots trade all day). */
    static final int LINES_KEPT = 20_000;

    public enum Kind { DEPOSIT, TRADE, MARGIN_OPEN, MARGIN_CLOSE, STOP_OUT, SAVINGS_OPEN, SAVINGS_CLOSE, INTEREST, DIVIDEND, COUPON,
        REDEMPTION }

    /** One statement line; nullable fields do not apply to every kind. All money in minor units. */
    public record Line(long ts, Kind kind, String instrument, Order.Side side, Long price, Long qty, Long mid,
                       String asset, long amount, long fee, long spreadPaid, long realisedPnl, boolean margin, Long refId) {}

    /**
     * {@code payouts}: dividends and coupons received; taxed at 10% like trading profit (ИПН, M2b). {@code tax} =
     * 10% × (max(0, realised profit) + payouts).
     */
    public record Totals(long fees, long spreadPaid, long realisedPnl, long taxRateBps, long tax, long interest,
                         long payouts) {}

    public record Statement(long from, long to, String currency, List<Line> lines, Totals totals) {}

    private final Map<String, Instrument> instruments = new HashMap<>();
    private final Map<String, Instrument> byBase = new HashMap<>();
    private final Map<String, Deque<Line>> lines = new HashMap<>();
    private final Map<String, long[]> basis = new HashMap<>(); // owner|instrument → {qty, cost}
    private final Map<String, Long> lastPrice = new HashMap<>();
    private final Map<String, List<long[]>> unvalued = new HashMap<>(); // instrument → deposits awaiting a first price
    private final Map<String, List<String>> unvaluedOwners = new HashMap<>();
    private final Map<Long, Long> collateral = new HashMap<>();
    private final Map<Long, String> positionInstrument = new HashMap<>();

    public StatementProjection(List<Instrument> instruments) {
        for (Instrument i : instruments) {
            this.instruments.put(i.id(), i);
            byBase.put(i.base(), i);
        }
    }

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            apply(e);
        }
    }

    public Statement statement(String owner, long from, long to) {
        List<Line> out = new ArrayList<>();
        long fees = 0;
        long spread = 0;
        long realised = 0;
        long interest = 0;
        long payouts = 0;
        for (Line l : lines.getOrDefault(owner, new ArrayDeque<>())) {
            if (l.ts() < from || l.ts() >= to) {
                continue;
            }
            out.add(l);
            fees += l.fee();
            spread += l.spreadPaid();
            realised += l.realisedPnl();
            if (l.kind() == Kind.INTEREST) {
                interest += l.amount();
            }
            if (l.kind() == Kind.DIVIDEND || l.kind() == Kind.COUPON) {
                payouts += l.amount();
            }
        }
        long tax = (Math.max(0, realised) + payouts) * TAX_RATE_BPS / 10_000;
        return new Statement(from, to, "SPARK", out, new Totals(fees, spread, realised, TAX_RATE_BPS, tax, interest, payouts));
    }

    private void apply(Event e) {
        switch (e) {
            case Event.FundsDeposited d -> deposited(d);
            case Event.TradeExecuted t -> traded(t);
            case Event.MarginPositionOpened m -> {
                collateral.put(m.positionId(), m.collateral());
                positionInstrument.put(m.positionId(), m.instrument());
                add(m.account(), new Line(m.ts(), Kind.MARGIN_OPEN, m.instrument(), m.side(), null, m.qty(), null,
                        quoteOf(m.instrument()), -m.collateral(), 0, 0, 0, true, m.positionId()));
            }
            case Event.MarginStopOut s -> add(s.account(), new Line(s.ts(), Kind.STOP_OUT, positionInstrument.get(s.positionId()),
                    null, s.lastPrice(), null, null, quoteOf(positionInstrument.get(s.positionId())), 0, 0, 0, 0, true, s.positionId()));
            case Event.MarginPositionClosed c -> add(c.account(), new Line(c.ts(), Kind.MARGIN_CLOSE,
                    positionInstrument.get(c.positionId()), null, null, null, null, quoteOf(positionInstrument.get(c.positionId())),
                    c.returnedQuote(), 0, 0, c.returnedQuote() - collateral.getOrDefault(c.positionId(), 0L), true, c.positionId()));
            case Event.SavingsOpened s -> add(s.account(), new Line(s.ts(), Kind.SAVINGS_OPEN, null, null, null, null, null,
                    s.asset(), -s.amount(), 0, 0, 0, false, s.depositId()));
            case Event.SavingsClosed s -> add(s.account(), new Line(s.ts(), Kind.SAVINGS_CLOSE, null, null, null, null, null,
                    "SPARK", s.payout(), 0, 0, 0, false, s.depositId()));
            case Event.InterestAccrued i -> add(i.account(), new Line(i.ts(), Kind.INTEREST, null, null, null, null, null,
                    "SPARK", i.amount(), 0, 0, 0, false, i.depositId()));
            case Event.PayoutPaid p -> paid(p);
            default -> { }
        }
    }

    /** Dividends and coupons are income; a redemption sells the bonds back to the issuer at {@code perUnit}. */
    private void paid(Event.PayoutPaid p) {
        String owner = Accounts.owner(p.holder());
        if (isSystem(owner) || Accounts.isSubAccount(p.holder())) {
            return;
        }
        String quote = quoteOf(p.instrument());
        switch (p.kind()) {
            case DIVIDEND -> add(owner, new Line(p.ts(), Kind.DIVIDEND, p.instrument(), null, null, p.units(), null, quote,
                    p.amount(), 0, 0, 0, false, null));
            case COUPON -> add(owner, new Line(p.ts(), Kind.COUPON, p.instrument(), null, null, p.units(), null, quote,
                    p.amount(), 0, 0, 0, false, null));
            case REDEMPTION -> add(owner, new Line(p.ts(), Kind.REDEMPTION, p.instrument(), Order.Side.SELL,
                    p.units() == 0 ? 0 : p.amount() / p.units(), p.units(), null, quote, p.amount(), 0, 0,
                    realise(owner, p.instrument(), p.units(), p.amount()), false, null));
        }
    }

    private void deposited(Event.FundsDeposited d) {
        if (isSystem(d.account())) {
            return;
        }
        add(d.account(), new Line(d.ts(), Kind.DEPOSIT, null, null, null, null, null, d.asset(), d.amount(), 0, 0, 0, false, null));
        Instrument i = byBase.get(d.asset());
        if (i != null) {
            // A deposited base asset enters the cost basis at the market price: the last trade, or the first one to come.
            Long price = lastPrice.get(i.id());
            if (price != null) {
                addBasis(d.account(), i.id(), d.amount(), price * d.amount());
            } else {
                unvalued.computeIfAbsent(i.id(), k -> new ArrayList<>()).add(new long[] {d.amount()});
                unvaluedOwners.computeIfAbsent(i.id(), k -> new ArrayList<>()).add(d.account());
            }
        }
    }

    private void traded(Event.TradeExecuted t) {
        List<long[]> waiting = unvalued.remove(t.instrument());
        if (waiting != null) {
            List<String> owners = unvaluedOwners.remove(t.instrument());
            for (int k = 0; k < waiting.size(); k++) {
                addBasis(owners.get(k), t.instrument(), waiting.get(k)[0], waiting.get(k)[0] * t.price());
            }
        }
        long notional = t.price() * t.qty();
        String quote = quoteOf(t.instrument());
        boolean hasMid = t.mid() > 0;
        // buyer
        boolean buyerMargin = Accounts.isSubAccount(t.buyer());
        String buyer = Accounts.owner(t.buyer());
        if (!isSystem(buyer)) {
            if (!buyerMargin) {
                addBasis(buyer, t.instrument(), t.qty(), notional + t.buyerFee());
            }
            add(buyer, new Line(t.ts(), Kind.TRADE, t.instrument(), Order.Side.BUY, t.price(), t.qty(), hasMid ? t.mid() : null,
                    quote, -(notional + t.buyerFee()), t.buyerFee(), hasMid ? (t.price() - t.mid()) * t.qty() : 0, 0,
                    buyerMargin, t.buyOrderId()));
        }
        // seller
        boolean sellerMargin = Accounts.isSubAccount(t.seller());
        String seller = Accounts.owner(t.seller());
        if (!isSystem(seller)) {
            long proceeds = notional - t.sellerFee();
            long realised = sellerMargin ? 0 : realise(seller, t.instrument(), t.qty(), proceeds);
            add(seller, new Line(t.ts(), Kind.TRADE, t.instrument(), Order.Side.SELL, t.price(), t.qty(), hasMid ? t.mid() : null,
                    quote, proceeds, t.sellerFee(), hasMid ? (t.mid() - t.price()) * t.qty() : 0, realised,
                    sellerMargin, t.sellOrderId()));
        }
        lastPrice.put(t.instrument(), t.price());
    }

    /** Average cost: the sold part carries its share of the cost basis. */
    private long realise(String owner, String instrument, long qty, long proceeds) {
        long[] b = basis.get(owner + "|" + instrument);
        if (b == null || b[0] <= 0) {
            return 0;
        }
        long sold = Math.min(qty, b[0]);
        long cost = Math.multiplyExact(b[1], sold) / b[0];
        b[0] -= sold;
        b[1] -= cost;
        return Math.multiplyExact(proceeds, sold) / qty - cost;
    }

    private void addBasis(String owner, String instrument, long qty, long cost) {
        long[] b = basis.computeIfAbsent(owner + "|" + instrument, k -> new long[2]);
        b[0] += qty;
        b[1] += cost;
    }

    private void add(String owner, Line line) {
        Deque<Line> list = lines.computeIfAbsent(owner, k -> new ArrayDeque<>());
        list.addLast(line);
        if (list.size() > LINES_KEPT) {
            list.removeFirst();
        }
    }

    private String quoteOf(String instrument) {
        Instrument i = instrument == null ? null : instruments.get(instrument);
        return i == null ? "SPARK" : i.quote();
    }

    private static boolean isSystem(String account) {
        return account.equals(Ledger.FEES_ACCOUNT) || account.equals(Ledger.BANK_ACCOUNT);
    }
}
