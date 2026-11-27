package app.web;

import app.journal.CountingJournal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** {@code GET /health} for a container health check (LE-016); no auth, no Spring Actuator (see DECISIONS.md). */
@RestController
@RequestMapping("/api/v1")
public class HealthController {

    public record Health(String status, long journalEvents) {
    }

    private final CountingJournal journal;

    public HealthController(CountingJournal journal) {
        this.journal = journal;
    }

    @GetMapping("/health")
    public Health health() {
        return new Health("UP", journal.events());
    }
}
