package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Order;
import java.util.List;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;

class ReplScriptTest {

    /**
     * The commands {@code repl.Repl#execute} accepts, written out here: the engine's tests cannot depend on the
     * repl module. {@code buy|sell <qty>[@<price>]}, {@code cancel <id>}, {@code book}.
     */
    private static final Pattern REPL_COMMAND =
            Pattern.compile("(buy|sell) -?\\d+(@-?\\d+)?|cancel -?\\d+|book");

    @Test
    void rendersThreeActionsAsReplCommands() {
        List<Action> actions = List.of(
                new Action.SubmitLimit(Order.Side.BUY, 100, 5),
                new Action.SubmitMarket(Order.Side.SELL, 2),
                new Action.Cancel(7));

        String script = ReplScript.render(actions, Runner.run(actions));

        // ids: the limit buy gets #1, the market sell #2; the cancel picks the only live order, #1.
        assertEquals("buy 5@100\nsell 2\ncancel 1\n", script);
        assertAcceptedByRepl(script);
    }

    @Test
    void cancelResolvesPickIndexToTheIdTheBookAssigned() {
        List<Action> actions = List.of(
                new Action.SubmitMarket(Order.Side.BUY, 3),
                new Action.SubmitLimit(Order.Side.SELL, 101, 4),
                new Action.SubmitLimit(Order.Side.SELL, 102, 6),
                new Action.Cancel(3));

        String script = ReplScript.render(actions, Runner.run(actions));

        // live: #2, #3 in arrival order; pick 3 mod 2 = 1 -> #3.
        assertEquals("buy 3\nsell 4@101\nsell 6@102\ncancel 3\n", script);
        assertAcceptedByRepl(script);
    }

    @Test
    void cancelWithNothingRestingBecomesBook() {
        List<Action> actions = List.of(new Action.Cancel(0), new Action.SubmitMarket(Order.Side.BUY, 1));

        String script = ReplScript.render(actions, Runner.run(actions));

        assertEquals("book\nbuy 1\n", script);
        assertAcceptedByRepl(script);
    }

    @Test
    void generatedFlowRendersOneAcceptedLinePerAction() {
        List<Action> actions = ActionGen.generate(42, 200);

        String[] lines = ReplScript.render(actions, Runner.run(actions)).split("\n");

        assertEquals(actions.size(), lines.length);
        for (String line : lines) {
            assertTrue(REPL_COMMAND.matcher(line).matches(), line);
        }
    }

    @Test
    void stepsOfOtherActionsAreRejected() {
        List<Action> actions = List.of(new Action.SubmitMarket(Order.Side.BUY, 1));
        List<Action> other = List.of(new Action.SubmitMarket(Order.Side.SELL, 1));

        assertThrows(IllegalArgumentException.class, () -> ReplScript.render(actions, Runner.run(other)));
        assertThrows(IllegalArgumentException.class, () -> ReplScript.render(actions, List.of()));
    }

    private static void assertAcceptedByRepl(String script) {
        for (String line : script.split("\n")) {
            assertTrue(REPL_COMMAND.matcher(line).matches(), "REPL would reject: " + line);
        }
    }
}
