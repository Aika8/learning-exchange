package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import tools.jackson.databind.JsonNode;

/**
 * LE-058: {@code GET /session-review} carries the trading mistakes of the period from
 * {@code application.review.TradingMistakes} and still validates against {@code api/openapi.yaml}.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false"})
class MistakesContractTest extends ContractTest {

    private static List<String> codes(JsonNode review) {
        List<String> out = new ArrayList<>();
        review.get("mistakes").forEach(m -> out.add(m.get("code").asString()));
        return out;
    }

    @Test
    void reviewListsTheMistakesOfThePeriod() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"mistakes me\"}", 200, "LoginResponse").get("token").asString();
        String other = call("POST", "/auth/dev-login", null, "{\"name\":\"mistakes other\"}", 200, "LoginResponse").get("token").asString();
        call("POST", "/me/deposits", other, "{\"asset\":\"SILK\",\"amount\":100}", 200, "AccountDetails");

        JsonNode before = call("GET", "/session-review", me, null, 200, "SessionReview");
        assertEquals(0, before.get("mistakes").size(), before.toString());

        // an entry, then a second buy at a lower price while the first is under water: averaging down; held at the
        // end with nothing covering it: no exit plan
        call("POST", "/orders", other, "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":10000,\"qty\":10}", 201, "Order");
        call("POST", "/orders", me, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":10}", 201, "Order");
        call("POST", "/orders", other, "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":9000,\"qty\":5}", 201, "Order");
        call("POST", "/orders", me, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":5}", 201, "Order");

        JsonNode review = call("GET", "/session-review", me, null, 200, "SessionReview");
        List<String> codes = codes(review);
        assertTrue(codes.contains("B6_AVERAGING_DOWN"), review.toString());
        assertTrue(codes.contains("B7_NO_EXIT_PLAN"), review.toString());
        long lastAt = Long.MIN_VALUE;
        for (JsonNode m : review.get("mistakes")) {
            assertEquals("SILK-SPARK", m.get("instrument").asString(), m.toString());
            assertTrue(m.get("detail").asString().contains("="), m.toString());
            assertTrue(m.get("at").asLong() >= lastAt, "time order: " + review.get("mistakes"));
            lastAt = m.get("at").asLong();
        }

        // the seller entered nothing, so their review has no mistakes
        JsonNode theirs = call("GET", "/session-review", other, null, 200, "SessionReview");
        assertEquals(List.of(), codes(theirs), theirs.toString());

        // a period that ends before the trades has none either
        JsonNode empty = call("GET", "/session-review?to=1", me, null, 200, "SessionReview");
        assertEquals(List.of(), codes(empty), empty.toString());
    }
}
