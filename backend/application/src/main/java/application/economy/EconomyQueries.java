package application.economy;

import engine.Event;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/** Builds the economy views from the projection and the schedule. Pure functions; called on the sequencer thread. */
public final class EconomyQueries {

    /** Kinds shown ahead of time: their dates are public. Storms, insider trades and halts are not. */
    private static final Set<String> PUBLIC_AHEAD = Set.of("RATE_DECISION", "EARNINGS", "COUPON", "MATURITY");
    private static final Set<String> SHOWN = Set.of("RATE_DECISION", "EARNINGS", "CONSENSUS", "DIVIDEND_EX",
            "DIVIDEND_RECORD", "DIVIDEND_PAY", "COUPON", "MATURITY", "STORM");

    private EconomyQueries() {
    }

    public static List<EconomyViews.CalendarEntry> calendar(EconomySchedule schedule, EconomyProjection economy,
                                                            long from, long to, long doneUpTo) {
        List<EconomyViews.CalendarEntry> out = new ArrayList<>();
        for (EconomySchedule.Item item : schedule.between(from - 1, to)) {
            boolean done = item.at() <= doneUpTo;
            String kind = item.kind();
            if (!SHOWN.contains(kind) || (!done && !PUBLIC_AHEAD.contains(kind) && !announcedDividend(item, economy))) {
                continue;
            }
            out.add(entry(item, done, economy));
        }
        return out;
    }

    private static boolean announcedDividend(EconomySchedule.Item item, EconomyProjection economy) {
        return switch (item) {
            case EconomySchedule.Dividend d -> economy.dividends(d.instrument()).stream().anyMatch(x -> x.exDate() == d.at());
            case EconomySchedule.DividendRecord d -> economy.dividends(d.instrument()).stream()
                    .anyMatch(x -> x.recordDate() != null && x.recordDate() == d.at());
            case EconomySchedule.DividendPay d -> economy.dividends(d.instrument()).stream()
                    .anyMatch(x -> x.payDate() != null && x.payDate() == d.at());
            default -> false;
        };
    }

    private static EconomyViews.CalendarEntry entry(EconomySchedule.Item item, boolean done, EconomyProjection economy) {
        return switch (item) {
            case EconomySchedule.Publish p -> switch (p.disclosure()) {
                case Event.RateDecided d -> {
                    var published = economy.scheduledDecisions().stream().filter(s -> s.number() == d.number()).findFirst();
                    yield new EconomyViews.CalendarEntry(p.at(), "RATE_DECISION", null, done,
                            published.map(Event.RateDecisionScheduled::consensusBps).orElse(null),
                            done ? d.rateBps() : null, done ? d.previousBps() : null,
                            published.map(Event.RateDecisionScheduled::inflationBps).orElse(null));
                }
                case Event.EarningsReported r -> {
                    Long consensus = economy.reports(r.instrument()).stream().filter(x -> x.season() == r.season())
                            .findFirst().map(Event.EarningsReported::consensusEps)
                            .or(() -> economy.pendingConsensus(r.instrument()).filter(c -> c.season() == r.season())
                                    .map(Event.ConsensusPublished::eps))
                            .orElse(null);
                    yield new EconomyViews.CalendarEntry(p.at(), "EARNINGS", r.instrument(), done, consensus,
                            done ? r.eps() : null, null, null);
                }
                case Event.ConsensusPublished c -> new EconomyViews.CalendarEntry(p.at(), "CONSENSUS", c.instrument(), done,
                        c.eps(), null, null, null);
                case Event.MarketRegimeChanged m -> new EconomyViews.CalendarEntry(p.at(), "STORM", null, done, null,
                        (long) m.volatilityPct(), null, null);
                default -> new EconomyViews.CalendarEntry(p.at(), p.kind(), p.instrument(), done, null, null, null, null);
            };
            case EconomySchedule.Dividend d -> new EconomyViews.CalendarEntry(d.at(), "DIVIDEND_EX", d.instrument(), done,
                    null, d.perShare(), null, null);
            case EconomySchedule.DividendRecord d -> new EconomyViews.CalendarEntry(d.at(), "DIVIDEND_RECORD", d.instrument(),
                    done, null, d.perShare(), null, null);
            case EconomySchedule.DividendPay d -> new EconomyViews.CalendarEntry(d.at(), "DIVIDEND_PAY", d.instrument(), done,
                    null, d.perShare(), null, null);
            case EconomySchedule.Coupon c -> new EconomyViews.CalendarEntry(c.at(), "COUPON", c.instrument(), done, null,
                    c.bond().couponPerUnit(), null, null);
            case EconomySchedule.Maturity m -> new EconomyViews.CalendarEntry(m.at(), "MATURITY", m.instrument(), done, null,
                    m.bond().faceValue(), null, null);
            default -> new EconomyViews.CalendarEntry(item.at(), item.kind(), item.instrument(), done, null, null, null, null);
        };
    }

    public static EconomyViews.Macro macro(EconomyProjection economy, long depositMarginBps, EconomySchedule schedule, long now) {
        long rate = economy.policyRateBps();
        long inflation = economy.inflationBps();
        var next = economy.nextDecision();
        var regime = economy.regime();
        return new EconomyViews.Macro(rate, inflation, rate - inflation, Math.max(0, rate - depositMarginBps),
                regime.regime(), regime.volatilityPct(), next.map(Event.RateDecisionScheduled::decisionAt).orElseGet(() ->
                        schedule.between(now, now + 60L * schedule.dayMillis()).stream()
                                .filter(i -> i.kind().equals("RATE_DECISION")).map(EconomySchedule.Item::at).findFirst().orElse(null)),
                next.map(Event.RateDecisionScheduled::consensusBps).orElse(null), economy.decisions());
    }

    public static EconomyViews.Company company(Securities.Company c, EconomyProjection economy, EconomySchedule schedule,
                                               Long lastPrice, boolean open, long now) {
        List<Event.EarningsReported> reports = economy.reports(c.instrument());
        List<Event.EarningsReported> last4 = reports.subList(Math.max(0, reports.size() - 4), reports.size());
        Long epsTtm = null;
        Long profitTtm = null;
        long divTtm = 0;
        if (!last4.isEmpty()) {
            long eps = 0;
            long profit = 0;
            for (Event.EarningsReported r : last4) {
                eps += r.eps();
                profit += r.netProfit();
                divTtm += r.dividendPerShare();
            }
            // fewer than four seasons so far: annualise
            epsTtm = eps * 4 / last4.size();
            profitTtm = profit * 4 / last4.size();
            divTtm = divTtm * 4 / last4.size();
        }
        Event.EarningsReported last = reports.isEmpty() ? null : reports.getLast();
        Long pe = lastPrice != null && epsTtm != null && epsTtm > 0 ? lastPrice * 100 / epsTtm : null;
        Long debtToProfit = last != null && profitTtm != null && profitTtm > 0 ? last.debt() * 100 / profitTtm : null;
        Long yield = lastPrice != null && lastPrice > 0 && !last4.isEmpty() ? divTtm * 10_000 / lastPrice : null;
        Long surprise = last == null || last.consensusEps() == 0 ? null
                : (last.eps() - last.consensusEps()) * 10_000 / Math.abs(last.consensusEps());
        Long nextReport = schedule.between(now, now + (long) EconomySchedule.SEASON_DAYS * 2 * schedule.dayMillis()).stream()
                .filter(i -> i.kind().equals("EARNINGS") && c.instrument().equals(i.instrument()))
                .map(EconomySchedule.Item::at).findFirst().orElse(null);
        List<EconomyViews.Dividend> dividends = economy.dividends(c.instrument()).stream()
                .map(d -> new EconomyViews.Dividend(d.perShare(), d.exDate(), d.recordDate(), d.payDate(), d.paid())).toList();
        return new EconomyViews.Company(c.instrument(), c.issuer(), c.sharesOutstanding(), lastPrice, epsTtm, pe,
                debtToProfit, yield, last, surprise, economy.pendingConsensus(c.instrument()).orElse(null), nextReport, open,
                economy.insiderTrades(c.instrument()), dividends, reports);
    }

    public static EconomyViews.Bond bond(Securities.Bond b, EconomyProjection economy, EconomySchedule schedule,
                                         Long lastPrice, long now) {
        EconomyProjection.BondState st = economy.bond(b.instrument());
        int left = schedule.couponsLeft(b, now);
        long fairYield = economy.policyRateBps() + b.spreadBps();
        long fair = BondMath.price(b.faceValue(), b.couponPerUnit(), b.couponsPerYear(), left, fairYield);
        long price = lastPrice != null ? lastPrice : fair;
        long ytm = BondMath.yieldToMaturity(price, b.faceValue(), b.couponPerUnit(), b.couponsPerYear(), left);
        long duration = BondMath.modifiedDurationX100(b.faceValue(), b.couponPerUnit(), b.couponsPerYear(), left, ytm);
        String status = st.redeemed() ? "REDEEMED" : st.defaulted() ? "DEFAULTED" : "ACTIVE";
        long next = schedule.nextCouponAt(b, now);
        return new EconomyViews.Bond(b.instrument(), b.issuer(), b.faceValue(), b.couponBps(), b.couponsPerYear(),
                b.couponPerUnit(), schedule.maturityAt(b), b.rating(), status, lastPrice, price, ytm, duration,
                next == 0 || st.defaulted() ? null : next, st.couponsPaid(), st.defaulted() ? 0 : left, fairYield,
                economy.policyRateBps());
    }
}
