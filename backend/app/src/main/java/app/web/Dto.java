package app.web;

import application.TradingService;
import engine.Balance;
import engine.Event;
import engine.Instrument;
import engine.OrderBook;
import engine.OrderView;
import java.util.List;
import java.util.Map;

/**
 * Response and request shapes of {@code api/openapi.yaml}. Hand-written to match the contract; ContractTest checks
 * every response against it. Domain objects never leave the core as they are.
 */
public final class Dto {

    private Dto() {
    }

    /** Decimals shown for each asset; the catalogue (ADR-0012) will own this in M2. */
    static final Map<String, Integer> SCALE = Map.of("SPARK", 2, "SILK", 0);

    public record LoginRequest(String name) {}

    public record AccountRef(String accountId, String name) {}

    public record LoginResponse(String token, AccountRef account) {}

    public record BalanceDto(String asset, long available, long reserved) {
        static BalanceDto of(Balance b) {
            return new BalanceDto(b.asset(), b.available(), b.reserved());
        }
    }

    public record AccountDetails(String accountId, String name, List<BalanceDto> balances) {}

    public record DepositRequest(String asset, Long amount) {}

    public record InstrumentDto(String id, String base, String quote, long feeBps, int priceScale, int qtyScale) {
        static InstrumentDto of(Instrument i) {
            return new InstrumentDto(i.id(), i.base(), i.quote(), i.feeBps(), SCALE.getOrDefault(i.quote(), 0),
                    SCALE.getOrDefault(i.base(), 0));
        }
    }

    public record PlaceOrderRequest(String instrument, String side, String type, Long price, Long qty) {}

    public record OrderDto(long orderId, String instrument, String side, String type, long price, long qty,
                           long filledQty, long remainingQty, String status, long createdAt) {
        static OrderDto of(OrderView o) {
            return new OrderDto(o.orderId(), o.instrument(), o.side().name(), o.type().name(), o.price(), o.qty(),
                    o.filledQty(), o.remainingQty(), o.status().name(), o.createdTs());
        }
    }

    public record LevelDto(long price, long qty, int orders) {
        static LevelDto of(OrderBook.Level l) {
            return new LevelDto(l.price(), l.qty(), l.orders());
        }
    }

    public record BookDto(String instrument, List<LevelDto> bids, List<LevelDto> asks, Long lastPrice, long ts) {
        public static BookDto of(TradingService.BookSnapshot b) {
            return new BookDto(b.instrument(), b.bids().stream().map(LevelDto::of).toList(),
                    b.asks().stream().map(LevelDto::of).toList(), b.lastPrice(), b.ts());
        }
    }

    public record TradeDto(long tradeId, String instrument, long price, long qty, String aggressorSide, long ts) {
        public static TradeDto of(Event.TradeExecuted t) {
            return new TradeDto(t.tradeId(), t.instrument(), t.price(), t.qty(), t.aggressorSide().name(), t.ts());
        }
    }

    public record ClockDto(long now, boolean paused, int speed) {
        public static ClockDto of(TradingService.ClockState c) {
            return new ClockDto(c.now(), c.paused(), c.speed());
        }
    }

    public record ClockUpdate(Boolean paused, Integer speed) {}

    public record Problem(String code, String message) {}
}
