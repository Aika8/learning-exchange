package app.config;

import java.util.Map;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("exchange")
public record ExchangeProperties(String journal, String botsFile, boolean botsEnabled, Map<String, Long> startingBalance) {
}
