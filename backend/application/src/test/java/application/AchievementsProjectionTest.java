package application;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import engine.Instrument;
import engine.Order;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class AchievementsProjectionTest {

    private static final List<Instrument> I = List.of(Instrument.SILK_SPARK);
    private static final Map<String, Long> START = Map.of("SPARK", 10_000_000L, "SILK", 1_000L);

    private static AchievementsProjection.Achievement of(List<AchievementsProjection.Achievement> list, AchievementsProjection.Id id) {
        return list.stream().filter(a -> a.id() == id).findFirst().orElseThrow();
    }

    @Test
    void aTradeUnlocksFirstTradeForBothSidesAndReplayGivesTheSame() throws Exception {
        InMemoryJournal journal = new InMemoryJournal();
        ManualClock clock = new ManualClock(1_000);
        List<AchievementsProjection.Achievement> before;
        String buyer;
        try (ExchangeService s = new ExchangeService(I, journal, clock, START)) {
            String seller = s.login("seller").accountId();
            buyer = s.login("buyer").accountId();
            assertFalse(of(s.achievements(buyer), AchievementsProjection.Id.FIRST_TRADE).unlocked());
            s.place(seller, "SILK-SPARK", Order.Side.SELL, Order.Type.LIMIT, 10_000, 5, null);
            clock.advance(10);
            s.place(buyer, "SILK-SPARK", Order.Side.BUY, Order.Type.MARKET, 0, 2, null);
            before = s.achievements(buyer);
            var first = of(before, AchievementsProjection.Id.FIRST_TRADE);
            assertTrue(first.unlocked());
            assertEquals(1_010L, first.at());
            assertTrue(of(s.achievements(seller), AchievementsProjection.Id.FIRST_TRADE).unlocked());
            assertEquals(1, of(before, AchievementsProjection.Id.DIVERSIFIED_3).progress());
        }
        try (ExchangeService again = new ExchangeService(I, journal, clock, START)) {
            assertEquals(before, again.achievements(buyer));
        }
    }

    @Test
    void unknownAccountHasAllLockedWithTargets() {
        var list = new AchievementsProjection().achievements("nobody");
        assertEquals(AchievementsProjection.Id.values().length, list.size());
        assertTrue(list.stream().noneMatch(AchievementsProjection.Achievement::unlocked));
        assertEquals(5, of(list, AchievementsProjection.Id.JOURNAL_5).target());
    }
}
