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
 * price. Empty price levels are removed immediately.
 *
 * <p><b>Not thread-safe, single-threaded by design.</b> There are no locks: every
 * call must come from one thread. Protection against concurrent access is an open
 * question, to be decided after a test that demonstrates the race.
 */
public final class OrderBook {

    private final NavigableMap<Long, Deque<Order>> bids = new TreeMap<>(Comparator.reverseOrder());
    private final NavigableMap<Long, Deque<Order>> asks = new TreeMap<>();
    private final Map<Long, Order> resting = new HashMap<>();

    /**
     * Matches the order against the opposite side. A limit remainder rests at its
     * limit price; a market remainder is cancelled and never rests.
     */
    public List<Trade> submit(Order order) {
        if (resting.containsKey(order.id())) {
            throw new IllegalArgumentException("duplicate order id: " + order.id());
        }
        if (order.filled() != 0) {
            throw new IllegalArgumentException("order already executed: " + order.id());
        }
        List<Trade> trades = new ArrayList<>();
        NavigableMap<Long, Deque<Order>> opposite = order.side() == Order.Side.BUY ? asks : bids;

        while (order.remaining() > 0 && !opposite.isEmpty()) {
            Map.Entry<Long, Deque<Order>> best = opposite.firstEntry();
            if (!crosses(order, best.getKey())) {
                break;
            }
            Deque<Order> level = best.getValue();
            Order maker = level.peekFirst();
            long qty = Math.min(order.remaining(), maker.remaining());
            order.fill(qty);
            maker.fill(qty);
            trades.add(order.side() == Order.Side.BUY
                    ? new Trade(order.id(), maker.id(), maker.price(), qty)
                    : new Trade(maker.id(), order.id(), maker.price(), qty));
            if (maker.remaining() == 0) {
                level.pollFirst();
                resting.remove(maker.id());
                if (level.isEmpty()) {
                    opposite.remove(best.getKey());
                }
            }
        }

        if (order.remaining() > 0 && order.type() == Order.Type.LIMIT) {
            NavigableMap<Long, Deque<Order>> own = order.side() == Order.Side.BUY ? bids : asks;
            own.computeIfAbsent(order.price(), p -> new ArrayDeque<>()).addLast(order);
            resting.put(order.id(), order);
        }
        return trades;
    }

    /** Removes a resting order. Returns false if the id is not resting in the book. */
    public boolean cancel(long id) {
        Order order = resting.remove(id);
        if (order == null) {
            return false;
        }
        NavigableMap<Long, Deque<Order>> side = order.side() == Order.Side.BUY ? bids : asks;
        Deque<Order> level = side.get(order.price());
        level.remove(order);
        if (level.isEmpty()) {
            side.remove(order.price());
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

    private static boolean crosses(Order incoming, long restingPrice) {
        if (incoming.type() == Order.Type.MARKET) {
            return true;
        }
        return incoming.side() == Order.Side.BUY
                ? restingPrice <= incoming.price()
                : restingPrice >= incoming.price();
    }

    private static List<Level> levels(NavigableMap<Long, Deque<Order>> side, int depth) {
        List<Level> out = new ArrayList<>();
        for (Map.Entry<Long, Deque<Order>> e : side.entrySet()) {
            if (out.size() == depth) {
                break;
            }
            long qty = e.getValue().stream().mapToLong(Order::remaining).sum();
            out.add(new Level(e.getKey(), qty, e.getValue().size()));
        }
        return Collections.unmodifiableList(out);
    }
}
