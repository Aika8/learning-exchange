package app.web;

import application.TradingService;
import org.springframework.stereotype.Component;

/**
 * Dev-only authentication: the token is {@code dev-<accountId>}. Anyone who knows a name can act as that user —
 * acceptable for a learning app with practice money, never for real money (intent 02: no real credentials).
 * Tokens survive a restart because accounts are rebuilt from the journal.
 */
@Component
public class DevAuth {

    private static final String PREFIX = "dev-";
    private final TradingService market;

    public DevAuth(TradingService market) {
        this.market = market;
    }

    public static String tokenFor(String accountId) {
        return PREFIX + accountId;
    }

    /** Account id for an {@code Authorization: Bearer} header or a raw token; throws {@link Unauthorized} if unknown. */
    public String accountId(String headerOrToken) {
        if (headerOrToken == null) {
            throw new Unauthorized();
        }
        String token = headerOrToken.startsWith("Bearer ") ? headerOrToken.substring(7).strip() : headerOrToken.strip();
        if (!token.startsWith(PREFIX)) {
            throw new Unauthorized();
        }
        String accountId = token.substring(PREFIX.length());
        if (market.account(accountId).isEmpty()) {
            throw new Unauthorized();
        }
        return accountId;
    }

    public static final class Unauthorized extends RuntimeException {
        Unauthorized() {
            super("missing or unknown dev token");
        }
    }
}
