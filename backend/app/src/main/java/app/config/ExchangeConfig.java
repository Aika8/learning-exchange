package app.config;

import app.journal.FileJournal;
import application.ExchangeService;
import application.InMemoryJournal;
import application.Journal;
import application.SimulationClock;
import engine.Instrument;
import java.nio.file.Path;
import java.util.List;
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
    ExchangeService exchangeService(Journal journal, SimulationClock clock, ExchangeProperties props) {
        return new ExchangeService(List.of(Instrument.SILK_SPARK), journal, clock, props.startingBalance());
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
