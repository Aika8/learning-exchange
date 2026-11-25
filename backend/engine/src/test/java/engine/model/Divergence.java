package engine.model;

import engine.OrderBook;
import engine.Trade;
import engine.ref.RefLevel;
import engine.ref.RefTrade;
import engine.ref.ReferenceBook;
import java.util.List;
import java.util.Optional;

/**
 * The first difference between the engine's {@link OrderBook} and the {@link ReferenceBook} over one action list,
 * as a value instead of a test failure — so a {@link Shrinker} can ask "does it still differ?" many times.
 *
 * <p>Compared after every step: the assigned id, the cancel result, the trades (in order) and the full depth on
 * both sides. The engine side is {@link Runner}; a cancel sends the id the Runner resolved to the reference book.
 */
public final class Divergence {

    private Divergence() {}

    /** Empty when both books agree on every step; otherwise "step i (action): what differs, both values". */
    public static Optional<String> first(List<Action> actions) {
        List<Runner.Step> steps = Runner.run(actions);
        ReferenceBook ref = new ReferenceBook();
        for (Runner.Step step : steps) {
            List<RefTrade> expected = List.of();
            Optional<String> d = Optional.empty();
            switch (step.action()) {
                case Action.SubmitLimit l -> {
                    d = differ(step, "order id", ref.submitLimit(l.side(), l.price(), l.qty()),
                            step.orderId().orElseThrow());
                    expected = ref.lastTrades();
                }
                case Action.SubmitMarket m -> {
                    d = differ(step, "order id", ref.submitMarket(m.side(), m.qty()), step.orderId().orElseThrow());
                    expected = ref.lastTrades();
                }
                case Action.Cancel c -> {
                    if (step.orderId().isPresent()) {
                        d = differ(step, "cancel result", ref.cancel(step.orderId().getAsLong()), step.cancelled());
                    }
                }
            }
            List<RefTrade> actual = step.trades().stream().map(Divergence::asRef).toList();
            List<RefTrade> trades = expected;
            d = d.or(() -> differ(step, "trades", trades, actual))
                    .or(() -> differ(step, "bids", ref.bids(Integer.MAX_VALUE), asRef(step.bids())))
                    .or(() -> differ(step, "asks", ref.asks(Integer.MAX_VALUE), asRef(step.asks())));
            if (d.isPresent()) {
                return d;
            }
        }
        return Optional.empty();
    }

    private static Optional<String> differ(Runner.Step step, String what, Object reference, Object engine) {
        if (reference.equals(engine)) {
            return Optional.empty();
        }
        return Optional.of("step " + step.index() + " (" + step.action() + "): " + what + " differ\n"
                + "  reference: " + reference + "\n"
                + "  engine:    " + engine);
    }

    private static RefTrade asRef(Trade t) {
        return new RefTrade(t.buyOrderId(), t.sellOrderId(), t.price(), t.qty(), t.aggressorSide());
    }

    private static List<RefLevel> asRef(List<OrderBook.Level> levels) {
        return levels.stream().map(l -> new RefLevel(l.price(), l.qty(), l.orders())).toList();
    }
}
