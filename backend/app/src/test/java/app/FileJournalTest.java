package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import app.journal.FileJournal;
import application.ExchangeService;
import application.ManualClock;
import engine.Instrument;
import engine.Order;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

/** The JSON-lines journal round-trips every event type and a restarted service sees the same state. */
class FileJournalTest {

    @TempDir
    Path dir;

    @Test
    void restartFromTheFileGivesTheSameState() throws Exception {
        Path file = dir.resolve("j/journal.jsonl");
        String before;
        try (ExchangeService s = new ExchangeService(List.of(Instrument.SILK_SPARK), new FileJournal(file), new ManualClock(5),
                Map.of("SPARK", 1_000_000L, "SILK", 100L))) {
            s.login("a");
            s.login("b");
            s.place("acc-a", "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 1_000, 10, "k");
            s.place("acc-b", "SILK-SPARK", Order.Side.BUY, Order.Type.MARKET, 0, 20, null);
            long id = s.place("acc-b", "SILK-SPARK", Order.Side.BUY, Order.Type.LIMIT, 900, 1, null).orderId();
            s.cancel("acc-b", id);
            before = s.balances("acc-a") + "" + s.balances("acc-b") + s.orders("acc-b", false, 10);
        }
        List<String> lines = Files.readAllLines(file);
        assertTrue(lines.stream().anyMatch(l -> l.contains("\"type\":\"TradeExecuted\"")));
        assertTrue(lines.stream().anyMatch(l -> l.contains("\"type\":\"OrderExpired\"")));
        assertTrue(lines.stream().noneMatch(l -> l.contains("decision")));

        FileJournal again = new FileJournal(file);
        try (ExchangeService s = new ExchangeService(List.of(Instrument.SILK_SPARK), again, new ManualClock(5),
                Map.of("SPARK", 1_000_000L, "SILK", 100L))) {
            assertEquals(before, s.balances("acc-a") + "" + s.balances("acc-b") + s.orders("acc-b", false, 10));
        }
    }
}
