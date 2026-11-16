package app.ws;

import app.web.DevAuth;
import app.web.Dto;
import application.MarketListener;
import application.TradingService;
import engine.Event;
import jakarta.annotation.PreDestroy;
import java.io.IOException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * WebSocket adapter for {@code api/asyncapi.yaml}. Subscribes to the core as a {@link MarketListener} and pushes
 * to clients once per market-data tick (100 ms): a fresh book snapshot when the book changed (throttled to one per
 * 250 ms per instrument by {@link BookThrottle}, M4), the new trades, the clock
 * when it changed, and an "account changed" nudge to the owner's channel.
 *
 * <p>Pattern: Observer (twice: the hub observes the core, clients observe channels). The listener only enqueues on
 * the sequencer thread; all I/O happens on the tick thread. See docs/adr/0003-contract-first-api.md and
 * 0006-single-writer-and-sim-clock.md.
 */
@Component
public class MarketDataHub extends TextWebSocketHandler implements MarketListener {

    static final long TICK_MILLIS = 100;
    private static final Logger log = LoggerFactory.getLogger(MarketDataHub.class);

    private final TradingService market;
    private final DevAuth auth;
    private final JsonMapper json;
    private final ConcurrentLinkedQueue<Event> inbox = new ConcurrentLinkedQueue<>();
    private final Map<String, Client> clients = new ConcurrentHashMap<>();
    private final ScheduledExecutorService ticker = Executors.newSingleThreadScheduledExecutor(
            Thread.ofPlatform().name("market-data").daemon().factory());
    private long lastClockPush;
    /** Book snapshots to clients at most every 250 ms per instrument, never a repeat (M4). */
    static final long BOOK_MIN_MILLIS = 250;
    private final BookThrottle books = new BookThrottle(BOOK_MIN_MILLIS);

    public MarketDataHub(TradingService market, DevAuth auth, JsonMapper json) {
        this.market = market;
        this.auth = auth;
        this.json = json;
        market.subscribe(this);
        ticker.scheduleAtFixedRate(this::tickSafely, TICK_MILLIS, TICK_MILLIS, TimeUnit.MILLISECONDS);
    }

    @PreDestroy
    void stop() {
        ticker.shutdownNow();
    }

    @Override
    public void onEvents(List<Event> events) {
        inbox.addAll(events);
    }

    // ---- connections ----

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String token = null;
        String query = session.getUri() == null ? null : session.getUri().getQuery();
        if (query != null) {
            for (String part : query.split("&")) {
                if (part.startsWith("token=")) {
                    token = java.net.URLDecoder.decode(part.substring(6), java.nio.charset.StandardCharsets.UTF_8);
                }
            }
        }
        String accountId = null;
        if (token != null) {
            try {
                accountId = auth.accountId(token);
            } catch (DevAuth.Unauthorized e) {
                accountId = null;
            }
        }
        clients.put(session.getId(), new Client(new ConcurrentWebSocketSessionDecorator(session, 5_000, 1 << 20), accountId));
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        clients.remove(session.getId());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) {
        Client c = clients.get(session.getId());
        if (c == null) {
            return;
        }
        String channel = "";
        try {
            JsonNode msg = json.readTree(message.getPayload());
            String op = msg.path("op").asString("");
            channel = msg.path("channel").asString("");
            if (!isKnown(channel)) {
                error(c, channel, "BAD_REQUEST", "unknown channel");
                return;
            }
            if (channel.startsWith("account.") && !channel.equals("account." + c.accountId)) {
                error(c, channel, "UNAUTHORIZED", "connect with ?token= of this account");
                return;
            }
            switch (op) {
                case "subscribe" -> {
                    c.channels.add(channel);
                    send(c, channel, snapshot(channel));
                }
                case "unsubscribe" -> c.channels.remove(channel);
                default -> error(c, channel, "BAD_REQUEST", "op must be subscribe or unsubscribe");
            }
        } catch (RuntimeException e) {
            error(c, channel, "BAD_REQUEST", "message must be {\"op\",\"channel\"}");
        }
    }

    // ---- tick ----

    private void tickSafely() {
        try {
            tick();
        } catch (RuntimeException e) {
            log.warn("market-data tick failed", e);
        }
    }

    void tick() {
        Set<String> dirtyBooks = new LinkedHashSet<>();
        Map<String, List<Dto.TradeDto>> trades = new LinkedHashMap<>();
        Map<String, Set<String>> accountReasons = new LinkedHashMap<>();
        boolean clockChanged = false;
        Event e;
        while ((e = inbox.poll()) != null) {
            switch (e) {
                case Event.TradeExecuted t -> {
                    dirtyBooks.add(t.instrument());
                    trades.computeIfAbsent(t.instrument(), k -> new ArrayList<>()).add(Dto.TradeDto.of(t));
                    reason(accountReasons, t.buyer(), "TRADE");
                    reason(accountReasons, t.seller(), "TRADE");
                }
                case Event.OrderAccepted o -> {
                    dirtyBooks.add(o.instrument());
                    reason(accountReasons, o.account(), "ORDER");
                }
                case Event.OrderCancelled o -> {
                    market.instruments().forEach(i -> dirtyBooks.add(i.id()));
                    reason(accountReasons, o.account(), "ORDER");
                }
                case Event.OrderExpired o -> reason(accountReasons, o.account(), "ORDER");
                case Event.FundsDeposited d -> reason(accountReasons, d.account(), "DEPOSIT");
                case Event.ClockChanged c -> clockChanged = true;
                case Event.AccountOpened a -> { }
                case Event.ConditionalPlaced c -> reason(accountReasons, c.account(), "CONDITIONAL");
                case Event.ConditionalCancelled c -> reason(accountReasons, c.account(), "CONDITIONAL");
                case Event.ConditionalArmed c -> reason(accountReasons, c.account(), "CONDITIONAL");
                case Event.ConditionalTriggered c -> reason(accountReasons, c.account(), "CONDITIONAL");
                case Event.MarginPositionOpened m -> reason(accountReasons, m.account(), "MARGIN");
                case Event.MarginCloseRequested m -> reason(accountReasons, m.account(), "MARGIN");
                case Event.MarginStopOut m -> reason(accountReasons, m.account(), "MARGIN");
                case Event.MarginPositionClosed m -> reason(accountReasons, m.account(), "MARGIN");
                case Event.SavingsOpened d -> reason(accountReasons, d.account(), "SAVINGS");
                case Event.InterestAccrued d -> reason(accountReasons, d.account(), "SAVINGS");
                case Event.SavingsClosed d -> reason(accountReasons, d.account(), "SAVINGS");
                case Event.PayoutPaid p -> reason(accountReasons, p.holder(), "PAYOUT");
                case Event.PaperPositionOpened p -> reason(accountReasons, p.account(), "PAPER");
                case Event.PaperPositionClosed p -> reason(accountReasons, p.account(), "PAPER");
                case Event.TradingStatusChanged t -> dirtyBooks.add(t.instrument());
                case Event.Disclosure d -> { }
                case Event.PayoutStarted p -> { }
                case Event.BondDefaulted b -> { }
                case Event.OrderAnnotated a -> reason(accountReasons, a.account(), "ORDER");
                case Event.DividendPaid d -> reason(accountReasons, d.holder(), "PAYOUT");
                case Event.ReferencePriceAdjusted r -> dirtyBooks.add(r.instrument());
                case Event.DividendExDate d -> { }
                case Event.DividendEntitled d -> { }
                case Event.DividendPaymentStarted d -> { }
                case Event.FundFeeCharged f -> { }
            }
        }
        if (clients.isEmpty()) {
            return;
        }
        long nowMs = System.currentTimeMillis();
        dirtyBooks.forEach(books::dirty);
        for (String instrument : books.due(nowMs)) {
            String channel = "market." + instrument + ".book";
            if (anyone(channel)) {
                Dto.BookDto snapshot = Dto.BookDto.of(market.book(instrument, 20));
                if (books.shouldSend(instrument, List.of(snapshot.bids(), snapshot.asks(), String.valueOf(snapshot.lastPrice())), nowMs)) {
                    broadcast(channel, snapshot);
                }
            }
        }
        trades.forEach((instrument, list) -> broadcast("market." + instrument + ".trades", list));
        accountReasons.forEach((account, reasons) -> broadcast("account." + account, Map.of("reasons", List.copyOf(reasons))));
        long now = System.currentTimeMillis();
        if (clockChanged || now - lastClockPush >= 1_000) {
            lastClockPush = now;
            broadcast("clock", Dto.ClockDto.of(market.clock()));
        }
    }

    private Object snapshot(String channel) {
        if (channel.equals("clock")) {
            return Dto.ClockDto.of(market.clock());
        }
        if (channel.startsWith("account.")) {
            return Map.of("reasons", List.of());
        }
        String instrument = channel.substring("market.".length(), channel.lastIndexOf('.'));
        if (channel.endsWith(".book")) {
            return Dto.BookDto.of(market.book(instrument, 20));
        }
        List<Dto.TradeDto> recent = new ArrayList<>(market.trades(instrument, 50).stream().map(Dto.TradeDto::of).toList());
        java.util.Collections.reverse(recent);
        return recent;
    }

    private boolean isKnown(String channel) {
        if (channel.equals("clock") || channel.startsWith("account.")) {
            return true;
        }
        for (var i : market.instruments()) {
            if (channel.equals("market." + i.id() + ".book") || channel.equals("market." + i.id() + ".trades")) {
                return true;
            }
        }
        return false;
    }

    private boolean anyone(String channel) {
        return clients.values().stream().anyMatch(c -> c.channels.contains(channel));
    }

    private void broadcast(String channel, Object data) {
        for (Client c : clients.values()) {
            if (c.channels.contains(channel)) {
                send(c, channel, data);
            }
        }
    }

    private void error(Client c, String channel, String code, String message) {
        write(c, Map.of("channel", channel, "error", new Dto.Problem(code, message)));
    }

    private void send(Client c, String channel, Object data) {
        write(c, Map.of("channel", channel, "data", data));
    }

    private void write(Client c, Object payload) {
        try {
            c.session.sendMessage(new TextMessage(json.writeValueAsString(payload)));
        } catch (IOException | IllegalStateException e) {
            log.debug("dropping client {}: {}", c.session.getId(), e.toString());
            clients.remove(c.session.getId());
        }
    }

    private static void reason(Map<String, Set<String>> map, String account, String reason) {
        // A leveraged position trades from a sub-account; its owner is the one to nudge (with MARGIN as well).
        if (engine.Accounts.isSubAccount(account)) {
            map.computeIfAbsent(engine.Accounts.owner(account), k -> new LinkedHashSet<>()).add("MARGIN");
            account = engine.Accounts.owner(account);
        }
        map.computeIfAbsent(account, k -> new LinkedHashSet<>()).add(reason);
    }

    private static final class Client {
        final WebSocketSession session;
        final String accountId;
        final Set<String> channels = ConcurrentHashMap.newKeySet();

        Client(WebSocketSession session, String accountId) {
            this.session = session;
            this.accountId = accountId;
        }
    }
}
