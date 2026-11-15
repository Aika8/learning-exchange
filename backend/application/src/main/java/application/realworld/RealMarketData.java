package application.realworld;

import java.util.List;
import java.util.Optional;

/**
 * Port: read-only real-world market data (ADR-0015). Real quotes never enter the simulated order book; people can only
 * look at them and open paper («учебные») positions. Every value says where it came from and as of when.
 *
 * <p>Pattern: Ports &amp; Adapters + Anti-corruption layer — adapters translate a source's format into these records.
 * Adapters: {@code app.realworld.StaticSampleData} (recorded sample data, the default).
 */
public interface RealMarketData {

    /** Where the data comes from: shown on every screen with real data. */
    record Source(String id, String name, String url, String terms, boolean sample, boolean delayed) {}

    /**
     * A quote: {@code price} in minor units of {@code quoteCurrency} ({@code scale} decimals), e.g. USD/KZT 524.31 →
     * 52431 with scale 2.
     */
    record Quote(String symbol, String base, String quoteCurrency, long price, int scale, long asOf, Source source) {}

    record Point(long date, long price) {}

    record RateDecision(long date, long rateBps) {}

    /** The central bank's base rate and its decision calendar (past and announced). */
    record BaseRate(String bank, long rateBps, long asOf, List<RateDecision> history, List<Long> upcoming, Source source) {}

    /** No real data (tests, offline): every screen says "no data". */
    RealMarketData NONE = new RealMarketData() {
        @Override
        public List<Quote> quotes() {
            return List.of();
        }

        @Override
        public List<Point> history(String symbol) {
            return List.of();
        }

        @Override
        public Optional<BaseRate> baseRate() {
            return Optional.empty();
        }
    };

    List<Quote> quotes();

    default Optional<Quote> quote(String symbol) {
        return quotes().stream().filter(q -> q.symbol().equals(symbol)).findFirst();
    }

    List<Point> history(String symbol);

    Optional<BaseRate> baseRate();
}
