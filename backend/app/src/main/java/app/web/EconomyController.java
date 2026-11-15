package app.web;

import application.CandleProjection;
import application.CommandRejected;
import application.TradingService;
import application.economy.EconomyViews;
import engine.Order;
import engine.Rejection;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST adapter for the M2b part of {@code api/openapi.yaml}: candles, economic calendar, rates, companies, bonds,
 * real-world data and paper positions. No business rule lives here. Pattern: Adapter (driving side).
 */
@RestController
@RequestMapping("/api/v1")
public class EconomyController {

    static final long DAY = 60_000;

    private final TradingService market;
    private final DevAuth auth;

    public EconomyController(TradingService market, DevAuth auth) {
        this.market = market;
        this.auth = auth;
    }

    @GetMapping("/instruments/{id}/candles")
    public List<CandleProjection.Candle> candles(@PathVariable String id, @RequestParam(defaultValue = "90") int limit) {
        return market.candles(id, Math.clamp(limit, 1, 365));
    }

    @GetMapping("/instruments/{id}/atr")
    public Dto.AtrDto atr(@PathVariable String id, @RequestParam(defaultValue = "14") int period) {
        int p = Math.clamp(period, 2, 100);
        application.Atr.Result r = market.atr(id, p);
        Long last = market.lastPrice(id).orElse(null);
        Long bps = r.atr() == null || last == null || last == 0 ? null : r.atr() * 10_000 / last;
        return new Dto.AtrDto(id, p, r.ready(), r.candles(), r.atr(), last, bps);
    }

    @GetMapping("/funds")
    public List<EconomyViews.Fund> funds() {
        return market.funds();
    }

    @GetMapping("/funds/{id}")
    public EconomyViews.Fund fund(@PathVariable String id) {
        return market.funds().stream().filter(f -> f.instrument().equals(id)).findFirst()
                .orElseThrow(() -> new application.CommandRejected(engine.Rejection.UNKNOWN_INSTRUMENT));
    }

    @GetMapping("/economy/calendar")
    public List<EconomyViews.CalendarEntry> calendar(@RequestParam(required = false) Long from,
                                                     @RequestParam(required = false) Long to) {
        long now = market.clock().now();
        long f = from == null ? now - 30 * DAY : from;
        long t = to == null ? now + 120 * DAY : to;
        if (t < f || t - f > 3 * 365 * DAY) {
            throw new ApiController.BadRequest("from..to must be ordered and at most 3 years");
        }
        return market.calendar(f, t);
    }

    @GetMapping("/economy/rates")
    public EconomyViews.Macro rates() {
        return market.macro();
    }

    @GetMapping("/companies")
    public List<EconomyViews.Company> companies() {
        return market.companies();
    }

    @GetMapping("/companies/{id}")
    public EconomyViews.Company company(@PathVariable String id) {
        return company(market, id);
    }

    static EconomyViews.Company company(TradingService market, String id) {
        return market.companies().stream().filter(c -> c.instrument().equals(id)).findFirst()
                .orElseThrow(() -> new CommandRejected(Rejection.UNKNOWN_INSTRUMENT));
    }

    @GetMapping("/bonds")
    public List<EconomyViews.Bond> bonds() {
        return market.bonds();
    }

    @GetMapping("/bonds/{id}")
    public EconomyViews.Bond bond(@PathVariable String id) {
        return market.bonds().stream().filter(b -> b.instrument().equals(id)).findFirst()
                .orElseThrow(() -> new CommandRejected(Rejection.UNKNOWN_INSTRUMENT));
    }

    // ---- real world (ADR-0015) ----

    @GetMapping("/real-world")
    public Dto.RealWorldDto realWorld() {
        return new Dto.RealWorldDto(market.realQuotes(), market.realBaseRate().orElse(null));
    }

    @GetMapping("/real-world/history")
    public List<application.realworld.RealMarketData.Point> history(@RequestParam String symbol) {
        return market.realHistory(symbol);
    }

    @GetMapping("/real-world/paper-positions")
    public List<Dto.PaperPositionDto> paper(@RequestHeader(value = "Authorization", required = false) String authz) {
        String id = auth.accountId(authz);
        return market.paperPositions(id).stream().map(p -> Dto.PaperPositionDto.of(p, price(p.symbol()))).toList();
    }

    @PostMapping("/real-world/paper-positions")
    @ResponseStatus(HttpStatus.CREATED)
    public Dto.PaperPositionDto openPaper(@RequestHeader(value = "Authorization", required = false) String authz,
                                          @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
                                          @RequestBody Dto.OpenPaperRequest b) {
        String id = auth.accountId(authz);
        if (b == null || b.symbol() == null || b.side() == null || b.qty() == null) {
            throw new ApiController.BadRequest("symbol, side and qty are required");
        }
        Order.Side side;
        try {
            side = Order.Side.valueOf(b.side());
        } catch (IllegalArgumentException e) {
            throw new ApiController.BadRequest("unknown side: " + b.side());
        }
        var p = market.openPaper(id, b.symbol(), side, b.qty(), ApiController.key(idempotencyKey));
        return Dto.PaperPositionDto.of(p, price(p.symbol()));
    }

    @PostMapping("/real-world/paper-positions/{paperId}/close")
    public Dto.PaperPositionDto closePaper(@RequestHeader(value = "Authorization", required = false) String authz,
                                           @PathVariable long paperId) {
        var p = market.closePaper(auth.accountId(authz), paperId);
        return Dto.PaperPositionDto.of(p, price(p.symbol()));
    }

    private long price(String symbol) {
        return market.realQuotes().stream().filter(q -> q.symbol().equals(symbol)).findFirst()
                .map(application.realworld.RealMarketData.Quote::price).orElse(0L);
    }
}
