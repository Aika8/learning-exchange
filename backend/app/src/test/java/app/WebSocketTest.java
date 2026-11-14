package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.WebSocket;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/** The stream side of the contract: messages match {@code Ws*Message} schemas and a trade arrives within a tick or two. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT,
        properties = {"exchange.journal=memory", "exchange.bots-enabled=false"})
class WebSocketTest {

    @LocalServerPort
    int port;

    @Autowired
    JsonMapper json;

    @Test
    void subscriberGetsSnapshotThenTradeAndBookUpdates() throws Exception {
        HttpClient http = HttpClient.newHttpClient();
        String a = login(http, "ws-a");
        String b = login(http, "ws-b");
        BlockingQueue<String> inbox = new LinkedBlockingQueue<>();
        WebSocket ws = http.newWebSocketBuilder()
                .buildAsync(URI.create("ws://localhost:" + port + "/ws?token=" + b), new WebSocket.Listener() {
                    final StringBuilder buf = new StringBuilder();

                    @Override
                    public CompletionStage<?> onText(WebSocket w, CharSequence data, boolean last) {
                        buf.append(data);
                        if (last) {
                            inbox.add(buf.toString());
                            buf.setLength(0);
                        }
                        w.request(1);
                        return null;
                    }
                }).get(5, TimeUnit.SECONDS);
        for (String ch : new String[] {"market.SILK-SPARK.book", "market.SILK-SPARK.trades", "clock", "account.acc-ws-b"}) {
            ws.sendText("{\"op\":\"subscribe\",\"channel\":\"" + ch + "\"}", true).get();
        }
        ws.sendText("{\"op\":\"subscribe\",\"channel\":\"account.acc-ws-a\"}", true).get();

        post(http, a, "{\"instrument\":\"SILK-SPARK\",\"side\":\"SELL\",\"type\":\"LIMIT\",\"price\":10200,\"qty\":2}");
        long placed = System.currentTimeMillis();
        post(http, b, "{\"instrument\":\"SILK-SPARK\",\"side\":\"BUY\",\"type\":\"MARKET\",\"qty\":2}");

        boolean sawTrade = false;
        boolean sawFilledBook = false;
        boolean sawAccount = false;
        boolean sawForbidden = false;
        long deadline = System.currentTimeMillis() + 3_000;
        while (System.currentTimeMillis() < deadline && !(sawTrade && sawFilledBook && sawAccount && sawForbidden)) {
            String raw = inbox.poll(200, TimeUnit.MILLISECONDS);
            if (raw == null) {
                continue;
            }
            JsonNode m = json.readTree(raw);
            String ch = m.get("channel").asString();
            if (m.has("error")) {
                ContractTest.assertValid("WsErrorMessage", raw);
                sawForbidden |= ch.equals("account.acc-ws-a");
            } else if (ch.endsWith(".trades")) {
                ContractTest.assertValid("WsTradesMessage", raw);
                if (!m.get("data").isEmpty() && m.get("data").get(0).get("price").asLong() == 10200) {
                    sawTrade = true;
                    assertTrue(System.currentTimeMillis() - placed < 1_000, "trade must arrive within a market-data tick or so");
                }
            } else if (ch.endsWith(".book")) {
                ContractTest.assertValid("WsBookMessage", raw);
                sawFilledBook |= m.get("data").get("lastPrice").asLong(0) == 10200;
            } else if (ch.equals("clock")) {
                ContractTest.assertValid("WsClockMessage", raw);
            } else {
                ContractTest.assertValid("WsAccountMessage", raw);
                sawAccount |= m.get("data").get("reasons").toString().contains("TRADE");
            }
        }
        ws.abort();
        assertTrue(sawTrade, "trade message");
        assertTrue(sawFilledBook, "book update after the trade");
        assertTrue(sawAccount, "account nudge");
        assertTrue(sawForbidden, "someone else's account channel is refused");
    }

    private String login(HttpClient http, String name) throws Exception {
        HttpResponse<String> r = http.send(HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/auth/dev-login"))
                .POST(HttpRequest.BodyPublishers.ofString("{\"name\":\"" + name + "\"}"))
                .header("Content-Type", "application/json").build(), HttpResponse.BodyHandlers.ofString());
        return json.readTree(r.body()).get("token").asString();
    }

    private void post(HttpClient http, String token, String body) throws Exception {
        HttpResponse<String> r = http.send(HttpRequest.newBuilder(URI.create("http://localhost:" + port + "/api/v1/orders"))
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .header("Content-Type", "application/json").header("Authorization", "Bearer " + token).build(),
                HttpResponse.BodyHandlers.ofString());
        assertEquals(201, r.statusCode(), r.body());
    }
}
