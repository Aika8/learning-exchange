package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import app.web.DevAuth;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** A Cyrillic name gets an ASCII dev token that a browser can put in a header, and it logs in. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false"})
class DevAuthNonAsciiNameTest {

    @LocalServerPort
    int port;

    @Autowired
    JsonMapper json;

    final HttpClient http = HttpClient.newHttpClient();

    @Test
    void cyrillicNameGetsAnAsciiTokenThatWorks() throws Exception {
        HttpResponse<String> login = http.send(HttpRequest.newBuilder(uri("/auth/dev-login"))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString("{\"name\":\"Асель\"}"))
                .build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(200, login.statusCode(), login.body());
        String token = json.readTree(login.body()).get("token").asString();
        assertTrue(token.chars().allMatch(c -> c < 128), () -> "token is not ASCII: " + token);

        HttpResponse<String> me = http.send(HttpRequest.newBuilder(uri("/me"))
                .header("Authorization", "Bearer " + token)
                .GET().build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(200, me.statusCode(), me.body());
        JsonNode body = json.readTree(me.body());
        assertEquals("Асель", body.get("name").asString());
        assertEquals("acc-асель", body.get("accountId").asString());
    }

    @Test
    void brokenEscapeIsUnauthorizedNotAServerError() throws Exception {
        HttpResponse<String> me = http.send(HttpRequest.newBuilder(uri("/me"))
                .header("Authorization", "Bearer dev-acc-%zz")
                .GET().build(), HttpResponse.BodyHandlers.ofString());
        assertEquals(401, me.statusCode(), me.body());
    }

    @Test
    void latinIdTokenIsUnchanged() {
        assertEquals("dev-acc-aika", DevAuth.tokenFor("acc-aika"));
    }

    URI uri(String path) {
        return URI.create("http://localhost:" + port + "/api/v1" + path);
    }
}
