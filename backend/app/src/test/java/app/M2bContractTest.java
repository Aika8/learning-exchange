package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.SimulationClock;
import application.TradingService;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import tools.jackson.databind.JsonNode;

/**
 * M2b endpoints against {@code api/openapi.yaml}, after moving the simulation clock 200 bank days ahead so reports,
 * rate decisions and coupons have happened. Its own Spring context (another economy seed), so the M2a tests keep
 * their starting rates.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false", "exchange.economy-seed=7"})
class M2bContractTest extends ContractTest {

    static final long DAY = 60_000;

    @Autowired
    SimulationClock clock;

    @Autowired
    TradingService market;

    @Test
    void m2bEndpointsAnswerAsTheContractSays() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"m2b\"}", 200, "LoginResponse").get("token").asString();
        String other = call("POST", "/auth/dev-login", null, "{\"name\":\"m2b other\"}", 200, "LoginResponse").get("token").asString();
        call("POST", "/me/deposits", other, "{\"asset\":\"FORGE\",\"amount\":100}", 200, "AccountDetails");
        call("POST", "/me/deposits", other, "{\"asset\":\"HBND\",\"amount\":10}", 200, "AccountDetails");
        call("POST", "/orders", other, "{\"instrument\":\"FORGE-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":25000,\"qty\":5}", 201, "Order");
        call("POST", "/orders", me, "{\"instrument\":\"FORGE-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":2}", 201, "Order");

        for (int d = 0; d < 200; d += 5) {
            clock.resumeFrom(clock.now() + 5 * DAY, false, 1);
            market.runEconomy();
        }

        callArray("GET", "/instruments", null, 200, "Instrument");
        callArray("GET", "/instruments/FORGE-SPARK/candles?limit=30", null, 200, "Candle");
        callArray("GET", "/economy/calendar", null, 200, "CalendarEntry");
        JsonNode macro = call("GET", "/economy/rates", null, null, 200, "Macro");
        assertTrue(macro.get("decisions").size() >= 4, macro.toString());
        callArray("GET", "/companies", null, 200, "Company");
        JsonNode forge = call("GET", "/companies/FORGE-SPARK", null, null, 200, "Company");
        assertTrue(forge.get("reports").size() >= 2);
        call("GET", "/companies/NOPE", null, null, 404, "Problem");
        callArray("GET", "/bonds", null, 200, "Bond");
        JsonNode hbnd = call("GET", "/bonds/HBND-SPARK", null, null, 200, "Bond");
        assertTrue(hbnd.get("ytmBps").asLong() > 0 && hbnd.get("couponsPaid").asInt() >= 2, hbnd.toString());

        // statement has the coupons the other account received
        JsonNode st = call("GET", "/statement", other, null, 200, "Statement");
        assertTrue(st.get("totals").get("payouts").asLong() > 0, st.get("totals").toString());

        // real world + paper positions with an idempotency key
        JsonNode real = call("GET", "/real-world", null, null, 200, "RealWorld");
        assertTrue(real.get("quotes").get(0).get("source").get("sample").asBoolean());
        callArray("GET", "/real-world/history?symbol=USD/KZT", null, 200, "RealPoint");
        String body = "{\"symbol\":\"USD/KZT\",\"side\":\"BUY\",\"qty\":100}";
        var r = request("POST", "/real-world/paper-positions", me, body).header("Idempotency-Key", "p-1");
        HttpResponse<String> first = http.send(r.build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(201, first.statusCode(), first.body());
        assertValid("PaperPosition", first.body());
        HttpResponse<String> again = http.send(r.build(), HttpResponse.BodyHandlers.ofString());
        long id = json.readTree(first.body()).get("paperId").asLong();
        assertEquals(id, json.readTree(again.body()).get("paperId").asLong());
        callArray("GET", "/real-world/paper-positions", me, 200, "PaperPosition");
        assertEquals(1, json.readTree(http.send(request("GET", "/real-world/paper-positions", me, null).build(),
                HttpResponse.BodyHandlers.ofString()).body()).size());
        assertFalse(call("POST", "/real-world/paper-positions/" + id + "/close", me, null, 200, "PaperPosition").get("open").asBoolean());
        call("POST", "/real-world/paper-positions/" + id + "/close", me, null, 409, "Problem");
        call("POST", "/real-world/paper-positions/" + id + "/close", other, null, 403, "Problem");
        call("POST", "/real-world/paper-positions", me, "{\"symbol\":\"XXX/KZT\",\"side\":\"BUY\",\"qty\":1}", 404, "Problem");

        // BFFs: mobile has real names only, the game also lore names
        callArray("GET", "/bff/mobile/catalogue", null, 200, "CatalogueItem");
        JsonNode mobile = json.readTree(http.send(request("GET", "/bff/mobile/catalogue", null, null).build(), HttpResponse.BodyHandlers.ofString()).body());
        assertTrue(mobile.get(0).get("lore").isNull());
        JsonNode game = json.readTree(http.send(request("GET", "/bff/game/catalogue", null, null).build(), HttpResponse.BodyHandlers.ofString()).body());
        assertFalse(game.get(0).get("lore").isNull());
        callArray("GET", "/bff/mobile/glossary", null, 200, "GlossaryTerm");
        callArray("GET", "/bff/game/glossary", null, 200, "GlossaryTerm");
        JsonNode card = call("GET", "/bff/mobile/companies/FORGE-SPARK", me, null, 200, "MobileCompanyCard");
        assertNull(card.get("gapWarning").isNull() ? null : card.get("gapWarning"));
        call("GET", "/bff/mobile/companies/FORGE-SPARK", null, null, 401, "Problem");
    }

    @Test
    void idempotencyKeysOnStopsPositionsAndDeposits() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"m2b idem\"}", 200, "LoginResponse").get("token").asString();
        String stop = "{\"instrument\":\"SILK-SPARK\",\"kind\":\"STOP_MARKET\",\"side\":\"SELL\",\"qty\":1,\"triggerPrice\":9000}";
        long a = json.readTree(http.send(request("POST", "/conditional-orders", me, stop).header("Idempotency-Key", "s").build(),
                HttpResponse.BodyHandlers.ofString()).body()).get("conditionalId").asLong();
        long b = json.readTree(http.send(request("POST", "/conditional-orders", me, stop).header("Idempotency-Key", "s").build(),
                HttpResponse.BodyHandlers.ofString()).body()).get("conditionalId").asLong();
        assertEquals(a, b);
        String dep = "{\"amount\":1000}";
        long d1 = json.readTree(http.send(request("POST", "/savings", me, dep).header("Idempotency-Key", "d").build(),
                HttpResponse.BodyHandlers.ofString()).body()).get("depositId").asLong();
        long d2 = json.readTree(http.send(request("POST", "/savings", me, dep).header("Idempotency-Key", "d").build(),
                HttpResponse.BodyHandlers.ofString()).body()).get("depositId").asLong();
        assertEquals(d1, d2);
        HttpResponse<String> tooLong = http.send(request("POST", "/savings", me, dep).header("Idempotency-Key", "x".repeat(65)).build(),
                HttpResponse.BodyHandlers.ofString());
        assertEquals(400, tooLong.statusCode());
    }
}
