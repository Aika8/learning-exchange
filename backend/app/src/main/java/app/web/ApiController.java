package app.web;

import app.web.Dto.AccountDetails;
import app.web.Dto.AccountRef;
import app.web.Dto.BalanceDto;
import app.web.Dto.BookDto;
import app.web.Dto.ClockDto;
import app.web.Dto.InstrumentDto;
import app.web.Dto.LoginResponse;
import app.web.Dto.OrderDto;
import app.web.Dto.TradeDto;
import application.TradingService;
import engine.Conditional;
import engine.Order;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST adapter for {@code api/openapi.yaml}: parses, authenticates, calls the {@link TradingService} port, maps to DTOs.
 * No business rule lives here. Pattern: Adapter (driving side). See docs/adr/0002-hexagonal-architecture.md.
 */
@RestController
@RequestMapping("/api/v1")
public class ApiController {

    private final TradingService market;
    private final DevAuth auth;

    public ApiController(TradingService market, DevAuth auth) {
        this.market = market;
        this.auth = auth;
    }

    @PostMapping("/auth/dev-login")
    public LoginResponse login(@RequestBody Dto.LoginRequest body) {
        TradingService.Account a = market.login(body == null ? null : body.name());
        return new LoginResponse(DevAuth.tokenFor(a.accountId()), new AccountRef(a.accountId(), a.name()));
    }

    @GetMapping("/me")
    public AccountDetails me(@RequestHeader(value = "Authorization", required = false) String authz) {
        return details(auth.accountId(authz));
    }

    @PostMapping("/me/deposits")
    public AccountDetails deposit(@RequestHeader(value = "Authorization", required = false) String authz,
                                  @RequestBody Dto.DepositRequest body) {
        String id = auth.accountId(authz);
        if (body == null || body.asset() == null || body.amount() == null) {
            throw new BadRequest("asset and amount are required");
        }
        market.deposit(id, body.asset(), body.amount());
        return details(id);
    }

    @GetMapping("/instruments")
    public List<InstrumentDto> instruments() {
        return market.instruments().stream().map(i -> InstrumentDto.of(i, market.tradingOpen(i.id()))).toList();
    }

    @GetMapping("/instruments/{id}/book")
    public BookDto book(@PathVariable String id, @RequestParam(defaultValue = "10") int depth) {
        return BookDto.of(market.book(id, Math.clamp(depth, 1, 50)));
    }

    @GetMapping("/instruments/{id}/trades")
    public List<TradeDto> trades(@PathVariable String id, @RequestParam(defaultValue = "50") int limit) {
        return market.trades(id, Math.clamp(limit, 1, 200)).stream().map(TradeDto::of).toList();
    }

    @GetMapping("/orders")
    public List<OrderDto> orders(@RequestHeader(value = "Authorization", required = false) String authz,
                                 @RequestParam(defaultValue = "false") boolean open,
                                 @RequestParam(defaultValue = "50") int limit) {
        return market.orders(auth.accountId(authz), open, Math.clamp(limit, 1, 200)).stream().map(OrderDto::of).toList();
    }

    @PostMapping("/orders")
    @ResponseStatus(HttpStatus.CREATED)
    public OrderDto place(@RequestHeader(value = "Authorization", required = false) String authz,
                          @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
                          @RequestBody Dto.PlaceOrderRequest body) {
        String id = auth.accountId(authz);
        if (body == null || body.instrument() == null || body.side() == null || body.type() == null || body.qty() == null) {
            throw new BadRequest("instrument, side, type and qty are required");
        }
        Order.Side side = parse(Order.Side.class, body.side());
        Order.Type type = parse(Order.Type.class, body.type());
        long price = type == Order.Type.LIMIT ? (body.price() == null ? 0 : body.price()) : 0;
        return OrderDto.of(market.place(id, body.instrument(), side, type, price, body.qty(), key(idempotencyKey)));
    }

    @DeleteMapping("/orders/{orderId}")
    public OrderDto cancel(@RequestHeader(value = "Authorization", required = false) String authz,
                           @PathVariable long orderId) {
        return OrderDto.of(market.cancel(auth.accountId(authz), orderId));
    }

    @GetMapping("/clock")
    public ClockDto clock() {
        return ClockDto.of(market.clock());
    }

    @PutMapping("/clock")
    public ClockDto setClock(@RequestHeader(value = "Authorization", required = false) String authz,
                             @RequestBody Dto.ClockUpdate body) {
        auth.accountId(authz);
        if (body == null || body.paused() == null || body.speed() == null) {
            throw new BadRequest("paused and speed are required");
        }
        return ClockDto.of(market.setClock(body.paused(), body.speed()));
    }

    // ---- M2a: conditional orders, leverage, savings, statement ----

    @GetMapping("/conditional-orders")
    public List<Dto.ConditionalDto> conditionals(@RequestHeader(value = "Authorization", required = false) String authz) {
        return market.conditionals(auth.accountId(authz), 200).stream().map(Dto.ConditionalDto::of).toList();
    }

    @PostMapping("/conditional-orders")
    @ResponseStatus(HttpStatus.CREATED)
    public Dto.ConditionalDto placeConditional(@RequestHeader(value = "Authorization", required = false) String authz,
                                               @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
                                               @RequestBody Dto.PlaceConditionalRequest b) {
        String id = auth.accountId(authz);
        if (b == null || b.instrument() == null || b.kind() == null || b.side() == null || b.qty() == null) {
            throw new BadRequest("instrument, kind, side and qty are required");
        }
        return Dto.ConditionalDto.of(market.placeConditional(id, b.instrument(), parse(Conditional.Kind.class, b.kind()),
                parse(Order.Side.class, b.side()), b.qty(), or0(b.triggerPrice()), or0(b.limitPrice()),
                or0(b.activationPrice()), or0(b.offset()), or0(b.protectiveSpread()), key(idempotencyKey)));
    }

    @DeleteMapping("/conditional-orders/{conditionalId}")
    public Dto.ConditionalDto cancelConditional(@RequestHeader(value = "Authorization", required = false) String authz,
                                                @PathVariable long conditionalId) {
        return Dto.ConditionalDto.of(market.cancelConditional(auth.accountId(authz), conditionalId));
    }

    @GetMapping("/margin/positions")
    public List<Dto.MarginPositionDto> positions(@RequestHeader(value = "Authorization", required = false) String authz) {
        return market.positions(auth.accountId(authz), 200).stream().map(Dto.MarginPositionDto::of).toList();
    }

    @PostMapping("/margin/positions")
    @ResponseStatus(HttpStatus.CREATED)
    public Dto.MarginPositionDto openMargin(@RequestHeader(value = "Authorization", required = false) String authz,
                                            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
                                            @RequestBody Dto.OpenMarginRequest b) {
        String id = auth.accountId(authz);
        if (b == null || b.instrument() == null || b.side() == null || b.qty() == null || b.leverage() == null) {
            throw new BadRequest("instrument, side, qty and leverage are required");
        }
        return Dto.MarginPositionDto.of(market.openMargin(id, b.instrument(), parse(Order.Side.class, b.side()), b.qty(), b.leverage(),
                key(idempotencyKey)));
    }

    @PostMapping("/margin/positions/{positionId}/close")
    public Dto.MarginPositionDto closeMargin(@RequestHeader(value = "Authorization", required = false) String authz,
                                             @PathVariable long positionId) {
        return Dto.MarginPositionDto.of(market.closeMargin(auth.accountId(authz), positionId));
    }

    @GetMapping("/savings")
    public Dto.SavingsOverviewDto savings(@RequestHeader(value = "Authorization", required = false) String authz) {
        String id = auth.accountId(authz);
        TradingService.SavingsProduct p = market.savingsProduct();
        return new Dto.SavingsOverviewDto(new Dto.SavingsProductDto(p.asset(), p.rateBps(), p.dayMillis()),
                market.savings(id).stream().map(Dto.SavingsDepositDto::of).toList());
    }

    @PostMapping("/savings")
    @ResponseStatus(HttpStatus.CREATED)
    public Dto.SavingsDepositDto openSavings(@RequestHeader(value = "Authorization", required = false) String authz,
                                             @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKey,
                                             @RequestBody Dto.OpenSavingsRequest b) {
        String id = auth.accountId(authz);
        if (b == null || b.amount() == null) {
            throw new BadRequest("amount is required");
        }
        return Dto.SavingsDepositDto.of(market.openSavings(id, b.amount(), key(idempotencyKey)));
    }

    @PostMapping("/savings/{depositId}/close")
    public Dto.SavingsDepositDto closeSavings(@RequestHeader(value = "Authorization", required = false) String authz,
                                              @PathVariable long depositId) {
        return Dto.SavingsDepositDto.of(market.closeSavings(auth.accountId(authz), depositId));
    }

    @GetMapping("/statement")
    public Dto.StatementDto statement(@RequestHeader(value = "Authorization", required = false) String authz,
                                      @RequestParam(required = false) Long from, @RequestParam(required = false) Long to) {
        String id = auth.accountId(authz);
        long f = from == null ? 0 : from;
        long t = to == null ? market.clock().now() + 1 : to;
        return Dto.StatementDto.of(market.statement(id, f, t));
    }

    /** Idempotency key: optional, at most 64 characters (same rule on every POST that creates something). */
    static String key(String idempotencyKey) {
        if (idempotencyKey != null && idempotencyKey.length() > 64) {
            throw new BadRequest("Idempotency-Key is longer than 64");
        }
        return idempotencyKey;
    }

    private static long or0(Long v) {
        return v == null ? 0 : v;
    }

    private AccountDetails details(String accountId) {
        TradingService.Account a = market.account(accountId).orElseThrow(DevAuth.Unauthorized::new);
        return new AccountDetails(a.accountId(), a.name(), market.balances(accountId).stream().map(BalanceDto::of).toList());
    }

    private static <E extends Enum<E>> E parse(Class<E> type, String value) {
        try {
            return Enum.valueOf(type, value);
        } catch (IllegalArgumentException e) {
            throw new BadRequest("unknown " + type.getSimpleName() + ": " + value);
        }
    }

    static final class BadRequest extends RuntimeException {
        BadRequest(String message) {
            super(message);
        }
    }
}
