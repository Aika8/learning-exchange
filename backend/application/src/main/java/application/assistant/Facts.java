package application.assistant;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * The facts an assistant may talk about, computed deterministically before any text is written (ADR-0013). Values
 * are integers (minor units, basis points, R × 100, counts) or codes; nothing here is computed by a model.
 */
public record Facts(List<Fact> facts) {

    public enum Kind { MONEY, BPS, RX100, COUNT, CODE }

    public record Fact(String key, String value, Kind kind) {}

    public Facts {
        facts = List.copyOf(facts);
    }

    public Optional<Fact> get(String key) {
        return facts.stream().filter(f -> f.key().equals(key)).findFirst();
    }

    public Optional<Long> number(String key) {
        return get(key).filter(f -> f.kind() != Kind.CODE).map(f -> Long.parseLong(f.value()));
    }

    public List<Fact> startingWith(String prefix) {
        return facts.stream().filter(f -> f.key().startsWith(prefix)).toList();
    }

    /** Facts as data lines for a prompt: {@code key=value (kind)}. */
    public String asData() {
        StringBuilder sb = new StringBuilder();
        for (Fact f : facts) {
            sb.append(f.key()).append('=').append(f.value()).append(" (").append(f.kind().name().toLowerCase()).append(")\n");
        }
        return sb.toString();
    }

    public static Builder builder() {
        return new Builder();
    }

    public static final class Builder {
        private final List<Fact> facts = new ArrayList<>();

        public Builder add(String key, long value, Kind kind) {
            facts.add(new Fact(key, Long.toString(value), kind));
            return this;
        }

        public Builder addIfPresent(String key, Long value, Kind kind) {
            return value == null ? this : add(key, value, kind);
        }

        public Builder code(String key, String value) {
            if (value != null) {
                facts.add(new Fact(key, value, Kind.CODE));
            }
            return this;
        }

        public Facts build() {
            return new Facts(facts);
        }
    }
}
