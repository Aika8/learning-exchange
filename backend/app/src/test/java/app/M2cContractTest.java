package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import application.SimulationClock;
import application.TradingService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import tools.jackson.databind.JsonNode;

/**
 * M2c endpoints against {@code api/openapi.yaml}: an order with a journal note and the session review, ATR, funds with
 * TER charged by the clock, and a dividend with tax withheld in the statement (SILK pays, holders at the ex-date open).
 */
@org.junit.jupiter.api.TestMethodOrder(org.junit.jupiter.api.MethodOrderer.MethodName.class) // inherited M2a checks first, at the starting rate
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false", "exchange.economy-seed=8"}) // own context: it moves the clock
class M2cContractTest extends ContractTest {

    static final long DAY = 60_000;

    @Autowired
    SimulationClock clock;

    @Autowired
    TradingService market;

    @Test
    void zM2cEndpointsAnswerAsTheContractSays() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"m2c\"}", 200, "LoginResponse").get("token").asString();
        String other = call("POST", "/auth/dev-login", null, "{\"name\":\"m2c other\"}", 200, "LoginResponse").get("token").asString();
        call("POST", "/me/deposits", other, "{\"asset\":\"SILK\",\"amount\":100}", 200, "AccountDetails");
        call("POST", "/me/deposits", other, "{\"asset\":\"FORGE\",\"amount\":100}", 200, "AccountDetails");
        call("POST", "/orders", other, "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":10000,\"qty\":20}", 201, "Order");
        call("POST", "/orders", other, "{\"instrument\":\"FORGE-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":25000,\"qty\":5}", 201, "Order");
        call("POST", "/orders", me, "{\"instrument\":\"FORGE-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":1}", 201, "Order");
        call("POST", "/orders", me, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":10,"
                + "\"journal\":{\"why\":\"breakout\",\"marketState\":\"TREND_UP\",\"mood\":\"FOMO\",\"plannedRisk\":5000}}", 201, "Order");
        call("POST", "/orders", me, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":1,"
                + "\"journal\":{\"mood\":\"GREEDY\"}}", 400, "Problem");

        JsonNode review = call("GET", "/session-review", me, null, 200, "SessionReview");
        assertEquals(1, review.get("annotated").asInt(), review.toString());
        assertEquals("FOMO", review.get("byMood").get(0).get("key").asString(), review.toString());

        for (int d = 0; d < 120; d += 2) {
            clock.resumeFrom(clock.now() + 2 * DAY, false, 1);
            market.runEconomy();
            market.accrueInterest();
            // a trade a day keeps candles coming for the ATR
            call("POST", "/orders", other, "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":"
                    + (10_000 + (d % 7) * 40) + ",\"qty\":1}", 201, "Order");
            call("POST", "/orders", me, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":1}", 201, "Order");
        }

        JsonNode atr = call("GET", "/instruments/SILK-SPARK/atr", null, null, 200, "Atr");
        assertTrue(atr.get("ready").asBoolean(), atr.toString());
        call("GET", "/instruments/NOPE/atr", null, null, 404, "Problem");

        callArray("GET", "/funds", null, 200, "Fund");
        JsonNode act = call("GET", "/funds/ACT-SPARK", null, null, 200, "Fund");
        assertTrue(act.get("feesPaid").asLong() > 0, act.toString());
        call("GET", "/funds/NOPE", null, null, 404, "Problem");

        JsonNode silk = call("GET", "/companies/SILK-SPARK", null, null, 200, "Company");
        assertTrue(silk.get("dividends").size() >= 1, silk.toString());
        JsonNode st = call("GET", "/statement", me, null, 200, "Statement");
        assertTrue(st.get("totals").get("taxWithheld").asLong() > 0, st.get("totals").toString());
        callArray("GET", "/economy/calendar", null, 200, "CalendarEntry");
    }
}
