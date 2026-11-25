package engine.model;

import engine.Order;
import engine.OrderBook;
import engine.SubmitResult;
import engine.Trade;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.OptionalLong;

/**
 * Pattern: Model-based testing — replays generated {@link Action}s on a real {@link OrderBook} and records
 * every observable result per step, so properties can be checked against the run afterwards.
 * No ADR: test-only; see docs/backlog/QUEUE.md ("Engine: model-based testing").
 *
 * <p>The live-order table in each {@link Step} is the Runner's own model, built only from what the book
 * returned (assigned ids, trades, cancel results); it does not read the book's internals. A {@link
 * Action.Cancel} picks from that table in arrival order.
 */
public final class Runner {

    private Runner() {}

    /** A limit remainder the model believes is resting after a step. */
    public record LiveOrder(long id, Order.Side side, long price, long originalQty, long remainingQty, int arrival) {}

    /**
     * What one action did.
     *
     * @param index        position of the action in the list (0-based)
     * @param action       the action applied
     * @param orderId      the id the book assigned (submits), or the resting id a cancel resolved to; empty for a
     *                     cancel with nothing resting
     * @param submitResult the book's result for a submit; empty for a cancel
     * @param cancelled    what {@link OrderBook#cancel} returned; false for submits and for a no-op cancel
     * @param trades       trades of this step (empty for a cancel)
     * @param bids         full bid depth after the step, best first
     * @param asks         full ask depth after the step, best first
     * @param live         live orders after the step by id, in arrival order
     */
    public record Step(
            int index,
            Action action,
            OptionalLong orderId,
            Optional<SubmitResult> submitResult,
            boolean cancelled,
            List<Trade> trades,
            List<OrderBook.Level> bids,
            List<OrderBook.Level> asks,
            Map<Long, LiveOrder> live) {}

    /** Applies {@code actions} to a fresh {@link OrderBook}; one {@link Step} per action. */
    public static List<Step> run(List<Action> actions) {
        OrderBook book = new OrderBook();
        Map<Long, LiveOrder> live = new LinkedHashMap<>();
        List<Step> steps = new ArrayList<>(actions.size());
        for (int i = 0; i < actions.size(); i++) {
            Action action = actions.get(i);
            OptionalLong orderId;
            Optional<SubmitResult> submitResult = Optional.empty();
            boolean cancelled = false;
            List<Trade> trades = List.of();
            switch (action) {
                case Action.SubmitLimit l -> {
                    SubmitResult r = book.submit(Order.limit(l.side(), l.price(), l.qty()));
                    applyTrades(live, r);
                    long rest = l.qty() - r.filledQty();
                    if (rest > 0) {
                        live.put(r.orderId(), new LiveOrder(r.orderId(), l.side(), l.price(), l.qty(), rest, i));
                    }
                    orderId = OptionalLong.of(r.orderId());
                    submitResult = Optional.of(r);
                    trades = r.trades();
                }
                case Action.SubmitMarket m -> {
                    SubmitResult r = book.submit(Order.market(m.side(), m.qty()));
                    applyTrades(live, r);
                    orderId = OptionalLong.of(r.orderId());
                    submitResult = Optional.of(r);
                    trades = r.trades();
                }
                case Action.Cancel c -> {
                    if (live.isEmpty()) {
                        orderId = OptionalLong.empty();
                    } else {
                        long id = new ArrayList<>(live.keySet()).get(Math.floorMod(c.pickIndex(), live.size()));
                        cancelled = book.cancel(id);
                        if (cancelled) {
                            live.remove(id);
                        }
                        orderId = OptionalLong.of(id);
                    }
                }
            }
            steps.add(new Step(i, action, orderId, submitResult, cancelled, trades,
                    book.bids(Integer.MAX_VALUE), book.asks(Integer.MAX_VALUE),
                    Collections.unmodifiableMap(new LinkedHashMap<>(live))));
        }
        return Collections.unmodifiableList(steps);
    }

    /** Reduces the resting (maker) side of each trade; a maker filled to zero leaves the model. */
    private static void applyTrades(Map<Long, LiveOrder> live, SubmitResult r) {
        for (Trade t : r.trades()) {
            long makerId = t.aggressorSide() == Order.Side.BUY ? t.sellOrderId() : t.buyOrderId();
            LiveOrder maker = live.get(makerId);
            if (maker == null) {
                continue;
            }
            long left = maker.remainingQty() - t.qty();
            if (left <= 0) {
                live.remove(makerId);
            } else {
                live.put(makerId, new LiveOrder(maker.id(), maker.side(), maker.price(), maker.originalQty(), left,
                        maker.arrival()));
            }
        }
    }
}
