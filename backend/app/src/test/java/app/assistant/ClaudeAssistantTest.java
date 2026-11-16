package app.assistant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.assistant.AdviceGuard;
import application.assistant.Assistant;
import application.assistant.Facts;
import application.assistant.FallbackAssistant;
import application.assistant.TemplateAssistant;
import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** The Claude adapter against a fake HTTP transport: the real API is never called in tests (no key in CI). */
class ClaudeAssistantTest {

    record Sent(URI uri, Map<String, String> headers, String body) {}

    final JsonMapper json = JsonMapper.builder().build();
    final List<Sent> sent = new ArrayList<>();
    final Facts facts = Facts.builder().add("statement.fees", 120, Facts.Kind.MONEY).build();

    ClaudeAssistant with(int status, String reply) {
        return new ClaudeAssistant((uri, headers, body) -> {
            sent.add(new Sent(uri, headers, body));
            return new ClaudeAssistant.Transport.Response(status, reply);
        }, "https://fake.local/", "test-key", "claude-haiku-5-5", 400, json);
    }

    static String reply(String text) {
        return "{\"id\":\"msg_1\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\""
                + text + "\"}],\"stop_reason\":\"end_turn\"}";
    }

    @Test
    void sendsFactsAsDataWithTheConfiguredModelAndReadsTheText() {
        var a = with(200, reply("You paid 1.20 SPARK in fees.")).answer(
                new Assistant.Question("Сколько комиссий?", "en", Assistant.Persona.HELPER), facts);
        assertEquals("You paid 1.20 SPARK in fees.", a.text());
        assertEquals(Assistant.Source.CLAUDE, a.source());
        assertEquals("claude-haiku-5-5", a.model());
        Sent s = sent.getFirst();
        assertEquals(URI.create("https://fake.local/v1/messages"), s.uri());
        assertEquals("test-key", s.headers().get("x-api-key"));
        assertEquals("2023-06-01", s.headers().get("anthropic-version"));
        JsonNode body = json.readTree(s.body());
        assertEquals("claude-haiku-5-5", body.get("model").asString());
        assertTrue(body.get("system").asString().contains("Never give investment advice"));
        String user = body.get("messages").get(0).get("content").asString();
        assertTrue(user.contains("<facts>\nstatement.fees=120 (money)\n</facts>"), user);
    }

    @Test
    void anErrorStatusFallsBackToTheTemplate() {
        ClaudeAssistant claude = with(529, "{\"type\":\"error\"}");
        assertThrows(IllegalStateException.class, () -> claude.answer(new Assistant.Question("x", "ru", null), facts));
        var a = new FallbackAssistant(claude, new TemplateAssistant(), new AdviceGuard())
                .answer(new Assistant.Question("Сколько комиссий?", "ru", null), facts);
        assertEquals(Assistant.Source.TEMPLATE, a.source());
    }

    @Test
    void adviceFromTheModelIsReplaced() {
        var a = new FallbackAssistant(with(200, reply("Купите SILK сейчас.")), new TemplateAssistant(), new AdviceGuard())
                .answer(new Assistant.Question("Сколько комиссий?", "ru", null), facts);
        assertEquals(Assistant.Source.TEMPLATE, a.source());
        assertTrue(a.guarded());
    }
}
