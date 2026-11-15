package application.economy;

import application.MarketListener;
import engine.Event;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * What the world has published so far: reports and consensus per company, dividends, insider trades, the central
 * bank's decisions and calendar, the market regime, bond coupons, defaults and redemptions. Built only from journalled
 * events (on start from the whole journal), queried on the sequencer thread.
 *
 * <p>Pattern: Event Sourcing projection / CQRS read model. See docs/adr/0021-scheduled-economy.md.
 */
public final class EconomyProjection implements MarketListener {

    static final int INSIDERS_KEPT = 30;

    public record Dividend(Event.DividendAnnounced announced, boolean paid) {}

    public record BondState(int couponsPaid, boolean defaulted, boolean redeemed, long redeemedPerUnit) {}

    private final Map<String, List<Event.EarningsReported>> reports = new HashMap<>();
    private final Map<String, Event.ConsensusPublished> consensus = new HashMap<>();
    private final Map<String, List<Dividend>> dividends = new HashMap<>();
    private final Map<String, Deque<Event.InsiderTradeDisclosed>> insiders = new HashMap<>();
    private final Map<Integer, Event.RateDecisionScheduled> scheduled = new LinkedHashMap<>();
    private final List<Event.RateDecided> decided = new ArrayList<>();
    private final Map<String, BondState> bonds = new HashMap<>();
    private final Map<String, Boolean> open = new HashMap<>();
    private Event.MarketRegimeChanged regime;
    private Long epoch;
    private long lastEconomyTs = Long.MIN_VALUE;

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            switch (e) {
                case Event.ConsensusPublished c -> consensus.put(c.instrument(), c);
                case Event.EarningsReported r -> reports.computeIfAbsent(r.instrument(), k -> new ArrayList<>()).add(r);
                case Event.DividendAnnounced d -> dividends.computeIfAbsent(d.instrument(), k -> new ArrayList<>()).add(new Dividend(d, false));
                case Event.InsiderTradeDisclosed i -> {
                    Deque<Event.InsiderTradeDisclosed> q = insiders.computeIfAbsent(i.instrument(), k -> new ArrayDeque<>());
                    q.addFirst(i);
                    while (q.size() > INSIDERS_KEPT) {
                        q.removeLast();
                    }
                }
                case Event.RateDecisionScheduled s -> scheduled.put(s.number(), s);
                case Event.RateDecided d -> decided.add(d);
                case Event.MarketRegimeChanged m -> {
                    if (epoch == null) {
                        epoch = m.ts();
                    }
                    regime = m;
                }
                case Event.PayoutStarted p -> onPayout(p);
                case Event.BondDefaulted b -> bonds.merge(b.instrument(), new BondState(0, true, false, 0),
                        (a, x) -> new BondState(a.couponsPaid(), true, a.redeemed(), a.redeemedPerUnit()));
                case Event.TradingStatusChanged t -> open.put(t.instrument(), t.open());
                default -> { }
            }
            if (isEconomy(e)) {
                lastEconomyTs = Math.max(lastEconomyTs, e.ts());
            }
        }
    }

    private void onPayout(Event.PayoutStarted p) {
        switch (p.kind()) {
            case DIVIDEND -> {
                List<Dividend> list = dividends.getOrDefault(p.instrument(), List.of());
                for (int i = 0; i < list.size(); i++) {
                    if (!list.get(i).paid() && list.get(i).announced().perShare() == p.perUnit()) {
                        list.set(i, new Dividend(list.get(i).announced(), true));
                        break;
                    }
                }
            }
            case COUPON -> bonds.merge(p.instrument(), new BondState(1, false, false, 0),
                    (a, x) -> new BondState(a.couponsPaid() + 1, a.defaulted(), a.redeemed(), a.redeemedPerUnit()));
            case REDEMPTION -> bonds.merge(p.instrument(), new BondState(0, false, true, p.perUnit()),
                    (a, x) -> new BondState(a.couponsPaid(), a.defaulted(), true, p.perUnit()));
        }
    }

    /** Events the economy schedule produced (not people): the restart cursor is the latest of them. */
    static boolean isEconomy(Event e) {
        return switch (e) {
            case Event.PaperPositionOpened p -> false;
            case Event.PaperPositionClosed p -> false;
            case Event.Disclosure d -> true;
            case Event.TradingStatusChanged t -> true;
            case Event.PayoutStarted p -> true;
            case Event.BondDefaulted b -> true;
            default -> false;
        };
    }

    public Optional<Long> epoch() {
        return Optional.ofNullable(epoch);
    }

    public long lastEconomyTs() {
        return lastEconomyTs;
    }

    public List<Event.EarningsReported> reports(String instrument) {
        return List.copyOf(reports.getOrDefault(instrument, List.of()));
    }

    public Optional<Event.EarningsReported> lastReport(String instrument) {
        List<Event.EarningsReported> list = reports.getOrDefault(instrument, List.of());
        return list.isEmpty() ? Optional.empty() : Optional.of(list.getLast());
    }

    /** The consensus for the next report, if published and not yet reported. */
    public Optional<Event.ConsensusPublished> pendingConsensus(String instrument) {
        Event.ConsensusPublished c = consensus.get(instrument);
        if (c == null) {
            return Optional.empty();
        }
        return lastReport(instrument).filter(r -> r.season() >= c.season()).isPresent() ? Optional.empty() : Optional.of(c);
    }

    public List<Dividend> dividends(String instrument) {
        return List.copyOf(dividends.getOrDefault(instrument, List.of()));
    }

    public List<Event.InsiderTradeDisclosed> insiderTrades(String instrument) {
        return List.copyOf(insiders.getOrDefault(instrument, new ArrayDeque<>()));
    }

    public long policyRateBps() {
        return decided.isEmpty() ? EconomySchedule.START_RATE_BPS : decided.getLast().rateBps();
    }

    public long inflationBps() {
        if (!decided.isEmpty()) {
            return decided.getLast().inflationBps();
        }
        return scheduled.isEmpty() ? EconomySchedule.START_INFLATION_BPS : scheduled.values().iterator().next().inflationBps();
    }

    public List<Event.RateDecided> decisions() {
        return List.copyOf(decided);
    }

    /** The published but not yet decided rate decision, if any. */
    public Optional<Event.RateDecisionScheduled> nextDecision() {
        int done = decided.isEmpty() ? 0 : decided.getLast().number();
        return Optional.ofNullable(scheduled.get(done + 1));
    }

    public List<Event.RateDecisionScheduled> scheduledDecisions() {
        return List.copyOf(scheduled.values());
    }

    public Event.MarketRegimeChanged regime() {
        return regime == null ? new Event.MarketRegimeChanged(0, "CALM", 100) : regime;
    }

    public BondState bond(String instrument) {
        return bonds.getOrDefault(instrument, new BondState(0, false, false, 0));
    }

    public boolean isOpen(String instrument) {
        return open.getOrDefault(instrument, true);
    }
}
