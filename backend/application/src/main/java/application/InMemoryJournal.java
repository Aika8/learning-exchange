package application;

import engine.Event;
import java.util.ArrayList;
import java.util.List;

/** Journal kept in memory: for tests, and for running without a file. */
public final class InMemoryJournal implements Journal {

    private final List<Event> events = new ArrayList<>();

    @Override
    public synchronized void append(List<Event> batch) {
        events.addAll(batch);
    }

    @Override
    public synchronized List<Event> readAll() {
        return List.copyOf(events);
    }
}
