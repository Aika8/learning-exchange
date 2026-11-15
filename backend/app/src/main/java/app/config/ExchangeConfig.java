package app.config;

import app.journal.FileJournal;
import application.ExchangeService;
import application.InMemoryJournal;
import application.Journal;
import application.SimulationClock;
import engine.Instrument;
import java.nio.file.Path;
import application.TradingService;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.LoggerFactory;
import app.bff.Catalogue;
import app.realworld.StaticSampleData;
import application.realworld.RealMarketData;
import tools.jackson.databind.json.JsonMapper;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/** Wires the hexagon: the core gets its driven adapters (journal, clock) here and nowhere else. */
@Configuration
@EnableConfigurationProperties(ExchangeProperties.class)
public class ExchangeConfig {

    @Bean
    SimulationClock simulationClock() {
        return new SimulationClock(System::currentTimeMillis, System.currentTimeMillis());
    }

    @Bean
    Journal journal(ExchangeProperties props) {
        return "memory".equals(props.journal()) ? new InMemoryJournal() : new FileJournal(Path.of(props.journal()));
    }

    @Bean(destroyMethod = "close")
    ExchangeService exchangeService(Journal journal, SimulationClock clock, ExchangeProperties props,
                                    RealMarketData realData) {
        ExchangeService.Options options = new ExchangeService.Options(props.bankCapital(),
                new TradingService.SavingsProduct("SPARK", props.savings().rateBps(), props.savings().dayMillis()),
                props.economySeed() == null ? 42 : props.economySeed(), ExchangeService.Options.ISSUER_CASH, realData);
        return new ExchangeService(Instrument.ALL, journal, clock, props.startingBalance(), options);
    }

    /** Real-world data (ADR-0015): the recorded sample until a live source's terms are checked. */
    @Bean
    RealMarketData realMarketData(JsonMapper json) {
        return new StaticSampleData(json);
    }

    @Bean
    Catalogue catalogue(ExchangeProperties props) {
        return new Catalogue(Path.of(props.catalogueFile()), Path.of(props.glossaryFile()));
    }

    /** The economy (reports, rate decisions, coupons, storms) runs on simulation time: a timer asks for due items. */
    @Bean(destroyMethod = "shutdownNow")
    ScheduledExecutorService economyTimer(TradingService market) {
        ScheduledExecutorService timer = Executors.newSingleThreadScheduledExecutor(
                Thread.ofPlatform().name("economy").daemon().factory());
        timer.scheduleWithFixedDelay(() -> {
            try {
                market.runEconomy();
            } catch (RuntimeException e) {
                LoggerFactory.getLogger(ExchangeConfig.class).warn("economy step failed", e);
            }
        }, 1, 1, TimeUnit.SECONDS);
        return timer;
    }

    /** Deposit interest is paid by a timer: once a second it asks the exchange to pay the bank days that passed. */
    @Bean(destroyMethod = "shutdownNow")
    ScheduledExecutorService interestTimer(TradingService market) {
        ScheduledExecutorService timer = Executors.newSingleThreadScheduledExecutor(
                Thread.ofPlatform().name("interest").daemon().factory());
        timer.scheduleWithFixedDelay(() -> {
            try {
                market.accrueInterest();
            } catch (RuntimeException e) {
                LoggerFactory.getLogger(ExchangeConfig.class).warn("interest accrual failed", e);
            }
        }, 1, 1, TimeUnit.SECONDS);
        return timer;
    }

    /** Dev CORS: the web client (Vite) and Expo web run on other localhost ports. */
    @Bean
    WebMvcConfigurer cors() {
        return new WebMvcConfigurer() {
            @Override
            public void addCorsMappings(CorsRegistry registry) {
                registry.addMapping("/api/**").allowedOriginPatterns("*").allowedMethods("*").allowedHeaders("*");
            }
        };
    }
}
