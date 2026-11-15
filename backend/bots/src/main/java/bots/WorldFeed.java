package bots;

import application.MarketListener;
import application.TradingService;
import application.economy.BondMath;
import application.economy.EconomyViews;
import engine.Event;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Turns public news into the hidden fair values the bots trade around (ADR-0007 {@code WorldEvents}):
 * <ul>
 *   <li>a storm (market regime) multiplies every market's volatility;</li>
 *   <li>a company report moves its stock by the <b>surprise</b> (actual − consensus EPS), not by the profit itself;</li>
 *   <li>a dividend lowers the stock by the dividend at the ex-date;</li>
 *   <li>a rate surprise moves the FX pair: a higher rate than expected strengthens SPARK, so AMBER-SPARK falls;</li>
 *   <li>bonds are anchored to the price their yield implies: policy rate + credit spread, and near zero after default.</li>
 * </ul>
 * It reads only what every client can see (journalled events through the port), so bots keep no privileges.
 *
 * <p>Pattern: Observer — subscribed to the market's events like the WebSocket hub.
 */
public final class WorldFeed implements MarketListener {

    /** A 10% EPS surprise moves the price 5%. */
    static final long SURPRISE_TO_GAP = 50;
    /** A rate surprise of 1 bp moves the FX pair 2 bp the other way. */
    static final long RATE_TO_FX = 2;
    /** Recovery a market expects from a defaulted bond, % of face (bps). */
    static final long DEFAULT_RECOVERY_BPS = 300;

    private final Map<String, FairValue> fairValues;
    private final String fxInstrument;
    private final Map<String, Long> fundamentals = new ConcurrentHashMap<>();
    private final TradingService market;

    /** @param fairValues every market's fair value, by instrument */
    public WorldFeed(Map<String, FairValue> fairValues, String fxInstrument, TradingService market) {
        this.fairValues = Map.copyOf(fairValues);
        this.fxInstrument = fxInstrument;
        this.market = market;
    }

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            switch (e) {
                case Event.MarketRegimeChanged m -> fairValues.values().forEach(f -> f.volatilityPct(m.volatilityPct()));
                case Event.EarningsReported r -> {
                    FairValue f = fairValues.get(r.instrument());
                    if (f != null && r.consensusEps() != 0) {
                        long surpriseBps = (r.eps() - r.consensusEps()) * 10_000 / Math.abs(r.consensusEps());
                        f.jump(Math.clamp(surpriseBps * SURPRISE_TO_GAP / 100, -3_000, 3_000));
                    }
                    fundamentals.put(r.instrument(), Math.max(0, r.guidanceEps()) * 4);
                }
                case Event.DividendExDate d -> {
                    FairValue f = fairValues.get(d.instrument());
                    if (f != null) {
                        f.shift(-d.perShare());
                    }
                }
                case Event.PayoutStarted p when p.kind() == Event.PayoutKind.DIVIDEND -> {
                    FairValue f = fairValues.get(p.instrument());
                    if (f != null) {
                        f.shift(-p.perUnit());
                    }
                }
                case Event.RateDecided d -> {
                    FairValue f = fairValues.get(fxInstrument);
                    if (f != null) {
                        f.jump(-(d.rateBps() - d.consensusBps()) * RATE_TO_FX);
                    }
                }
                default -> { }
            }
        }
    }

    /** Re-anchors each fund to its NAV per unit (M2c): its dealer quotes around what the basket is worth. */
    public void refreshFunds() {
        for (EconomyViews.Fund fund : market.funds()) {
            FairValue f = fairValues.get(fund.instrument());
            if (f != null && fund.navPerUnit() != null && fund.navPerUnit() > 0) {
                f.anchor(fund.navPerUnit());
            }
        }
    }

    /** Re-anchors the bonds to the price their fair yield implies; called by the runner before each tick. */
    public void refreshBonds() {
        for (EconomyViews.Bond b : market.bonds()) {
            FairValue f = fairValues.get(b.instrument());
            if (f == null) {
                continue;
            }
            long target = switch (b.status()) {
                case "DEFAULTED" -> b.faceValue() * DEFAULT_RECOVERY_BPS / 10_000;
                case "REDEEMED" -> b.faceValue();
                default -> BondMath.price(b.faceValue(), b.couponPerUnit(), b.couponsPerYear(), b.couponsLeft(), b.fairYieldBps());
            };
            f.anchor(target);
        }
    }

    /** Yearly EPS from the latest guidance, for the fundamentalist (null before the first report). */
    public Long annualEps(String instrument) {
        return fundamentals.get(instrument);
    }
}
