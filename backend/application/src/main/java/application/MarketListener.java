package application;

import engine.Event;
import java.util.List;

/**
 * Pattern: Observer — WebSocket publishers and bots subscribe to journalled events instead of polling.
 * Called on the sequencer thread right after the events are journalled, so it must only enqueue, never block.
 */
@FunctionalInterface
public interface MarketListener {

    void onEvents(List<Event> events);
}
