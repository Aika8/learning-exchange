package app.web;

import application.StatementProjection;
import application.TradingService;
import engine.ConditionalView;
import engine.MarginView;
import engine.SavingsView;
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
    static final Map<String, Integer> SCALE = Map.of("SPARK", 2, "SILK", 0, "AMBER", 0, "FORGE", 0, "HBND", 0, "GBND", 0);

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

    public record InstrumentDto(String id, String base, String quote, long feeBps, int priceScale, int qtyScale,
                                int maxLeverage, String kind, boolean tradingOpen) {
        static InstrumentDto of(Instrument i, boolean open) {
            return new InstrumentDto(i.id(), i.base(), i.quote(), i.feeBps(), SCALE.getOrDefault(i.quote(), 0),
                    SCALE.getOrDefault(i.base(), 0), i.maxLeverage(), application.economy.Securities.kind(i.id()), open);
        }
    }

    // ---- M2b ----

    public record OpenPaperRequest(String symbol, String side, Long qty) {}

    public record PaperPositionDto(long paperId, String symbol, String side, long qty, long entryPrice, long openedAt,
                                   long quotedAt, String source, boolean open, Long exitPrice, Long closedAt,
                                   long currentPrice, long pnl) {
        static PaperPositionDto of(application.realworld.PaperBook.Position p, long currentPrice) {
            return new PaperPositionDto(p.paperId(), p.symbol(), p.side().name(), p.qty(), p.entryPrice(), p.openedAt(),
                    p.quotedAt(), p.source(), p.open(), p.exitPrice(), p.closedAt(),
                    p.exitPrice() != null ? p.exitPrice() : currentPrice, p.pnl(currentPrice));
        }
    }

    public record RealWorldDto(List<application.realworld.RealMarketData.Quote> quotes,
                               application.realworld.RealMarketData.BaseRate baseRate) {}

    public record GapWarningDto(long reportAt, List<Long> conditionalIds) {}

    public record MobileCompanyCardDto(application.economy.EconomyViews.Company company, app.bff.Catalogue.Name name,
                                       GapWarningDto gapWarning) {}

    public record CatalogueItemDto(String instrument, String kind, app.bff.Catalogue.Name real, app.bff.Catalogue.Name lore) {}

    public record GlossaryTermDto(String id, app.bff.Catalogue.Name real, app.bff.Catalogue.Name definition,
                                  app.bff.Catalogue.Name lore) {}

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

    // ---- M2a ----

    public record PlaceConditionalRequest(String instrument, String kind, String side, Long qty, Long triggerPrice,
                                          Long limitPrice, Long activationPrice, Long offset, Long protectiveSpread) {}

    public record ConditionalDto(long conditionalId, String instrument, String kind, String side, long qty,
                                 long triggerPrice, long limitPrice, long activationPrice, long offset,
                                 long protectiveSpread, String state, Long bestPrice, Long triggeredAt,
                                 Long triggerTradePrice, Long orderId, long filledQty, String rejection, long createdAt) {
        static ConditionalDto of(ConditionalView v) {
            return new ConditionalDto(v.conditionalId(), v.instrument(), v.kind().name(), v.side().name(), v.qty(),
                    v.triggerPrice(), v.limitPrice(), v.activationPrice(), v.offset(), v.protectiveSpread(),
                    v.state().name(), v.bestPrice(), v.triggeredTs(), v.triggerTradePrice(), v.orderId(), v.filledQty(),
                    v.rejection(), v.createdTs());
        }
    }

    public record OpenMarginRequest(String instrument, String side, Long qty, Integer leverage) {}

    public record MarginPositionDto(long positionId, String instrument, String side, long qty, int leverage,
                                    long collateral, long loanQuote, long loanBase, long entryPrice, Long lastPrice,
                                    long equity, long stopOutEquity, Long stopOutPrice, String status,
                                    String closeReason, Long returned, Long realisedPnl, Long badDebt, long openedAt,
                                    Long closedAt) {
        static MarginPositionDto of(MarginView v) {
            return new MarginPositionDto(v.positionId(), v.instrument(), v.side().name(), v.qty(), v.leverage(),
                    v.collateral(), v.loanQuote(), v.loanBase(), v.entryPrice(), v.lastPrice(), v.equity(),
                    v.stopOutEquity(), v.stopOutPrice(), v.status().name(), v.closeReason(), v.returned(),
                    v.returned() == null ? null : v.returned() - v.collateral(), v.badDebt(), v.openedTs(), v.closedTs());
        }
    }

    public record SavingsProductDto(String asset, long rateBps, long dayMillis) {}

    public record OpenSavingsRequest(Long amount) {}

    public record SavingsDepositDto(long depositId, String asset, long principal, long balance, long interest,
                                    long rateBps, String status, long openedAt, Long closedAt) {
        static SavingsDepositDto of(SavingsView v) {
            return new SavingsDepositDto(v.depositId(), v.asset(), v.principal(), v.balance(), v.interest(), v.rateBps(),
                    v.open() ? "OPEN" : "CLOSED", v.openedTs(), v.closedTs());
        }
    }

    public record SavingsOverviewDto(SavingsProductDto product, List<SavingsDepositDto> deposits) {}

    public record StatementLineDto(long ts, String kind, String instrument, String side, Long price, Long qty, Long mid,
                                   String asset, long amount, long fee, long spreadPaid, long realisedPnl,
                                   boolean margin, Long refId) {
        static StatementLineDto of(StatementProjection.Line l) {
            return new StatementLineDto(l.ts(), l.kind().name(), l.instrument(), l.side() == null ? null : l.side().name(),
                    l.price(), l.qty(), l.mid(), l.asset(), l.amount(), l.fee(), l.spreadPaid(), l.realisedPnl(),
                    l.margin(), l.refId());
        }
    }

    public record StatementTotalsDto(long fees, long spreadPaid, long realisedPnl, long taxRateBps, long tax, long interest,
                                     long payouts) {}

    public record StatementDto(long from, long to, String currency, List<StatementLineDto> lines, StatementTotalsDto totals) {
        static StatementDto of(StatementProjection.Statement s) {
            StatementProjection.Totals t = s.totals();
            return new StatementDto(s.from(), s.to(), s.currency(), s.lines().stream().map(StatementLineDto::of).toList(),
                    new StatementTotalsDto(t.fees(), t.spreadPaid(), t.realisedPnl(), t.taxRateBps(), t.tax(), t.interest(), t.payouts()));
        }
    }
}
