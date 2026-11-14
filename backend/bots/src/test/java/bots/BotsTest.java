package bots;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.ExchangeService;
import application.InMemoryJournal;
import application.ManualClock;
import engine.Event;
import engine.Exchange;
import engine.Instrument;
import engine.Order;
import java.io.StringReader;
import java.util.List;
import java.util.Map;
import java.util.Random;
import org.junit.jupiter.api.Test;

class BotsTest {

    static final String YAML = """
            seed: 7
            instrument: SILK-SPARK
            tickMillis: 500
            fairValue: { start: 10000, volatilityBps: 5, floor: 100 }
            bots:
              - name: mm
                strategy: market-maker
                capital: { SPARK: 100000000, SILK: 10000 }
                params: { halfSpread: 10, step: 5, levels: 3, qty: 10, targetBase: 10000, skewPerUnit: 0.01 }
              - name: noise
                strategy: noise
                count: 3
                capital: { SPARK: 10000000, SILK: 500 }
                params: { activity: 0.8, maxQty: 5, marketShare: 0.6 }
            """;

    @Test
    void marketMakerQuotesBothSidesAroundFairValue() {
        MarketMaker mm = new MarketMaker(10, 5, 2, 10, 0, 0);
        List<Intent> intents = mm.decide(new MarketView("X", null, null, null, 10_000, List.of(), 0, 0, 0), new Random(1));

        assertTrue(intents.getFirst() instanceof Intent.CancelAllMine);
        List<Intent.Place> places = intents.stream().filter(i -> i instanceof Intent.Place).map(i -> (Intent.Place) i).toList();
        assertEquals(4, places.size());
        places.forEach(p -> assertTrue(p.side() == Order.Side.BUY ? p.price() < 10_000 : p.price() > 10_000));
    }

    @Test
    void marketMakerSkewsDownWhenItHoldsTooMuch() {
        MarketMaker mm = new MarketMaker(10, 5, 1, 10, 100, 1.0);
        List<Intent> heavy = mm.decide(new MarketView("X", null, null, null, 10_000, List.of(), 0, 0, 200), new Random(1));
        Intent.Place ask = (Intent.Place) heavy.stream().filter(i -> i instanceof Intent.Place p && p.side() == Order.Side.SELL).findFirst().orElseThrow();
        assertTrue(ask.price() < 10_000, "with 100 units too many the ask moves below fair value");
    }

    @Test
    void botsFromYamlTradeThroughThePortAndTheMarketIsDeterministic() throws Exception {
        List<Event> first = run();
        List<Event> second = run();

        assertTrue(first.stream().anyMatch(e -> e instanceof Event.TradeExecuted), "bots should trade");
        assertEquals(first, second, "same seed, same clock → same market");
        // Money is conserved and the journal replays.
        Exchange replayed = Exchange.replay(List.of(Instrument.SILK_SPARK), first);
        long deposited = first.stream().filter(e -> e instanceof Event.FundsDeposited d && d.asset().equals("SPARK"))
                .mapToLong(e -> ((Event.FundsDeposited) e).amount()).sum();
        assertEquals(deposited, replayed.ledger().totalOf("SPARK"));
        assertFalse(replayed.ledger().balances("exchange-fees").isEmpty(), "bots pay fees");
    }

    private static List<Event> run() throws Exception {
        InMemoryJournal journal = new InMemoryJournal();
        ManualClock clock = new ManualClock(0);
        try (ExchangeService s = new ExchangeService(List.of(Instrument.SILK_SPARK), journal, clock, Map.of("SPARK", 1_000_000L))) {
            BotConfig cfg = BotFactory.parse(new StringReader(YAML));
            BotRunner runner = new BotRunner(BotFactory.create(cfg, s),
                    new FairValue(cfg.fairValue().start(), cfg.fairValue().volatilityBps(), cfg.fairValue().floor(), cfg.seed()), clock);
            assertEquals(4, runner.bots().size());
            for (int i = 0; i < 100; i++) {
                clock.advance(500);
                runner.tick();
            }
        }
        return journal.readAll();
    }
}
