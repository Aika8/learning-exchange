package engine.model;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

import engine.Order;
import engine.Trade;
import java.io.IOException;
import java.net.URISyntaxException;
import java.net.URL;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.function.Predicate;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/**
 * LE-010: every file in {@code src/test/resources/regressions/*.txt} replays identically on the engine and the
 * {@link engine.ref.ReferenceBook}; plus the {@link Shrinker} and the {@link RegressionFile} format it writes.
 */
class RegressionCorpusTest {

    @Test
    void everyCorpusFileReplaysIdenticallyOnBothBooks() throws IOException, URISyntaxException {
        List<Path> files = corpus();
        assertFalse(files.isEmpty(), "no regression files found");
        for (Path file : files) {
            List<Action> actions = RegressionFile.parse(Files.readString(file));
            assertFalse(actions.isEmpty(), file + " has no actions");
            Divergence.first(actions).ifPresent(d -> fail(file.getFileName() + ": " + d));
        }
    }

    @Test
    void timePriorityFileFillsTheOlderOrderAtAPriceFirst() throws IOException, URISyntaxException {
        Path file = corpus().stream().filter(p -> p.endsWith("time-priority.txt")).findFirst().orElseThrow();
        List<Runner.Step> steps = Runner.run(RegressionFile.parse(Files.readString(file)));
        List<Long> makers = steps.get(3).trades().stream().map(Trade::sellOrderId).toList();
        assertEquals(List.of(3L, 1L, 2L), makers);
        assertTrue(steps.get(4).cancelled());
    }

    @Test
    void generatedRunsHaveNoDivergence() {
        for (long seed = 1; seed <= 20; seed++) {
            List<Action> actions = ActionGen.generate(seed, 300);
            assertEquals(java.util.Optional.empty(), Divergence.first(actions), "seed " + seed);
        }
    }

    @Test
    void renderedScriptsParseBackToTheSameRun() {
        for (long seed = 1; seed <= 20; seed++) {
            List<Action> actions = ActionGen.generate(seed, 300);
            List<Runner.Step> steps = Runner.run(actions);
            List<Action> parsed = RegressionFile.parse(ReplScript.render(actions, steps));
            List<Runner.Step> again = Runner.run(parsed);
            // "book" lines (cancels with nothing resting) are dropped; everything else targets the same ids.
            List<Runner.Step> kept = steps.stream().filter(s -> !(s.action() instanceof Action.Cancel)
                    || s.orderId().isPresent()).toList();
            assertEquals(kept.size(), again.size(), "seed " + seed);
            for (int i = 0; i < kept.size(); i++) {
                assertEquals(kept.get(i).orderId(), again.get(i).orderId(), "seed " + seed + ", step " + i);
                assertEquals(kept.get(i).trades(), again.get(i).trades(), "seed " + seed + ", step " + i);
            }
        }
    }

    @Test
    void parserRejectsBadLinesWithTheLineNumber() {
        IllegalArgumentException bad = assertThrows(IllegalArgumentException.class,
                () -> RegressionFile.parse("buy 1@100\nhold 3\n"));
        assertTrue(bad.getMessage().startsWith("line 2:"), bad.getMessage());
        IllegalArgumentException gone = assertThrows(IllegalArgumentException.class,
                () -> RegressionFile.parse("sell 1@100\nbuy 1\ncancel 1\n"));
        assertTrue(gone.getMessage().startsWith("line 3:"), gone.getMessage());
    }

    @Test
    void shrinkerKeepsTheFailureAndIsOneMinimal() {
        // A stand-in failure: some submit trades against two different resting orders at once.
        Predicate<List<Action>> fails = a -> Runner.run(a).stream()
                .anyMatch(s -> s.trades().stream().map(t -> t.aggressorSide() == Order.Side.BUY
                        ? t.sellOrderId() : t.buyOrderId()).distinct().count() >= 2);
        List<Action> actions = ActionGen.generate(7, 400);
        assertTrue(fails.test(actions), "seed 7 should contain such a submit");

        List<Action> small = Shrinker.shrink(actions, fails);

        assertTrue(fails.test(small));
        assertEquals(3, small.size(), small.toString()); // two makers and one taker
        for (int i = 0; i < small.size(); i++) {
            List<Action> fewer = new java.util.ArrayList<>(small);
            fewer.remove(i);
            assertFalse(fails.test(fewer), "dropping " + i + " still fails: " + fewer);
        }
        assertTrue(actions.containsAll(small));
    }

    @Test
    void shrinkerRefusesAPassingList() {
        assertThrows(IllegalArgumentException.class,
                () -> Shrinker.shrink(ActionGen.generate(1, 10), a -> false));
    }

    private static List<Path> corpus() throws IOException, URISyntaxException {
        URL dir = RegressionCorpusTest.class.getResource("/regressions");
        assertTrue(dir != null, "src/test/resources/regressions is not on the test classpath");
        try (Stream<Path> files = Files.list(Path.of(dir.toURI()))) {
            return files.filter(p -> p.toString().endsWith(".txt")).sorted().toList();
        }
    }
}
