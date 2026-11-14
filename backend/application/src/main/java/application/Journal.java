package application;

import engine.Event;
import java.util.List;

/**
 * Port: the append-only event journal, the source of truth (ADR-0005). Adapters: a JSON-lines file in the app,
 * {@link InMemoryJournal} in tests.
 *
 * <p>Pattern: Repository / Journal — the core asks for "append" and "read all", never for a file or a table.
 */
public interface Journal {

    void append(List<Event> events);

    List<Event> readAll();
}
