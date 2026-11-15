package application.realworld;

import application.MarketListener;
import engine.Event;
import engine.Order;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * Paper («учебные») positions on real-world quotes (ADR-0015): opened and closed at the real price of the moment,
 * P&amp;L in the quote currency. Never touches balances or the order book. Built from journalled events, so positions
 * survive a restart and replay; an {@code Idempotency-Key} returns the position it first opened.
 *
 * <p>Pattern: Event Sourcing projection / CQRS read model; Idempotency key. Not thread-safe: sequencer thread only.
 */
public final class PaperBook implements MarketListener {

    public record Position(long paperId, String account, String symbol, Order.Side side, long qty, long entryPrice,
                           long openedAt, long quotedAt, String source, Long exitPrice, Long closedAt) {

        public boolean open() {
            return exitPrice == null;
        }

        /** Profit in quote minor units at {@code price} (the exit price once closed). */
        public long pnl(long price) {
            long p = exitPrice != null ? exitPrice : price;
            long diff = side == Order.Side.BUY ? p - entryPrice : entryPrice - p;
            return Math.multiplyExact(diff, qty);
        }
    }

    private final Map<Long, Position> positions = new LinkedHashMap<>();
    private final Map<String, Long> keys = new HashMap<>();
    private long nextId = 1;

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            if (e instanceof Event.PaperPositionOpened o) {
                positions.put(o.paperId(), new Position(o.paperId(), o.account(), o.symbol(), o.side(), o.qty(), o.price(),
                        o.ts(), o.quotedAt(), o.source(), null, null));
                nextId = Math.max(nextId, o.paperId() + 1);
                if (o.idempotencyKey() != null) {
                    keys.put(o.account() + "|" + o.idempotencyKey(), o.paperId());
                }
            } else if (e instanceof Event.PaperPositionClosed c) {
                Position p = positions.get(c.paperId());
                if (p != null) {
                    positions.put(p.paperId(), new Position(p.paperId(), p.account(), p.symbol(), p.side(), p.qty(),
                            p.entryPrice(), p.openedAt(), p.quotedAt(), p.source(), c.price(), c.ts()));
                }
            }
        }
    }

    public long nextId() {
        return nextId;
    }

    public Optional<Long> byKey(String account, String key) {
        return key == null ? Optional.empty() : Optional.ofNullable(keys.get(account + "|" + key));
    }

    public Optional<Position> get(long id) {
        return Optional.ofNullable(positions.get(id));
    }

    public List<Position> of(String account) {
        List<Position> out = new ArrayList<>();
        positions.values().stream().filter(p -> p.account().equals(account)).forEach(out::add);
        return out.reversed();
    }
}
