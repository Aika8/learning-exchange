package bots;

import java.util.List;
import java.util.Map;

/** Parsed {@code bots.yaml}: one or more markets, each with its fair value and its bots. */
public record BotConfig(long seed, long tickMillis, List<MarketConfig> markets) {

    public record FairValueConfig(long start, double volatilityBps, long floor) {}

    /** The bots of one instrument and the fair value they quote around. */
    public record MarketConfig(String instrument, FairValueConfig fairValue, List<BotSpec> bots) {}

    /** One line of the file: {@code count} bots of one strategy with its parameters and their starting capital. */
    public record BotSpec(String name, String strategy, int count, Map<String, Long> capital, Map<String, Object> params) {}

    /** The first market (M1 files have only one). */
    public MarketConfig market() {
        return markets.getFirst();
    }
}
