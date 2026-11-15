package app.bff;

import app.web.DevAuth;
import app.web.Dto;
import application.TradingService;
import application.economy.EconomyViews;
import engine.ConditionalView;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * The two Backends-for-Frontends (ADR-0004) over one core. Each speaks its client's language (ADR-0012): the mobile
 * BFF serves real finance names only — the app knows nothing about the game — and the game BFF adds the lore names.
 * The mobile company card is screen-shaped: company data plus a gap-risk warning built from the person's own stops.
 *
 * <p>Pattern: Backend-for-Frontend + Anti-corruption layer (one way: core codes → each client's words).
 */
@RestController
@RequestMapping("/api/v1/bff")
public class BffController {

    /** "Tonight": the report comes out within this much simulation time (one bank day). */
    static final long TONIGHT = 60_000;

    private final TradingService market;
    private final DevAuth auth;
    private final Catalogue catalogue;

    public BffController(TradingService market, DevAuth auth, Catalogue catalogue) {
        this.market = market;
        this.auth = auth;
        this.catalogue = catalogue;
    }

    @GetMapping("/mobile/catalogue")
    public List<Dto.CatalogueItemDto> mobileCatalogue() {
        return catalogue.items().stream().map(i -> new Dto.CatalogueItemDto(i.instrument(), i.kind(), i.real(), null)).toList();
    }

    @GetMapping("/game/catalogue")
    public List<Dto.CatalogueItemDto> gameCatalogue() {
        return catalogue.items().stream().map(i -> new Dto.CatalogueItemDto(i.instrument(), i.kind(), i.real(), i.lore())).toList();
    }

    @GetMapping("/mobile/glossary")
    public List<Dto.GlossaryTermDto> mobileGlossary() {
        return catalogue.terms().stream().map(t -> new Dto.GlossaryTermDto(t.id(), t.real(), t.definition(), null)).toList();
    }

    @GetMapping("/game/glossary")
    public List<Dto.GlossaryTermDto> gameGlossary() {
        return catalogue.terms().stream().map(t -> new Dto.GlossaryTermDto(t.id(), t.real(), t.definition(), t.lore())).toList();
    }

    @GetMapping("/mobile/companies/{id}")
    public Dto.MobileCompanyCardDto companyCard(@RequestHeader(value = "Authorization", required = false) String authz,
                                                @PathVariable String id) {
        String account = auth.accountId(authz);
        EconomyViews.Company c = market.companies().stream().filter(x -> x.instrument().equals(id)).findFirst()
                .orElseThrow(() -> new application.CommandRejected(engine.Rejection.UNKNOWN_INSTRUMENT));
        Catalogue.Name name = catalogue.item(id).map(Catalogue.Item::real).orElse(new Catalogue.Name(id, id));
        return new Dto.MobileCompanyCardDto(c, name, gapWarning(c, market.conditionals(account, 200), market.clock().now()));
    }

    /**
     * Warn when a report comes out "tonight" (within a bank day, or the stock is already halted for it) and the person
     * has live stops on it: the open may gap through them, and a stop-limit may end up outside the market.
     */
    static Dto.GapWarningDto gapWarning(EconomyViews.Company c, List<ConditionalView> mine, long now) {
        if (c.nextReportAt() == null || c.nextReportAt() - now > TONIGHT) {
            return null;
        }
        List<Long> stops = mine.stream()
                .filter(k -> k.instrument().equals(c.instrument()))
                .filter(k -> k.state() == ConditionalView.State.WAITING || k.state() == ConditionalView.State.ARMED)
                .map(ConditionalView::conditionalId).toList();
        return stops.isEmpty() ? null : new Dto.GapWarningDto(c.nextReportAt(), stops);
    }
}
