package app.assistant;

import application.TradingService;
import application.assistant.AdviceGuard;
import application.assistant.Assistant;
import application.assistant.FactsCollector;
import application.assistant.FallbackAssistant;
import application.assistant.TemplateAssistant;
import java.time.Duration;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import tools.jackson.databind.json.JsonMapper;

/**
 * Wires the assistant (ADR-0013): Claude when {@code ANTHROPIC_API_KEY} is set in the environment, the template
 * otherwise; always behind the fallback and the advice guard. Model and URL come from {@code assistant.*} properties.
 *
 * <p>Pattern: Factory — the choice of adapter is made once, here.
 */
@Configuration
public class AssistantConfig {

    private static final Logger log = LoggerFactory.getLogger(AssistantConfig.class);

    @Bean
    Assistant assistant(@Value("${assistant.model:claude-haiku-5-5}") String model,
                        @Value("${assistant.base-url:https://api.anthropic.com}") String baseUrl,
                        @Value("${assistant.max-tokens:400}") int maxTokens,
                        @Value("${assistant.use-key:true}") boolean useKey,
                        JsonMapper json) {
        String key = System.getenv("ANTHROPIC_API_KEY");
        Assistant primary = null;
        if (useKey && key != null && !key.isBlank()) {
            primary = new ClaudeAssistant(ClaudeAssistant.Transport.jdk(Duration.ofSeconds(20)), baseUrl, key, model, maxTokens, json);
            log.info("assistant: {} with template fallback", model);
        } else {
            log.info("assistant: template only (no ANTHROPIC_API_KEY)");
        }
        return new FallbackAssistant(primary, new TemplateAssistant(), new AdviceGuard());
    }

    @Bean
    FactsCollector factsCollector(TradingService market) {
        return new FactsCollector(market);
    }
}
