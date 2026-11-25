package engine.model;

import engine.Order;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reads a regression file ({@code src/test/resources/regressions/*.txt}) back into {@link Action}s.
 *
 * <p>The format is what {@link ReplScript} writes, one action per line: {@code buy|sell <qty>@<price>},
 * {@code buy|sell <qty>}, {@code cancel <id>}. A {@code book} line (a cancel with nothing resting), a blank line and
 * a line starting with {@code #} (a comment) change nothing and are skipped. {@code cancel <id>} must name an order
 * still resting at that point; it becomes the {@link Action.Cancel} that picks that order.
 */
public final class RegressionFile {

    private static final Pattern LIMIT = Pattern.compile("(buy|sell) (\\d+)@(\\d+)");
    private static final Pattern MARKET = Pattern.compile("(buy|sell) (\\d+)");
    private static final Pattern CANCEL = Pattern.compile("cancel (\\d+)");

    private RegressionFile() {}

    public static List<Action> parse(String text) {
        List<Action> actions = new ArrayList<>();
        String[] lines = text.split("\n", -1);
        for (int n = 0; n < lines.length; n++) {
            String line = lines[n].strip().replaceAll("\\s+", " ");
            if (line.isEmpty() || line.startsWith("#") || line.equals("book")) {
                continue;
            }
            Matcher m;
            if ((m = LIMIT.matcher(line)).matches()) {
                actions.add(new Action.SubmitLimit(side(m.group(1)), Long.parseLong(m.group(3)),
                        Long.parseLong(m.group(2))));
            } else if ((m = MARKET.matcher(line)).matches()) {
                actions.add(new Action.SubmitMarket(side(m.group(1)), Long.parseLong(m.group(2))));
            } else if ((m = CANCEL.matcher(line)).matches()) {
                actions.add(new Action.Cancel(pickOf(actions, Long.parseLong(m.group(1)), n + 1)));
            } else {
                throw new IllegalArgumentException("line " + (n + 1) + ": not an action: " + lines[n]);
            }
        }
        return List.copyOf(actions);
    }

    /** The pick index that makes a {@link Action.Cancel} after {@code before} target order {@code id}. */
    private static int pickOf(List<Action> before, long id, int lineNo) {
        Map<Long, Runner.LiveOrder> live = before.isEmpty() ? Map.of() : Runner.run(before).getLast().live();
        int pick = new ArrayList<>(live.keySet()).indexOf(id);
        if (pick < 0) {
            throw new IllegalArgumentException("line " + lineNo + ": order " + id + " is not resting here");
        }
        return pick;
    }

    private static Order.Side side(String verb) {
        return verb.equals("buy") ? Order.Side.BUY : Order.Side.SELL;
    }
}
