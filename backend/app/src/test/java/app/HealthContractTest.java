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

/** {@code GET /health} (LE-016) answers without auth, as {@code api/openapi.yaml} says, the way {@link ContractTest} checks. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false"})
class HealthContractTest {

    static final SchemaRegistry SCHEMAS = SchemaRegistry.withDialect(Dialects.getOpenApi31());

    @LocalServerPort
    int port;

    @Autowired
    JsonMapper json;

    final HttpClient http = HttpClient.newHttpClient();

    @Test
    void healthAnswersUpWithoutAuthAndCountsJournalEvents() throws Exception {
        JsonNode before = health();
        assertEquals("UP", before.get("status").asString());
        assertTrue(before.get("journalEvents").asLong() > 0, "bank capital is journalled at start: " + before);

        HttpResponse<String> login = send("POST", "/auth/dev-login", "{\"name\":\"health watcher\"}");
        assertEquals(200, login.statusCode(), login.body());

        JsonNode after = health();
        assertTrue(after.get("journalEvents").asLong() > before.get("journalEvents").asLong(),
                "a new account is journalled: " + before + " → " + after);
    }

    JsonNode health() throws Exception {
        HttpResponse<String> res = send("GET", "/health", null);
        assertEquals(200, res.statusCode(), res.body());
        for (String pointer : List.of("/components/schemas/Health",
                "/paths/~1health/get/responses/200/content/application~1json/schema")) {
            Schema schema = SCHEMAS.getSchema(SchemaLocation.of("classpath:openapi.yaml#" + pointer));
            List<Error> errors = schema.validate(res.body(), InputFormat.JSON);
            assertTrue(errors.isEmpty(), pointer + " violated: " + errors + " in " + res.body());
        }
        return json.readTree(res.body());
    }

    HttpResponse<String> send(String method, String path, String body) throws Exception {
        HttpRequest r = HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1" + path))
                .method(method, body == null ? HttpRequest.BodyPublishers.noBody() : HttpRequest.BodyPublishers.ofString(body))
                .header("Content-Type", "application/json")
                .build();
        return http.send(r, HttpResponse.BodyHandlers.ofString());
    }
}
