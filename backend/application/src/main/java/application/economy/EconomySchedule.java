package application.economy;

import engine.Event;
import engine.Order;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Random;

/**
 * The world's calendar: company reports (consensus first, then the report while the stock is halted "at night"),
 * dividends, insider trades, the central bank's 8 rate decisions a year, bond coupons and maturities, and storms
 * (volatility regimes). A pure function of a seed and a start time: the same seed gives the same economy.
 *
 * <p>Each season (91 bank days) and each block of days is generated from its own seeded {@link Random}, so any time
 * window can be asked for in any order and gives the same items. Values a person must not see in advance (the actual
 * report, the rate decision) live in the items, but read models only show the date and kind of future items.
 *
 * <p>Pattern: Generator / Strategy for {@code CorporateEvents} and {@code MacroEvents} (ADR-0007), driven by the
 * simulation clock; the journal stores what it produced, so replay never runs it again (ADR-0021).
 */
public final class EconomySchedule {

    public static final int SEASON_DAYS = 91;
    public static final int YEAR_DAYS = 365;
    public static final int DECISIONS_PER_YEAR = 8;
    /** Policy rate and inflation before the first decision (bps), like a tight-money emerging market. */
    public static final long START_RATE_BPS = 1_600;
    public static final long START_INFLATION_BPS = 1_100;

    /** Something due at simulation time {@code at}; the service turns it into commands. */
    public sealed interface Item {
        long at();

        /** What the public calendar may show before it happens: kind and instrument, no numbers. */
        String kind();

        String instrument();
    }

    public record Publish(long at, String kind, String instrument, Event.Disclosure disclosure) implements Item {}

    public record TradingStatus(long at, String instrument, boolean open, String reason) implements Item {
        public String kind() {
            return open ? "MARKET_OPEN" : "MARKET_HALT";
        }
    }

    /** The open of the ex-date: entitlement fixed, reference price adjusted (M2c, ADR-0022). */
    public record Dividend(long at, String instrument, String issuer, long perShare, long recordDate, long payDate)
            implements Item {
        public String kind() {
            return "DIVIDEND_EX";
        }
    }

    /** Calendar marker only: the register is read on this day (settlement T+1 after the ex-date). */
    public record DividendRecord(long at, String instrument, long perShare) implements Item {
        public String kind() {
            return "DIVIDEND_RECORD";
        }
    }

    public record DividendPay(long at, String instrument, long perShare) implements Item {
        public String kind() {
            return "DIVIDEND_PAY";
        }
    }

    public record Coupon(long at, Securities.Bond bond, int number) implements Item {
        public String kind() {
            return "COUPON";
        }

        public String instrument() {
            return bond.instrument();
        }
    }

    public record Maturity(long at, Securities.Bond bond) implements Item {
        public String kind() {
            return "MATURITY";
        }

        public String instrument() {
            return bond.instrument();
        }
    }

    /** An insider trade; the price is the last trade price when it is disclosed. */
    public record Insider(long at, String instrument, String insider, String role, Order.Side side, long qty)
            implements Item {
        public String kind() {
            return "INSIDER_TRADE";
        }
    }

    private record Decision(long scheduledAt, long decidedAt, long consensusBps, long inflationBps, long rateBps,
                            long previousBps) {}

    private final long seed;
    private final long epoch;
    private final long day;
    private final List<Decision> decisions = new ArrayList<>();

    /**
     * @param epoch     simulation time the economy started (the journal keeps it as the first regime event)
     * @param dayMillis one bank day in simulation milliseconds (the savings product's day)
     */
    public EconomySchedule(long seed, long epoch, long dayMillis) {
        this.seed = seed;
        this.epoch = epoch;
        this.day = dayMillis;
    }

    public long epoch() {
        return epoch;
    }

    public long dayMillis() {
        return day;
    }

    /** Items with {@code fromExclusive < at <= toInclusive}, in time order. */
    public List<Item> between(long fromExclusive, long toInclusive) {
        List<Item> out = new ArrayList<>();
        if (toInclusive < epoch) {
            return out;
        }
        if (fromExclusive < epoch) {
            out.add(new Publish(epoch, "REGIME", null, new Event.MarketRegimeChanged(epoch, "CALM", 100)));
        }
        long fromDay = Math.max(0, (fromExclusive - epoch) / day - 1);
        long toDay = (toInclusive - epoch) / day + 1;
        for (long s = fromDay / SEASON_DAYS; s <= toDay / SEASON_DAYS + 1; s++) {
            season((int) s, out);
        }
        for (long b = fromDay / 30; b <= toDay / 30; b++) {
            storms(b, out);
        }
        int n = 0;
        while (decisionDay(n) - 10 <= toDay + 1) {
            if (decisionDay(n) + 1 >= fromDay) {
                Decision d = decision(n);
                out.add(new Publish(d.scheduledAt(), "RATE_SCHEDULE", null,
                        new Event.RateDecisionScheduled(d.scheduledAt(), n + 1, d.decidedAt(), d.consensusBps(), d.inflationBps())));
                out.add(new Publish(d.decidedAt(), "RATE_DECISION", null,
                        new Event.RateDecided(d.decidedAt(), n + 1, d.rateBps(), d.previousBps(), d.consensusBps(), d.inflationBps())));
            }
            n++;
        }
        for (Securities.Bond b : Securities.BONDS) {
            for (int p = 1; p <= b.seasons(); p++) {
                out.add(new Coupon(at(p * SEASON_DAYS, 0.5), b, p));
            }
            out.add(new Maturity(at(b.seasons() * SEASON_DAYS, 0.55), b));
        }
        return out.stream().filter(i -> i.at() > fromExclusive && i.at() <= toInclusive)
                .sorted(Comparator.comparingLong(Item::at)).toList();
    }

    /** Coupon dates of a bond that are still ahead of {@code now}. */
    public int couponsLeft(Securities.Bond b, long now) {
        int left = 0;
        for (int p = 1; p <= b.seasons(); p++) {
            if (at(p * SEASON_DAYS, 0.5) > now) {
                left++;
            }
        }
        return left;
    }

    public long nextCouponAt(Securities.Bond b, long now) {
        for (int p = 1; p <= b.seasons(); p++) {
            long t = at(p * SEASON_DAYS, 0.5);
            if (t > now) {
                return t;
            }
        }
        return 0;
    }

    public long maturityAt(Securities.Bond b) {
        return at(b.seasons() * SEASON_DAYS, 0.55);
    }

    // ---- generators ----

    private long at(long dayNo, double fraction) {
        return epoch + dayNo * day + Math.round(fraction * day);
    }

    private Random random(long... key) {
        long h = seed;
        for (long k : key) {
            h = h * 1_000_003L + k;
        }
        return new Random(h);
    }

    /** Company reports of season {@code s} (seasons start at 0; the first report is in season 0). */
    private void season(int s, List<Item> out) {
        for (int c = 0; c < Securities.COMPANIES.size(); c++) {
            Securities.Company co = Securities.COMPANIES.get(c);
            String id = co.instrument();
            long reportDay = (long) s * SEASON_DAYS + co.reportDay();
            Random r = random(1, s, c);
            double trend = Math.pow(1 + co.growthBps() / 10_000.0, s);
            double shock = r.nextGaussian() * 0.08;
            long consensusRevenue = Math.round(co.revenue() * trend * (1 + r.nextGaussian() * 0.01));
            long consensusProfit = consensusRevenue * co.netMarginBps() / 10_000;
            long consensusEps = consensusProfit / co.sharesOutstanding();
            long revenue = Math.round(co.revenue() * trend * (1 + shock));
            long marginBps = Math.max(-2_000, co.netMarginBps() + Math.round(shock * 6_000));
            long profit = revenue * marginBps / 10_000;
            long eps = profit / co.sharesOutstanding();
            long cashFlow = Math.round(profit * (1.1 + r.nextGaussian() * 0.15));
            long debt = Math.round(co.debt() * (1 + r.nextGaussian() * 0.03));
            long dividend = profit > 0 ? eps * co.payoutBps() / 10_000 : 0;
            long guidance = Math.round(consensusEps * (1 + co.growthBps() / 10_000.0) * (1 + shock / 3));

            out.add(new Publish(at(reportDay - 5, 0.3 + c * 0.01), "CONSENSUS", id, new Event.ConsensusPublished(
                    at(reportDay - 5, 0.3 + c * 0.01), id, s + 1, at(reportDay, 0.75), consensusRevenue, consensusProfit, consensusEps)));
            out.add(new TradingStatus(at(reportDay, 0.70 + c * 0.01), id, false, "EARNINGS_NIGHT"));
            out.add(new Publish(at(reportDay, 0.75 + c * 0.01), "EARNINGS", id, new Event.EarningsReported(
                    at(reportDay, 0.75 + c * 0.01), id, s + 1, revenue, profit, eps, debt, cashFlow, dividend, guidance,
                    co.sharesOutstanding(), consensusEps)));
            if (dividend > 0) {
                // M2c: ex-date at the open of day +10, record date the next day (T+1), paid 4 days later.
                long ex = at(reportDay + 10, 0.01 + c * 0.001);
                long record = at(reportDay + 11, 0.02 + c * 0.001);
                long pay = at(reportDay + 15, 0.3 + c * 0.001);
                out.add(new Publish(at(reportDay, 0.76 + c * 0.01), "DIVIDEND", id,
                        new Event.DividendDeclared(at(reportDay, 0.76 + c * 0.01), id, dividend, ex, record, pay)));
                out.add(new Dividend(ex, id, co.issuer(), dividend, record, pay));
                out.add(new DividendRecord(record, id, dividend));
                out.add(new DividendPay(pay, id, dividend));
            }
            out.add(new TradingStatus(at(reportDay + 1, 0.0 + c * 0.001), id, true, "OPEN"));

            // Insiders buy more often before good hidden news; sales are mostly noise (ADR-0007).
            int trades = r.nextInt(3);
            for (int k = 0; k < trades; k++) {
                boolean buy = r.nextDouble() < (shock > 0 ? 0.75 : 0.3);
                String[] roles = {"CEO", "CFO", "DIRECTOR"};
                String role = roles[r.nextInt(roles.length)];
                out.add(new Insider(at(reportDay - 3 - r.nextInt(15), 0.4 + c * 0.01 + k * 0.001), id,
                        role.toLowerCase() + "-" + id.substring(0, id.indexOf('-')).toLowerCase(), role,
                        buy ? Order.Side.BUY : Order.Side.SELL, 100 + r.nextInt(900)));
            }
        }
    }

    /** Storms: in each 30-day block, maybe one storm of 2–5 days with 2–4× volatility. */
    private void storms(long block, List<Item> out) {
        Random r = random(2, block);
        if (r.nextDouble() < 0.4) {
            long start = block * 30 + 3 + r.nextInt(20);
            int len = 2 + r.nextInt(4);
            int vol = 200 + 100 * r.nextInt(3);
            out.add(new Publish(at(start, 0.05), "STORM", null, new Event.MarketRegimeChanged(at(start, 0.05), "STORM", vol)));
            out.add(new Publish(at(start + len, 0.05), "CALM", null, new Event.MarketRegimeChanged(at(start + len, 0.05), "CALM", 100)));
        }
    }

    private long decisionDay(int n) {
        return 20 + (long) n * YEAR_DAYS / DECISIONS_PER_YEAR;
    }

    /** Rate decision {@code n}: inflation wanders; the bank moves toward inflation + 4.5% real; 1 in 4 is a surprise. */
    private Decision decision(int n) {
        while (decisions.size() <= n) {
            int k = decisions.size();
            long prev = k == 0 ? START_RATE_BPS : decisions.get(k - 1).rateBps();
            long prevInfl = k == 0 ? START_INFLATION_BPS : decisions.get(k - 1).inflationBps();
            Random r = random(3, k);
            long inflation = Math.clamp(prevInfl + Math.round(r.nextGaussian() * 60), 300, 2_500);
            long step = Math.clamp(round25((inflation + 450 - prev) / 2), -100, 100);
            long consensus = prev + step;
            long surprise = r.nextDouble() < 0.25 ? (r.nextBoolean() ? 25 : -25) * (1 + r.nextInt(2)) : 0;
            long rate = Math.max(25, consensus + surprise);
            long d = decisionDay(k);
            decisions.add(new Decision(at(d - 10, 0.6), at(d, 0.6), consensus, inflation, rate, prev));
        }
        return decisions.get(n);
    }

    private static long round25(long bps) {
        return Math.round(bps / 25.0) * 25;
    }
}
