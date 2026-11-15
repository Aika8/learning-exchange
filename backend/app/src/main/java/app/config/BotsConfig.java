package app.config;

import application.SimulationClock;
import application.TradingService;
import bots.BotConfig;
import bots.BotFactory;
import bots.BotRunner;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Starts the bots from bots.yaml on a scheduler; off in tests ({@code exchange.bots-enabled=false}). */
@Configuration
@ConditionalOnProperty(name = "exchange.bots-enabled", havingValue = "true")
public class BotsConfig {

    private static final Logger log = LoggerFactory.getLogger(BotsConfig.class);

    @Bean
    BotRunner botRunner(TradingService market, SimulationClock clock, ExchangeProperties props) throws IOException {
        BotConfig cfg;
        try (InputStream in = Files.newInputStream(Path.of(props.botsFile()))) {
            cfg = BotFactory.parse(in);
        }
        BotRunner runner = BotFactory.runner(cfg, market, clock);
        log.info("{} bots on {} markets from {} (seed {})", runner.bots().size(), cfg.markets().size(), props.botsFile(), cfg.seed());
        ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor(
                Thread.ofPlatform().name("bots").daemon().factory());
        scheduler.scheduleWithFixedDelay(() -> {
            try {
                runner.tick();
            } catch (RuntimeException e) {
                log.warn("bot tick failed", e);
            }
        }, cfg.tickMillis(), cfg.tickMillis(), TimeUnit.MILLISECONDS);
        return runner;
    }
}
