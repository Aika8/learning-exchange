package app.ws;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Objects;
import java.util.Set;

/**
 * Limits book snapshots sent to clients (M4 performance): at most one per instrument per {@code minMillis}, and never
 * the same snapshot twice in a row. A book that changed during the pause stays pending and goes out on the next
 * allowed tick, so the last state always reaches the client. Trades are not throttled (each print matters).
 *
 * <p>Pattern: Throttle (rate limiting with trailing edge). Used on the market-data tick thread only.
 */
final class BookThrottle {

    private final long minMillis;
    private final Map<String, Long> sentAt = new HashMap<>();
    private final Map<String, Object> lastSent = new HashMap<>();
    private final Set<String> pending = new HashSet<>();

    BookThrottle(long minMillis) {
        this.minMillis = minMillis;
    }

    /** The instrument's book changed. */
    void dirty(String instrument) {
        pending.add(instrument);
    }

    /** Instruments whose book may be sent now; they are no longer pending. */
    Set<String> due(long now) {
        Set<String> out = new HashSet<>();
        for (String i : pending) {
            Long at = sentAt.get(i);
            if (at == null || now - at >= minMillis) {
                out.add(i);
            }
        }
        pending.removeAll(out);
        return out;
    }

    /** Whether this snapshot differs from the one sent last; records it as sent if so. */
    boolean shouldSend(String instrument, Object snapshot, long now) {
        if (Objects.equals(lastSent.get(instrument), snapshot)) {
            return false;
        }
        lastSent.put(instrument, snapshot);
        sentAt.put(instrument, now);
        return true;
    }
}
