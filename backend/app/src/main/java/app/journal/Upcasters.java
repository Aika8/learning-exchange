package app.journal;

import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reads old journal lines in the current format. Every line ends with {@code ,"v":N}, the format version it was
 * written in; a line without it is version 1 (M1/M2a). Each {@link Step} lifts one version to the next, so the
 * engine's event records only ever see the current shape and an old journal replays without {@code make reset}.
 *
 * <p>Steps edit the line's text, not a JSON tree: the first {@code "type"} key is the event type and
 * {@code OrderAccepted} has its own {@code "type"} field (LIMIT/MARKET), so a tree, which keeps one value per key,
 * would lose one of them. Lines are written by {@link FileJournal} only, so their shape is known.
 *
 * <p>Pattern: Upcaster (event versioning), a chain of small steps. See docs/adr/0020-journal-event-versioning.md.
 */
public final class Upcasters {

    /** The version written by this build. */
    public static final int CURRENT = 2;

    private static final Pattern VERSION = Pattern.compile(",\"v\":(\\d+)}$");
    private static final Pattern TYPE = Pattern.compile("^\\{\"type\":\"(\\w+)\"");

    /** Lifts a line from version {@code from()} to {@code from() + 1}. */
    interface Step {
        int from();

        String apply(String type, String line);
    }

    /**
     * v1 → v2 (M2b): stops, leveraged positions and savings deposits gained an {@code idempotencyKey}
     * (the {@code Idempotency-Key} header). Old lines had none, so it is {@code null}.
     */
    static final Step V1_IDEMPOTENCY_KEYS = new Step() {
        private final Set<String> types = Set.of("ConditionalPlaced", "MarginPositionOpened", "SavingsOpened");

        @Override
        public int from() {
            return 1;
        }

        @Override
        public String apply(String type, String line) {
            if (types.contains(type) && !line.contains("\"idempotencyKey\"")) {
                return line.substring(0, line.length() - 1) + ",\"idempotencyKey\":null}";
            }
            return line;
        }
    };

    private static final List<Step> STEPS = List.of(V1_IDEMPOTENCY_KEYS);

    private Upcasters() {
    }

    /** Marks a freshly serialised event with the current version. */
    static String stamp(String json) {
        return json.substring(0, json.length() - 1) + ",\"v\":" + CURRENT + "}";
    }

    /** Returns the line in the current format, without its version mark; fails on a line from a newer build. */
    public static String upcast(String line) {
        String body = line.strip();
        int v = 1;
        Matcher m = VERSION.matcher(body);
        if (m.find()) {
            v = Integer.parseInt(m.group(1));
            body = body.substring(0, m.start()) + "}";
        }
        if (v > CURRENT) {
            throw new IllegalStateException("journal line is version " + v + ", this build reads up to " + CURRENT);
        }
        Matcher t = TYPE.matcher(body);
        if (!t.find()) {
            throw new IllegalStateException("journal line has no leading type: " + line);
        }
        for (Step step : STEPS) {
            if (step.from() == v) {
                body = step.apply(t.group(1), body);
                v++;
            }
        }
        return body;
    }
}
