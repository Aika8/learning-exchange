package engine;

import java.util.List;

/**
 * Answer to one {@link Command}: either the events it produced, or a rejection and no events.
 * {@code orderId} is set for an accepted, replayed (same idempotency key) or cancelled order.
 */
public record Outcome(List<Event> events, Rejection rejection, long orderId) {

    public Outcome {
        events = List.copyOf(events);
    }

    static Outcome ok(List<Event> events, long orderId) {
        return new Outcome(events, null, orderId);
    }

    static Outcome rejected(Rejection why) {
        return new Outcome(List.of(), why, 0);
    }

    public boolean accepted() {
        return rejection == null;
    }
}
