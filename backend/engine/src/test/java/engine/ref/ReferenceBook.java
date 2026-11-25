package engine.ref;

import engine.Order.Side;
import java.util.ArrayList;
import java.util.List;

/**
 * Pattern: Test Oracle — a second order book written from intent/01-order-book.md alone, slow and plain, so
 * that differential tests (LE-008…010) can compare the engine against something a reader can check line by line.
 * Shares nothing with the engine except the {@link Side} enum.
 */
public final class ReferenceBook {

    /** A resting order; {@code filled} only grows, and never past {@code qty}. */
    private static final class Resting {
        final long id, price, qty;
        final Side side;
        long filled;

        Resting(long id, Side side, long price, long qty, long filled) {
            this.id = id; this.side = side; this.price = price; this.qty = qty; this.filled = filled;
        }

        long remaining() {
            return qty - filled; // invariant 7: remaining = quantity − filled
        }
    }

    // Each list is kept in arrival order: new orders are appended, never inserted.
    private final List<Resting> bids = new ArrayList<>();
    private final List<Resting> asks = new ArrayList<>();
    private List<RefTrade> lastTrades = List.of();
    private long nextId = 1; // DECISIONS.md: ids from 1, every submitted order gets one, never reused

    public long submitLimit(Side side, long price, long qty) {
        check(side, qty);
        if (price <= 0) throw new IllegalArgumentException("price must be positive");
        long id = nextId++;
        long left = match(id, side, price, qty, true);
        if (left > 0) {
            // Invariant 4: only priced orders rest. Invariant 3 holds: matching ran until the best opposite
            // price was beyond our limit, so resting here cannot cross the book.
            (side == Side.BUY ? bids : asks).add(new Resting(id, side, price, qty, qty - left));
        }
        return id;
    }

    public long submitMarket(Side side, long qty) {
        check(side, qty);
        long id = nextId++;
        match(id, side, 0, qty, false);
        // Invariant 4: an unfilled market remainder is cancelled — it is simply never added to a list.
        return id;
    }

    /** Invariant 5: a cancelled order leaves the book, so no later match can ever reach it. */
    public boolean cancel(long id) {
        for (List<Resting> list : List.of(bids, asks)) {
            for (int i = 0; i < list.size(); i++) {
                if (list.get(i).id == id) {
                    list.remove(i);
                    return true;
                }
            }
        }
        return false; // unknown, already filled or already cancelled
    }

    /** Trades produced by the most recent submit, in execution order. */
    public List<RefTrade> lastTrades() {
        return lastTrades;
    }

    public List<RefLevel> bids(int depth) {
        return levels(bids, depth, Side.BUY);
    }

    public List<RefLevel> asks(int depth) {
        return levels(asks, depth, Side.SELL);
    }

    /** Matches the incoming order against the opposite side; returns the quantity left unfilled. */
    private long match(long id, Side side, long limit, long qty, boolean priced) {
        List<Resting> opposite = side == Side.BUY ? asks : bids;
        List<RefTrade> trades = new ArrayList<>();
        long left = qty;
        while (left > 0) {
            Resting best = best(opposite);
            if (best == null) {
                break;
            }
            // Invariant 2: a limit order never executes at a price worse than its limit.
            // For a buy, an ask "better as a bid" than the limit is above it; for a sell, below it.
            if (priced && better(side, best.price, limit)) {
                break;
            }
            long q = Math.min(left, best.remaining());
            best.filled += q; // invariant 7: never more than the remaining quantity
            left -= q;
            long buyId = side == Side.BUY ? id : best.id;
            long sellId = side == Side.BUY ? best.id : id;
            trades.add(new RefTrade(buyId, sellId, best.price, q, side)); // trade at the resting order's price
            if (best.remaining() == 0) {
                opposite.remove(best); // invariant 6: a filled order leaves, so no level is empty
            }
        }
        lastTrades = List.copyOf(trades);
        return left;
    }

    /**
     * Best price first (highest bid, lowest ask); at equal price the earliest arrival wins — invariant 1.
     * The list is in arrival order, so a strict comparison keeps the first order found at the best price.
     */
    private static Resting best(List<Resting> list) {
        Resting best = null;
        for (Resting r : list) {
            if (best == null || better(r.side, r.price, best.price)) {
                best = r;
            }
        }
        return best;
    }

    private static boolean better(Side side, long price, long than) {
        return side == Side.BUY ? price > than : price < than;
    }

    /** Aggregates resting orders into levels, best first. Only orders with quantity rest, so no level is empty. */
    private static List<RefLevel> levels(List<Resting> list, int depth, Side side) {
        List<RefLevel> out = new ArrayList<>();
        List<Long> seen = new ArrayList<>();
        while (out.size() < depth) {
            Long price = null;
            for (Resting r : list) {
                if (!seen.contains(r.price) && (price == null || better(side, r.price, price))) {
                    price = r.price;
                }
            }
            if (price == null) {
                break;
            }
            seen.add(price);
            long qty = 0;
            int orders = 0;
            for (Resting r : list) {
                if (r.price == price) {
                    qty += r.remaining();
                    orders++;
                }
            }
            out.add(new RefLevel(price, qty, orders));
        }
        return out;
    }

    private static void check(Side side, long qty) {
        if (side == null || qty <= 0) {
            throw new IllegalArgumentException("side is required and qty must be positive"); // rejected before an id is taken
        }
    }
}
