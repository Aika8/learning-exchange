package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.networknt.schema.Error;
import com.networknt.schema.InputFormat;
import com.networknt.schema.Schema;
import com.networknt.schema.SchemaLocation;
import com.networknt.schema.SchemaRegistry;
import com.networknt.schema.dialect.Dialects;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * Every response of the REST adapter is validated against {@code api/openapi.yaml} (ADR-0003: the contract test that
 * keeps spec and implementation from drifting). Calls go over real HTTP.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false"})
class ContractTest {

    static final SchemaRegistry SCHEMAS = SchemaRegistry.withDialect(Dialects.getOpenApi31());
    static final String SPEC = "classpath:openapi.yaml";

    @LocalServerPort
    int port;

    @Autowired
    JsonMapper json;

    final HttpClient http = HttpClient.newHttpClient();

    @Test
    void everyEndpointAnswersAsTheContractSays() throws Exception {
        JsonNode login = call("POST", "/auth/dev-login", null, "{\"name\":\"Contract Tester\"}", 200, "LoginResponse");
        String token = login.get("token").asString();
        assertEquals("acc-contract-tester", login.get("account").get("accountId").asString());
        JsonNode seller = call("POST", "/auth/dev-login", null, "{\"name\":\"seller\"}", 200, "LoginResponse");
        String sellerToken = seller.get("token").asString();

        call("GET", "/me", token, null, 200, "AccountDetails");
        call("POST", "/me/deposits", token, "{\"asset\":\"SPARK\",\"amount\":500}", 200, "AccountDetails");
        callArray("GET", "/instruments", null, 200, "Instrument");
        call("GET", "/clock", null, null, 200, "Clock");
        call("PUT", "/clock", token, "{\"paused\":false,\"speed\":2}", 200, "Clock");

        call("POST", "/orders", sellerToken, "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":10100,\"qty\":3}", 201, "Order");
        JsonNode buy = call("POST", "/orders", token, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"LIMIT\",\"price\":10100,\"qty\":5}", 201, "Order");
        assertEquals("PARTIALLY_FILLED", buy.get("status").asString());
        JsonNode book = call("GET", "/instruments/SILK-SPARK/book?depth=5", null, null, 200, "BookSnapshot");
        assertEquals(10100, book.get("lastPrice").asLong());
        callArray("GET", "/instruments/SILK-SPARK/trades", null, 200, "Trade");
        callArray("GET", "/orders?open=true", token, 200, "Order");
        JsonNode cancelled = call("DELETE", "/orders/" + buy.get("orderId").asLong(), token, null, 200, "Order");
        assertEquals("CANCELLED", cancelled.get("status").asString());
        call("POST", "/orders", token, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":1}", 422, "Problem");
    }

    @Test
    void m2aEndpointsAnswerAsTheContractSays() throws Exception {
        String me = call("POST", "/auth/dev-login", null, "{\"name\":\"m2a\"}", 200, "LoginResponse").get("token").asString();
        String dealer = call("POST", "/auth/dev-login", null, "{\"name\":\"m2a dealer\"}", 200, "LoginResponse").get("token").asString();
        call("POST", "/me/deposits", dealer, "{\"asset\":\"AMBER\",\"amount\":1000}", 200, "AccountDetails");
        call("POST", "/orders", dealer, "{\"instrument\":\"AMBER-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":50000,\"qty\":100}", 201, "Order");
        call("POST", "/orders", dealer, "{\"instrument\":\"AMBER-SPARK\",\"side\":\"BUY\",\"type\":\"LIMIT\",\"price\":49000,\"qty\":100}", 201, "Order");

        // Conditional orders
        JsonNode stop = call("POST", "/conditional-orders", me, "{\"instrument\":\"SILK-SPARK\",\"kind\":\"STOP_LIMIT\",\"side\":\"SELL\",\"qty\":2,\"triggerPrice\":9000,\"limitPrice\":8900}", 201, "ConditionalOrder");
        assertEquals("WAITING", stop.get("state").asString());
        call("POST", "/conditional-orders", me, "{\"instrument\":\"SILK-SPARK\",\"kind\":\"TP_SL\",\"side\":\"SELL\",\"qty\":2,\"triggerPrice\":9000,\"activationPrice\":11000,\"offset\":50,\"protectiveSpread\":10}", 201, "ConditionalOrder");
        callArray("GET", "/conditional-orders", me, 200, "ConditionalOrder");
        assertEquals("CANCELLED", call("DELETE", "/conditional-orders/" + stop.get("conditionalId").asLong(), me, null, 200, "ConditionalOrder").get("state").asString());
        call("DELETE", "/conditional-orders/" + stop.get("conditionalId").asLong(), me, null, 409, "Problem");
        call("POST", "/conditional-orders", me, "{\"instrument\":\"SILK-SPARK\",\"kind\":\"SOMETIMES\",\"side\":\"SELL\",\"qty\":2}", 400, "Problem");

        // Leverage
        JsonNode instruments = json.readTree(http.send(request("GET", "/instruments", null, null).build(), HttpResponse.BodyHandlers.ofString()).body());
        assertEquals(4, instruments.get(1).get("maxLeverage").asInt());
        JsonNode pos = call("POST", "/margin/positions", me, "{\"instrument\":\"AMBER-SPARK\",\"side\":\"BUY\",\"qty\":10,\"leverage\":4}", 201, "MarginPosition");
        assertEquals(125_000 + 250, pos.get("collateral").asLong());
        callArray("GET", "/margin/positions", me, 200, "MarginPosition");
        JsonNode closed = call("POST", "/margin/positions/" + pos.get("positionId").asLong() + "/close", me, null, 200, "MarginPosition");
        assertEquals("CLOSED", closed.get("status").asString());
        call("POST", "/margin/positions", me, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"qty\":1,\"leverage\":2}", 422, "Problem");
        call("POST", "/margin/positions/999/close", me, null, 404, "Problem");

        // Savings
        JsonNode overview = call("GET", "/savings", me, null, 200, "SavingsOverview");
        assertEquals(1400, overview.get("product").get("rateBps").asInt());
        JsonNode dep = call("POST", "/savings", me, "{\"amount\":100000}", 201, "SavingsDeposit");
        call("GET", "/savings", me, null, 200, "SavingsOverview");
        assertEquals("CLOSED", call("POST", "/savings/" + dep.get("depositId").asLong() + "/close", me, null, 200, "SavingsDeposit").get("status").asString());
        call("POST", "/savings", me, "{\"amount\":999999999999}", 422, "Problem");

        // Statement
        JsonNode st = call("GET", "/statement", me, null, 200, "Statement");
        assertTrue(st.get("lines").size() >= 5, st.toString());
        call("GET", "/statement?from=0&to=1", me, null, 200, "Statement");
    }

    @Test
    void errorsAreProblemsWithTheContractedStatus() throws Exception {
        String token = call("POST", "/auth/dev-login", null, "{\"name\":\"errors\"}", 200, "LoginResponse").get("token").asString();

        call("GET", "/me", null, null, 401, "Problem");
        call("GET", "/me", "dev-acc-nobody", null, 401, "Problem");
        call("POST", "/auth/dev-login", null, "{\"name\":\"a/b\"}", 400, "Problem");
        assertEquals("INSUFFICIENT_FUNDS", call("POST", "/orders", token,
                "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":100,\"qty\":999999}", 422, "Problem").get("code").asString());
        call("POST", "/orders", token, "{\"instrument\":\"SILK-SPARK\",\"side\":\"UP\",\"type\":\"LIMIT\",\"price\":100,\"qty\":1}", 400, "Problem");
        call("POST", "/orders", token, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"LIMIT\",\"qty\":1}", 400, "Problem");
        call("DELETE", "/orders/424242", token, null, 404, "Problem");
        call("GET", "/instruments/NOPE/book", null, null, 404, "Problem");
        call("PUT", "/clock", token, "{\"paused\":false,\"speed\":0}", 400, "Problem");
    }

    @Test
    void sameIdempotencyKeyGivesTheSameOrder() throws Exception {
        String token = call("POST", "/auth/dev-login", null, "{\"name\":\"idem\"}", 200, "LoginResponse").get("token").asString();
        String body = "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"LIMIT\",\"price\":5000,\"qty\":1}";
        HttpRequest.Builder r = request("POST", "/orders", token, body).header("Idempotency-Key", "abc");
        long first = json.readTree(http.send(r.build(), HttpResponse.BodyHandlers.ofString()).body()).get("orderId").asLong();
        long second = json.readTree(http.send(r.build(), HttpResponse.BodyHandlers.ofString()).body()).get("orderId").asLong();
        assertEquals(first, second);
    }

    JsonNode call(String method, String path, String token, String body, int status, String schema) throws Exception {
        HttpResponse<String> res = http.send(request(method, path, token, body).build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(status, res.statusCode(), method + " " + path + " → " + res.body());
        assertValid(schema, res.body());
        return json.readTree(res.body());
    }

    void callArray(String method, String path, String token, int status, String itemSchema) throws Exception {
        HttpResponse<String> res = http.send(request(method, path, token, null).build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(status, res.statusCode(), method + " " + path + " → " + res.body());
        JsonNode array = json.readTree(res.body());
        assertTrue(array.isArray(), path + " should return an array");
        for (JsonNode item : array) {
            assertValid(itemSchema, json.writeValueAsString(item));
        }
    }

    HttpRequest.Builder request(String method, String path, String token, String body) {
        HttpRequest.Builder b = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1" + path))
                .method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body))
                .header("Content-Type", "application/json");
        if (token != null) {
            b.header("Authorization", "Bearer " + token);
        }
        return b;
    }

    static void assertValid(String schemaName, String body) {
        Schema schema = SCHEMAS.getSchema(SchemaLocation.of(SPEC + "#/components/schemas/" + schemaName));
        List<Error> errors = schema.validate(body, InputFormat.JSON);
        assertTrue(errors.isEmpty(), schemaName + " violated: " + errors + " in " + body);
    }
}
