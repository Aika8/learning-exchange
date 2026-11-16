package app.ws;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Set;
import org.junit.jupiter.api.Test;

class BookThrottleTest {

    @Test
    void sendsAtMostOncePerIntervalAndKeepsTheLastChangePending() {
        BookThrottle t = new BookThrottle(250);
        t.dirty("SILK");
        assertEquals(Set.of("SILK"), t.due(0));
        assertTrue(t.shouldSend("SILK", "v1", 0));
        t.dirty("SILK");
        assertEquals(Set.of(), t.due(100));      // too soon: still pending
        assertEquals(Set.of(), t.due(200));
        assertEquals(Set.of("SILK"), t.due(260)); // trailing edge: the change is not lost
        assertTrue(t.shouldSend("SILK", "v2", 260));
    }

    @Test
    void neverSendsTheSameSnapshotTwice() {
        BookThrottle t = new BookThrottle(0);
        assertTrue(t.shouldSend("SILK", "same", 0));
        assertFalse(t.shouldSend("SILK", "same", 1000));
        assertTrue(t.shouldSend("FORGE", "same", 1000));
    }
}
