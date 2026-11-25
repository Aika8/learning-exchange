package engine.model;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Predicate;

/**
 * Pattern: Delta debugging (one-at-a-time shrinking) — turns a long failing action list into a short one that
 * still fails, so it can be kept as a regression file that does not depend on the generator.
 * No ADR: test-only; see docs/backlog/QUEUE.md (LE-010).
 *
 * <p>Drops actions one by one, last to first, keeping a drop whenever the list still fails; repeats until no
 * single drop keeps it failing. The result is 1-minimal: removing any one action makes the failure go away.
 * A dropped action shifts what later {@link Action.Cancel}s pick, so every candidate is judged by running it again.
 */
public final class Shrinker {

    private Shrinker() {}

    /**
     * @param actions a list for which {@code fails} is true
     * @param fails   the failure to keep, e.g. {@code a -> Divergence.first(a).isPresent()}
     * @return a 1-minimal sub-list (order kept) for which {@code fails} is still true
     */
    public static List<Action> shrink(List<Action> actions, Predicate<List<Action>> fails) {
        if (!fails.test(actions)) {
            throw new IllegalArgumentException("nothing to shrink: the actions do not fail");
        }
        List<Action> current = new ArrayList<>(actions);
        boolean dropped = true;
        while (dropped) {
            dropped = false;
            for (int i = current.size() - 1; i >= 0; i--) {
                List<Action> candidate = new ArrayList<>(current);
                candidate.remove(i);
                if (fails.test(List.copyOf(candidate))) {
                    current = candidate;
                    dropped = true;
                }
            }
        }
        return List.copyOf(current);
    }

    /** Shrinks a list on which the engine and the reference book differ; prints it as a regression file. */
    public static String regressionFile(List<Action> actions) {
        List<Action> small = shrink(actions, a -> Divergence.first(a).isPresent());
        return ReplScript.render(small, Runner.run(small));
    }
}
