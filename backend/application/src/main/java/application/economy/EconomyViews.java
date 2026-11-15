package application.economy;

import engine.Event;
import java.util.List;

/** Read-only views of the economy for the API (all money in SPARK minor units, rates in bps). */
public final class EconomyViews {

    private EconomyViews() {
    }

    /**
     * One line of the economic calendar. Future lines show only what is public in advance (date, kind, consensus once
     * published); {@code actual} appears once it happened.
     */
    public record CalendarEntry(long at, String kind, String instrument, boolean done, Long consensus, Long actual,
                                Long previous, Long inflationBps) {}

    public record Macro(long policyRateBps, long inflationBps, long realRateBps, long savingsRateBps, String regime,
                        int volatilityPct, Long nextDecisionAt, Long nextConsensusBps, List<Event.RateDecided> decisions) {}

    public record Dividend(long perShare, long exDate, Long recordDate, Long payDate, boolean paid) {}

    /**
     * A company card. Ratios are ×100 (P/E 12.5 → 1250); {@code dividendYieldBps} is a year of dividends over the
     * price; {@code surpriseBps} is (actual − consensus EPS) / |consensus|.
     */
    public record Company(String instrument, String issuer, long sharesOutstanding, Long lastPrice, Long epsTtm,
                          Long peX100, Long debtToProfitX100, Long dividendYieldBps, Event.EarningsReported lastReport,
                          Long surpriseBps, Event.ConsensusPublished consensus, Long nextReportAt, boolean tradingOpen,
                          List<Event.InsiderTradeDisclosed> insiderTrades, List<Dividend> dividends,
                          List<Event.EarningsReported> reports) {}

    /** A bond card: YTM and modified duration (×100, years) are always computed, from the last price or fair price. */
    public record Bond(String instrument, String issuer, long faceValue, long couponBps, int couponsPerYear,
                       long couponPerUnit, long maturityAt, String rating, String status, Long lastPrice, long price,
                       long ytmBps, long durationX100, Long nextCouponAt, int couponsPaid, int couponsLeft,
                       long fairYieldBps, long policyRateBps) {}

    // ---- M2c ----

    public record FundHolding(String instrument, long qty, Long price, long value, long weightBps) {}

    /** A fund card: TER, NAV, holdings and the fund against the same basket held without the fee. */
    public record Fund(String instrument, String kind, long terBps, long unitsOutstanding, List<FundHolding> holdings,
                       long cash, long nav, Long navPerUnit, Long lastPrice, Long premiumBps, long feesPaid,
                       long basketValue, Long fundReturnBps, Long basketReturnBps, long tenYearCostBps) {}
}
