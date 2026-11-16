package application;

import engine.Accounts;
import engine.Event;
import java.util.ArrayList;
import java.util.EnumMap;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Achievements shared by the app and the game: both read the same account's events, so a stop placed in the app and
 * a stop placed on the ship are the same "Anchor dropped". Rebuilt from the journal on start like every read model,
 * so an old journal (any version the upcasters read) gives the same achievements.
 *
 * <p>Pattern: Event Sourcing projection / CQRS read model. See docs/adr/0005-event-sourcing-journal.md.
 * Not thread-safe: sequencer thread only.
 */
public final class AchievementsProjection implements MarketListener {

    public enum Id {
        FIRST_TRADE(1), FIRST_STOP(1), STOP_FIRED(1), JOURNAL_5(5), DIVERSIFIED_3(3), FIRST_SAVINGS(1), FIRST_DIVIDEND(1);

        public final int target;

        Id(int target) {
            this.target = target;
        }
    }

    public record Achievement(Id id, boolean unlocked, Long at, int progress, int target) {}

    private static final class Progress {
        final Map<Id, Long> unlockedAt = new EnumMap<>(Id.class);
        final Set<String> instruments = new HashSet<>();
        int notes;
    }

    private final Map<String, Progress> byAccount = new HashMap<>();

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            switch (e) {
                case Event.TradeExecuted t -> {
                    traded(t.buyer(), t.instrument(), t.ts());
                    traded(t.seller(), t.instrument(), t.ts());
                }
                case Event.ConditionalPlaced c -> unlock(c.account(), Id.FIRST_STOP, c.ts());
                case Event.ConditionalTriggered c -> unlock(c.account(), Id.STOP_FIRED, c.ts());
                case Event.OrderAnnotated a -> {
                    Progress p = of(a.account());
                    if (p != null && ++p.notes >= Id.JOURNAL_5.target) {
                        p.unlockedAt.putIfAbsent(Id.JOURNAL_5, a.ts());
                    }
                }
                case Event.SavingsOpened s -> unlock(s.account(), Id.FIRST_SAVINGS, s.ts());
                case Event.DividendPaid d -> unlock(d.holder(), Id.FIRST_DIVIDEND, d.ts());
                default -> { }
            }
        }
    }

    private void traded(String account, String instrument, long ts) {
        Progress p = of(account);
        if (p == null) {
            return;
        }
        p.unlockedAt.putIfAbsent(Id.FIRST_TRADE, ts);
        p.instruments.add(instrument);
        if (p.instruments.size() >= Id.DIVERSIFIED_3.target) {
            p.unlockedAt.putIfAbsent(Id.DIVERSIFIED_3, ts);
        }
    }

    private void unlock(String account, Id id, long ts) {
        Progress p = of(account);
        if (p != null) {
            p.unlockedAt.putIfAbsent(id, ts);
        }
    }

    private Progress of(String account) {
        if (account == null || Accounts.isSubAccount(account)) {
            return null;
        }
        return byAccount.computeIfAbsent(account, k -> new Progress());
    }

    public List<Achievement> achievements(String account) {
        Progress p = byAccount.getOrDefault(account, new Progress());
        List<Achievement> out = new ArrayList<>();
        for (Id id : Id.values()) {
            Long at = p.unlockedAt.get(id);
            int progress = switch (id) {
                case JOURNAL_5 -> Math.min(p.notes, id.target);
                case DIVERSIFIED_3 -> Math.min(p.instruments.size(), id.target);
                default -> at == null ? 0 : 1;
            };
            out.add(new Achievement(id, at != null, at, at != null ? id.target : progress, id.target));
        }
        return out;
    }
}
