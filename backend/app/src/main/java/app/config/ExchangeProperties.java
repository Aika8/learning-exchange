package app.config;

import java.util.Map;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("exchange")
public record ExchangeProperties(String journal, String botsFile, boolean botsEnabled, Map<String, Long> startingBalance,
                                 Map<String, Long> bankCapital, Savings savings) {

    /** The savings product: annual rate in basis points and the length of one bank day in simulation ms. */
    public record Savings(long rateBps, long dayMillis) {}
}
