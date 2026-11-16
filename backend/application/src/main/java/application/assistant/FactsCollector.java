package application.assistant;

import application.SessionReviewProjection;
import application.StatementProjection;
import application.TradingService;
import application.economy.EconomyViews;
import engine.Balance;
import engine.Event;
import java.util.Comparator;
import java.util.Map;

/**
 * Collects a person's facts for the assistant from the read models: statement totals, balances, open margin
 * positions, the trade-journal review, the last rate decision and company reports against their consensus, plus the
 * game's SessionFacts when the game sends them (as data: integers only, nothing from them reaches a prompt as text).
 */
public final class FactsCollector {

    private final TradingService market;

    public FactsCollector(TradingService market) {
        this.market = market;
    }

    public Facts collect(String accountId, Map<String, Long> game) {
        long now = market.clock().now() + 1;
        Facts.Builder b = Facts.builder();
        StatementProjection.Totals t = market.statement(accountId, 0, now).totals();
        b.add("statement.fees", t.fees(), Facts.Kind.MONEY)
                .add("statement.spreadPaid", t.spreadPaid(), Facts.Kind.MONEY)
                .add("statement.realisedPnl", t.realisedPnl(), Facts.Kind.MONEY)
                .add("statement.payouts", t.payouts(), Facts.Kind.MONEY)
                .add("statement.interest", t.interest(), Facts.Kind.MONEY)
                .add("statement.tax", t.tax(), Facts.Kind.MONEY);
        for (Balance bal : market.balances(accountId)) {
            b.add("balance." + bal.asset(), bal.total(), Facts.Kind.COUNT);
        }
        b.add("positions.marginOpen", market.positions(accountId, 200).stream().filter(p -> p.status() == engine.MarginView.Status.OPEN).count(),
                Facts.Kind.COUNT);
        SessionReviewProjection.Review r = market.sessionReview(accountId, 0, now);
        b.add("review.orders", r.orders(), Facts.Kind.COUNT)
                .add("review.wins", r.wins(), Facts.Kind.COUNT)
                .add("review.result", r.result(), Facts.Kind.MONEY)
                .addIfPresent("review.expectancyRx100", r.expectancyRx100(), Facts.Kind.RX100);
        r.byMood().stream().filter(g -> !"NONE".equals(g.key()) && g.result() < 0)
                .min(Comparator.comparingLong(SessionReviewProjection.Group::result))
                .ifPresent(g -> b.code("review.worstMood", g.key()));
        EconomyViews.Macro macro = market.macro();
        if (!macro.decisions().isEmpty()) {
            Event.RateDecided d = macro.decisions().getLast();
            b.add("rate.last.actualBps", d.rateBps(), Facts.Kind.BPS)
                    .add("rate.last.consensusBps", d.consensusBps(), Facts.Kind.BPS)
                    .add("rate.last.previousBps", d.previousBps(), Facts.Kind.BPS);
        }
        for (EconomyViews.Company c : market.companies()) {
            b.addIfPresent("report." + c.instrument() + ".surpriseBps", c.surpriseBps(), Facts.Kind.BPS);
        }
        if (game != null) {
            game.forEach((k, v) -> {
                if (v != null && k.matches("[a-zA-Z]{1,40}")) {
                    b.add("game." + k, v, k.endsWith("Bps") ? Facts.Kind.BPS : k.endsWith("Rx100") ? Facts.Kind.RX100
                            : k.equals("voyages") || k.equals("wins") || k.equals("gapsThroughStop") ? Facts.Kind.COUNT : Facts.Kind.MONEY);
                }
            });
        }
        return b.build();
    }
}
