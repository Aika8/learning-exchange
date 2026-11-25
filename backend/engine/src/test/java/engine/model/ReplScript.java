package engine.model;

import engine.Order;
import java.util.ArrayList;
import java.util.List;

/**
 * Turns a generated action list into commands for the order-book REPL ({@code make repl}), so a failing
 * property can be replayed by hand: paste the lines into the REPL and watch the book step by step.
 *
 * <p>The REPL grammar ({@code backend/repl}, {@code repl.Repl}): {@code buy|sell <qty>@<price>} for a limit
 * order, {@code buy|sell <qty>} for a market order, {@code cancel <id>}, {@code book}. A {@link Action.Cancel}
 * holds a pick index, not an id, so the id comes from the {@link Runner} run of the same actions; the REPL starts
 * with a fresh book too and assigns the same ids. A cancel with nothing resting becomes {@code book}, which only
 * prints the book: one line per action stays, so line {@code i} is action {@code i}.
 */
public final class ReplScript {

    private ReplScript() {}

    /**
     * One REPL command per action, joined by {@code \n} (trailing newline included).
     *
     * @param actions the actions that were run
     * @param steps   {@code Runner.run(actions)}; must be the run of exactly these actions
     */
    public static String render(List<Action> actions, List<Runner.Step> steps) {
        if (actions.size() != steps.size()) {
            throw new IllegalArgumentException(
                    "steps do not belong to these actions: " + actions.size() + " actions, " + steps.size() + " steps");
        }
        List<String> lines = new ArrayList<>(actions.size());
        for (int i = 0; i < actions.size(); i++) {
            Action action = actions.get(i);
            Runner.Step step = steps.get(i);
            if (!step.action().equals(action)) {
                throw new IllegalArgumentException("step " + i + " ran " + step.action() + ", not " + action);
            }
            lines.add(switch (action) {
                case Action.SubmitLimit l -> verb(l.side()) + " " + l.qty() + "@" + l.price();
                case Action.SubmitMarket m -> verb(m.side()) + " " + m.qty();
                case Action.Cancel c -> step.orderId().isPresent() ? "cancel " + step.orderId().getAsLong() : "book";
            });
        }
        return String.join("\n", lines) + (lines.isEmpty() ? "" : "\n");
    }

    private static String verb(Order.Side side) {
        return side == Order.Side.BUY ? "buy" : "sell";
    }
}
