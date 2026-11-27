package app.journal;

import application.Journal;
import engine.Event;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Pattern: Decorator — counts the journal's events for the health check without reading the file again and without
 * widening the {@link Journal} port. See docs/adr/0005-event-sourcing-journal.md.
 *
 * <p>The count is set by {@link #readAll()} (the replay at start) and grows with every {@link #append(List)}.
 */
public final class CountingJournal implements Journal {

    private final Journal delegate;
    private final AtomicLong events = new AtomicLong();

    public CountingJournal(Journal delegate) {
        this.delegate = delegate;
    }

    @Override
    public synchronized void append(List<Event> batch) {
        delegate.append(batch);
        events.addAndGet(batch.size());
    }

    @Override
    public synchronized List<Event> readAll() {
        List<Event> all = delegate.readAll();
        events.set(all.size());
        return all;
    }

    /** Events in the journal as far as this process knows: replayed history plus what was appended since. */
    public long events() {
        return events.get();
    }
}
