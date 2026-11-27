package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import app.bff.Catalogue;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import tools.jackson.databind.JsonNode;

/**
 * LE-097: {@code POST /assistant/ask} answers «what is X?» from {@code docs/lore/glossary.yaml} (through the loaded
 * {@link Catalogue}) and still validates against {@code api/openapi.yaml}. Expected texts come from the catalogue, so a
 * reworded definition does not break the test.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false", "assistant.use-key=false"})
class AssistantGlossaryContractTest extends ContractTest {

    @Autowired
    Catalogue catalogue;

    private Catalogue.Term term(String id) {
        return catalogue.terms().stream().filter(t -> t.id().equals(id)).findFirst().orElseThrow();
    }

    private JsonNode ask(String token, String body) throws Exception {
        return call("POST", "/assistant/ask", token, body, 200, "AssistantAnswer");
    }

    @Test
    void termQuestionsAnswerWithTheGlossaryDefinition() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"glossary\"}", 200, "LoginResponse").get("token").asString();
        Catalogue.Term spread = term("spread");

        JsonNode ru = ask(me, "{\"question\":\"Что такое спред?\",\"lang\":\"ru\"}");
        assertEquals("TEMPLATE", ru.get("source").asString());
        assertEquals(spread.real().ru() + " — " + spread.definition().ru(), ru.get("answer").asString());
        assertTrue(ru.get("disclaimer").asString().contains("не инвестиционный совет"), ru.toString());

        JsonNode en = ask(me, "{\"question\":\"What is the spread?\",\"lang\":\"en\"}");
        assertEquals(spread.real().en() + " — " + spread.definition().en(), en.get("answer").asString());

        JsonNode lore = ask(me, "{\"question\":\"What is the Chasm?\",\"lang\":\"en\",\"persona\":\"CHRONICLER\"}");
        assertEquals(spread.lore().en() + " (" + spread.real().en() + ") — " + spread.definition().en(),
                lore.get("answer").asString());

        Catalogue.Term stop = term("stop-loss");
        JsonNode stopLoss = ask(me, "{\"question\":\"what is a stop loss order\",\"lang\":\"en\"}");
        assertEquals(stop.real().en() + " — " + stop.definition().en(), stopLoss.get("answer").asString());

        Catalogue.Term tax = term("income-tax");
        JsonNode bracket = ask(me, "{\"question\":\"Что значит налог на доход?\",\"lang\":\"ru\"}");
        assertEquals(tax.real().ru() + " — " + tax.definition().ru(), bracket.get("answer").asString());
    }

    @Test
    void anUnknownWordSaysSoAndGivesTheNumbers() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"glossary unknown\"}", 200, "LoginResponse").get("token").asString();
        JsonNode a = ask(me, "{\"question\":\"Что такое квазар?\",\"lang\":\"ru\"}");
        assertTrue(a.get("answer").asString().startsWith("Этого слова я пока не знаю"), a.toString());
        assertTrue(a.get("answer").asString().contains("заявок"), a.toString());
    }
}
