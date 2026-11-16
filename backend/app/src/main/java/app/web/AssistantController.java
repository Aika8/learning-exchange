package app.web;

import application.AchievementsProjection;
import application.TradingService;
import application.assistant.Assistant;
import application.assistant.FactsCollector;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** REST adapter for {@code /assistant/ask} and {@code /achievements} (M4). Pattern: Adapter (driving side). */
@RestController
@RequestMapping("/api/v1")
public class AssistantController {

    public record GameFacts(Integer voyages, Integer wins, Long expectancyRx100, Long fees, Long spreadPaid, Long result,
                            Long dayReturnBps, Long basketReturnBps, Integer gapsThroughStop) {}

    public record AskRequest(String question, String lang, String persona, GameFacts game) {}

    public record FactDto(String key, String value) {}

    public record AnswerDto(String answer, String source, String model, String disclaimer, boolean guarded, List<FactDto> facts) {}

    private final TradingService market;
    private final DevAuth auth;
    private final Assistant assistant;
    private final FactsCollector facts;

    public AssistantController(TradingService market, DevAuth auth, Assistant assistant, FactsCollector facts) {
        this.market = market;
        this.auth = auth;
        this.assistant = assistant;
        this.facts = facts;
    }

    @PostMapping("/assistant/ask")
    public AnswerDto ask(@RequestHeader(value = "Authorization", required = false) String authz, @RequestBody AskRequest body) {
        String id = auth.accountId(authz);
        if (body == null || body.question() == null || body.question().isBlank() || body.question().length() > 500) {
            throw new ApiController.BadRequest("question is required, at most 500 characters");
        }
        if (body.lang() != null && !List.of("ru", "en").contains(body.lang())) {
            throw new ApiController.BadRequest("lang is ru or en");
        }
        Assistant.Persona persona;
        try {
            persona = body.persona() == null ? Assistant.Persona.HELPER : Assistant.Persona.valueOf(body.persona());
        } catch (IllegalArgumentException e) {
            throw new ApiController.BadRequest("persona is HELPER or CHRONICLER");
        }
        Map<String, Long> game = null;
        if (body.game() != null) {
            GameFacts g = body.game();
            game = new LinkedHashMap<>();
            game.put("voyages", g.voyages() == null ? null : g.voyages().longValue());
            game.put("wins", g.wins() == null ? null : g.wins().longValue());
            game.put("expectancyRx100", g.expectancyRx100());
            game.put("fees", g.fees());
            game.put("spreadPaid", g.spreadPaid());
            game.put("result", g.result());
            game.put("dayReturnBps", g.dayReturnBps());
            game.put("basketReturnBps", g.basketReturnBps());
            game.put("gapsThroughStop", g.gapsThroughStop() == null ? null : g.gapsThroughStop().longValue());
        }
        Assistant.Answer a = assistant.answer(new Assistant.Question(body.question(), body.lang(), persona), facts.collect(id, game));
        return new AnswerDto(a.text(), a.source().name(), a.model(), a.disclaimer(), a.guarded(),
                a.facts().stream().map(f -> new FactDto(f.key(), f.value())).toList());
    }

    @GetMapping("/achievements")
    public List<AchievementsProjection.Achievement> achievements(@RequestHeader(value = "Authorization", required = false) String authz) {
        return market.achievements(auth.accountId(authz));
    }
}
