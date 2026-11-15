package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import app.journal.FileJournal;
import application.ExchangeService;
import application.ManualClock;
import engine.Event;
import engine.Exchange;
import engine.Instrument;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** ADR-0020: a journal written by M2a (no {@code v}, no idempotency keys) still replays after the upgrade. */
class JournalVersionsTest {

    @TempDir
    Path dir;

    private Path m2aJournal() throws Exception {
        Path copy = dir.resolve("journal.jsonl");
        try (var in = Objects.requireNonNull(getClass().getResourceAsStream("/journal/m2a.jsonl"))) {
            Files.copy(in, copy);
        }
        return copy;
    }

    @Test
    void anM2aJournalIsReadAndReplays() throws Exception {
        List<Event> events = new FileJournal(m2aJournal()).readAll();
        assertEquals(31, events.size());
        Event.SavingsOpened s = events.stream().filter(Event.SavingsOpened.class::isInstance)
                .map(Event.SavingsOpened.class::cast).findFirst().orElseThrow();
        assertNull(s.idempotencyKey());
        Exchange ex = Exchange.replay(Instrument.ALL, events);
        assertTrue(ex.ledger().available("acc-a~s1", "SPARK") > 100_000, "interest was accrued and replayed");
    }

    @Test
    void theServiceStartsOnAnM2aJournalAndAppendsVersion2Lines() throws Exception {
        Path file = m2aJournal();
        try (ExchangeService s = new ExchangeService(Instrument.ALL, new FileJournal(file), new ManualClock(1_763_200_000_000L),
                Map.of("SPARK", 10_000_000L))) {
            s.login("c");
            s.openSavings("acc-c", 1_000, "retry-1");
            s.openSavings("acc-c", 1_000, "retry-1");
            assertEquals(1, s.savings("acc-c").size());
        }
        List<String> lines = Files.readAllLines(file);
        assertTrue(lines.getFirst().indexOf("\"v\"") < 0, "old lines are not rewritten");
        assertTrue(lines.getLast().contains("\"v\":2"));
        assertEquals(new FileJournal(file).readAll().size(), lines.size());
    }

    @Test
    void aLineFromANewerBuildFailsLoudly() throws Exception {
        Path file = dir.resolve("future.jsonl");
        Files.writeString(file, "{\"type\":\"AccountOpened\",\"ts\":1,\"account\":\"x\",\"name\":\"x\",\"v\":99}\n");
        assertThrows(IllegalStateException.class, () -> new FileJournal(file).readAll());
    }
}
