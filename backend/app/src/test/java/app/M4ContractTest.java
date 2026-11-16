package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import tools.jackson.databind.JsonNode;

/** M4 endpoints against {@code api/openapi.yaml}: the assistant (template, no key in tests) and achievements. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false", "assistant.use-key=false"})
class M4ContractTest extends ContractTest {

    @Test
    void zM4AssistantAndAchievementsAnswerAsTheContractSays() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"m4\"}", 200, "LoginResponse").get("token").asString();
        String other = call("POST", "/auth/dev-login", null, "{\"name\":\"m4 other\"}", 200, "LoginResponse").get("token").asString();

        JsonNode none = callArray("GET", "/achievements", me, 200, "Achievement");
        assertFalse(none.get(0).get("unlocked").asBoolean(), none.toString());

        call("POST", "/orders", other, "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":10000,\"qty\":5}", 201, "Order");
        call("POST", "/orders", me, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":2,"
                + "\"journal\":{\"mood\":\"FOMO\",\"plannedRisk\":1000}}", 201, "Order");

        JsonNode list = callArray("GET", "/achievements", me, 200, "Achievement");
        assertEquals("FIRST_TRADE", list.get(0).get("id").asString());
        assertTrue(list.get(0).get("unlocked").asBoolean(), list.toString());

        JsonNode a = call("POST", "/assistant/ask", me, "{\"question\":\"Как прошла сессия?\",\"lang\":\"ru\"}", 200, "AssistantAnswer");
        assertEquals("TEMPLATE", a.get("source").asString());
        assertTrue(a.get("answer").asString().contains("1 заявок"), a.toString());
        assertTrue(a.get("disclaimer").asString().contains("не инвестиционный совет"));

        JsonNode advice = call("POST", "/assistant/ask", me, "{\"question\":\"Should I buy SILK?\",\"lang\":\"en\"}", 200, "AssistantAnswer");
        assertTrue(advice.get("guarded").asBoolean());

        JsonNode game = call("POST", "/assistant/ask", me, "{\"question\":\"День\",\"persona\":\"CHRONICLER\",\"game\":"
                + "{\"voyages\":2,\"wins\":1,\"result\":1500,\"fees\":30,\"spreadPaid\":70}}", 200, "AssistantAnswer");
        assertTrue(game.get("answer").asString().startsWith("Летопись дня"), game.toString());

        call("POST", "/assistant/ask", me, "{\"question\":\"\"}", 400, "Problem");
        call("POST", "/assistant/ask", me, "{\"question\":\"x\",\"persona\":\"ORACLE\"}", 400, "Problem");
        call("POST", "/assistant/ask", null, "{\"question\":\"x\"}", 401, "Problem");
        call("GET", "/achievements", null, null, 401, "Problem");
    }
}
