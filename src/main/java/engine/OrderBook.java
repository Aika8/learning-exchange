package engine;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Deque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.NavigableMap;
import java.util.Optional;
import java.util.TreeMap;

/**
 * In-memory limit order book for one instrument with price-time priority.
 *
 * <p>Bids are kept highest price first, asks lowest price first. Within a price
 * level orders execute in arrival order. Trades are priced at the resting order's
 * price. Empty price levels are removed immediately. Order ids come from a
 * monotonic counter starting at 1 and are never reused.
 *
 * <p><b>Not thread-safe, single-threaded by design.</b> There are no locks: every
 * call must come from one thread. Protection against concurrent access is an open
 * question, to be decided after a test that demonstrates the race.
 */
public final class OrderBook {

    private final NavigableMap<Long, Deque<Resting>> bids = new TreeMap<>(Comparator.reverseOrder());
    private final NavigableMap<Long, Deque<Resting>> asks = new TreeMap<>();
    private final Map<Long, Resting> resting = new HashMap<>();
    private long nextId = 1;

    /**
     * Assigns the order an id and matches it against the opposite side. A limit
     * remainder rests at its limit price; a market remainder is cancelled and never rests.
     */
    public SubmitResult submit(Order order) {
        long id = nextId++;
        long remaining = order.qty();
        List<Trade> trades = new ArrayList<>();
        NavigableMap<Long, Deque<Resting>> opposite = order.side() == Order.Side.BUY ? asks : bids;

        while (remaining > 0 && !opposite.isEmpty()) {
            Map.Entry<Long, Deque<Resting>> best = opposite.firstEntry();
            if (!crosses(order, best.getKey())) {
                break;
            }
            Deque<Resting> level = best.getValue();
            Resting maker = level.peekFirst();
            long qty = Math.min(remaining, maker.remaining);
            remaining -= qty;
            maker.remaining -= qty;
            trades.add(order.side() == Order.Side.BUY
                    ? new Trade(id, maker.id, maker.price, qty, Order.Side.BUY)
                    : new Trade(maker.id, id, maker.price, qty, Order.Side.SELL));
            if (maker.remaining == 0) {
                level.pollFirst();
                resting.remove(maker.id);
                if (level.isEmpty()) {
                    opposite.remove(best.getKey());
                }
            }
        }

        if (remaining > 0 && order instanceof Order.Limit limit) {
            Resting rest = new Resting(id, limit.side(), limit.price(), remaining);
            NavigableMap<Long, Deque<Resting>> own = limit.side() == Order.Side.BUY ? bids : asks;
            own.computeIfAbsent(rest.price, p -> new ArrayDeque<>()).addLast(rest);
            resting.put(id, rest);
        }
        return new SubmitResult(id, trades);
    }

    /** Removes a resting order. Returns false if the id is not resting in the book. */
    public boolean cancel(long id) {
        Resting order = resting.remove(id);
        if (order == null) {
            return false;
        }
        NavigableMap<Long, Deque<Resting>> side = order.side == Order.Side.BUY ? bids : asks;
        Deque<Resting> level = side.get(order.price);
        level.remove(order);
        if (level.isEmpty()) {
            side.remove(order.price);
        }
        return true;
    }

    public Optional<Long> bestBid() {
        return bids.isEmpty() ? Optional.empty() : Optional.of(bids.firstKey());
    }

    public Optional<Long> bestAsk() {
        return asks.isEmpty() ? Optional.empty() : Optional.of(asks.firstKey());
    }

    /** Top {@code depth} bid levels, best first. */
    public List<Level> bids(int depth) {
        return levels(bids, depth);
    }

    /** Top {@code depth} ask levels, best first. */
    public List<Level> asks(int depth) {
        return levels(asks, depth);
    }

    /** Aggregated view of one price level. */
    public record Level(long price, long qty, int orders) {}

    /** A limit order remainder sitting in the book. */
    private static final class Resting {
        final long id;
        final Order.Side side;
        final long price;
        long remaining;

        Resting(long id, Order.Side side, long price, long remaining) {
            this.id = id;
            this.side = side;
            this.price = price;
            this.remaining = remaining;
        }
    }

    private static boolean crosses(Order incoming, long restingPrice) {
        if (!(incoming instanceof Order.Limit limit)) {
            return true;
        }
        return limit.side() == Order.Side.BUY
                ? restingPrice <= limit.price()
                : restingPrice >= limit.price();
    }

    private static List<Level> levels(NavigableMap<Long, Deque<Resting>> side, int depth) {
        List<Level> out = new ArrayList<>();
        for (Map.Entry<Long, Deque<Resting>> e : side.entrySet()) {
            if (out.size() == depth) {
                break;
            }
            long qty = e.getValue().stream().mapToLong(r -> r.remaining).sum();
            out.add(new Level(e.getKey(), qty, e.getValue().size()));
        }
        return Collections.unmodifiableList(out);
    }
}
