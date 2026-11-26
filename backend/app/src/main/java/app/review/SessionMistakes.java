package app.review;

import application.Journal;
import application.TradingService;
import application.review.TradingMistakes;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Finds the trading mistakes (field guide, table B) of one person in one period for {@code GET /session-review}
 * (LE-058). The rule lives in {@link TradingMistakes}; this only hands it the journal, the instruments and the length
 * of a bank day. The journal does not keep book snapshots, so B4 (wide spread) is never found here (DECISIONS.md).
 *
 * <p>Reads the whole journal on every call: fine for a learning exchange, a projection would be the next step.
 */
@Component
public class SessionMistakes {

    private final Journal journal;
    private final TradingService market;

    public SessionMistakes(Journal journal, TradingService market) {
        this.journal = journal;
        this.market = market;
    }

    public List<TradingMistakes.Mistake> find(String accountId, long from, long to) {
        return TradingMistakes.find(journal.readAll(), market.instruments(), accountId, from, to,
                market.savingsProduct().dayMillis());
    }
}
