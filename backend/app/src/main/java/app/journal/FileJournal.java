package app.journal;

import application.Journal;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import engine.Event;
import java.io.BufferedWriter;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardOpenOption;
import java.util.ArrayList;
import java.util.List;
import tools.jackson.databind.json.JsonMapper;

/**
 * Journal adapter: one JSON object per line, appended and flushed per batch, read back in full on start.
 * Example line: {@code {"type":"OrderAccepted","ts":1763100000000,"orderId":7,...,"v":2}}; {@code v} is the
 * format version, and older lines are lifted by {@link Upcasters} on read.
 *
 * <p>Pattern: Adapter (driven side of Ports &amp; Adapters) for the {@link Journal} port; the engine's events stay free
 * of Jackson thanks to a mix-in. See docs/adr/0005-event-sourcing-journal.md.
 */
public final class FileJournal implements Journal {

    private final Path file;
    private final JsonMapper json = JsonMapper.builder().addMixIn(Event.class, EventMixin.class).build();
    private BufferedWriter out;

    public FileJournal(Path file) {
        this.file = file;
    }

    @Override
    public synchronized void append(List<Event> events) {
        try {
            if (out == null) {
                if (file.getParent() != null) {
                    Files.createDirectories(file.getParent());
                }
                out = Files.newBufferedWriter(file, StandardCharsets.UTF_8, StandardOpenOption.CREATE, StandardOpenOption.APPEND);
            }
            for (Event e : events) {
                out.write(Upcasters.stamp(json.writerFor(Event.class).writeValueAsString(e)));
                out.newLine();
            }
            out.flush();
        } catch (IOException e) {
            throw new UncheckedIOException("journal append failed: " + file, e);
        }
    }

    @Override
    public synchronized List<Event> readAll() {
        if (!Files.exists(file)) {
            return List.of();
        }
        try {
            List<Event> events = new ArrayList<>();
            for (String line : Files.readAllLines(file, StandardCharsets.UTF_8)) {
                if (!line.isBlank()) {
                    events.add(json.readValue(Upcasters.upcast(line), Event.class));
                }
            }
            return events;
        } catch (IOException e) {
            throw new UncheckedIOException("journal read failed: " + file, e);
        }
    }

    @JsonTypeInfo(use = JsonTypeInfo.Id.SIMPLE_NAME, property = "type")
    @JsonSubTypes({
            @JsonSubTypes.Type(Event.AccountOpened.class),
            @JsonSubTypes.Type(Event.FundsDeposited.class),
            @JsonSubTypes.Type(Event.OrderAccepted.class),
            @JsonSubTypes.Type(Event.TradeExecuted.class),
            @JsonSubTypes.Type(Event.OrderCancelled.class),
            @JsonSubTypes.Type(Event.OrderExpired.class),
            @JsonSubTypes.Type(Event.ClockChanged.class),
            @JsonSubTypes.Type(Event.ConditionalPlaced.class),
            @JsonSubTypes.Type(Event.ConditionalCancelled.class),
            @JsonSubTypes.Type(Event.ConditionalArmed.class),
            @JsonSubTypes.Type(Event.ConditionalTriggered.class),
            @JsonSubTypes.Type(Event.MarginPositionOpened.class),
            @JsonSubTypes.Type(Event.MarginCloseRequested.class),
            @JsonSubTypes.Type(Event.MarginStopOut.class),
            @JsonSubTypes.Type(Event.MarginPositionClosed.class),
            @JsonSubTypes.Type(Event.SavingsOpened.class),
            @JsonSubTypes.Type(Event.InterestAccrued.class),
            @JsonSubTypes.Type(Event.SavingsClosed.class),
            @JsonSubTypes.Type(Event.ConsensusPublished.class),
            @JsonSubTypes.Type(Event.EarningsReported.class),
            @JsonSubTypes.Type(Event.DividendAnnounced.class),
            @JsonSubTypes.Type(Event.InsiderTradeDisclosed.class),
            @JsonSubTypes.Type(Event.RateDecisionScheduled.class),
            @JsonSubTypes.Type(Event.RateDecided.class),
            @JsonSubTypes.Type(Event.MarketRegimeChanged.class),
            @JsonSubTypes.Type(Event.PaperPositionOpened.class),
            @JsonSubTypes.Type(Event.PaperPositionClosed.class),
            @JsonSubTypes.Type(Event.TradingStatusChanged.class),
            @JsonSubTypes.Type(Event.PayoutStarted.class),
            @JsonSubTypes.Type(Event.PayoutPaid.class),
            @JsonSubTypes.Type(Event.BondDefaulted.class)
    })
    @JsonIgnoreProperties(ignoreUnknown = true)
    abstract static class EventMixin {
    }
}
