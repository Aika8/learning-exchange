package bots;

import java.util.List;
import java.util.Map;

/** Parsed {@code bots.yaml}. */
public record BotConfig(long seed, String instrument, long tickMillis, FairValueConfig fairValue, List<BotSpec> bots) {

    public record FairValueConfig(long start, double volatilityBps, long floor) {}

    /** One line of the file: {@code count} bots of one strategy with its parameters and their starting capital. */
    public record BotSpec(String name, String strategy, int count, Map<String, Long> capital, Map<String, Object> params) {}
}
