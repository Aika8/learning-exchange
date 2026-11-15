package application.economy;

import application.MarketListener;
import engine.Event;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * What the funds have charged so far (M2c): fees paid, the last fee day, and the NAV and basket value on the first fee
 * day — the starting point of the "fund against its own basket" comparison on the fund card.
 *
 * <p>Pattern: Event Sourcing projection. Not thread-safe: sequencer thread only.
 */
public final class FundProjection implements MarketListener {

    public record State(long fundedAt, long lastChargeAt, long feesPaid, Long firstNav, Long firstBasket) {}

    private final Map<String, State> states = new HashMap<>();
    private final Map<String, String> fundOfCustody = new HashMap<>();

    public FundProjection() {
        Funds.FUNDS.forEach(f -> fundOfCustody.put(f.custody(), f.instrument()));
    }

    @Override
    public void onEvents(List<Event> events) {
        for (Event e : events) {
            switch (e) {
                case Event.FundsDeposited d when fundOfCustody.containsKey(d.account()) ->
                        states.putIfAbsent(fundOfCustody.get(d.account()), new State(d.ts(), d.ts(), 0, null, null));
                case Event.FundFeeCharged f -> {
                    State s = states.getOrDefault(f.fund(), new State(f.ts(), f.ts(), 0, null, null));
                    states.put(f.fund(), new State(s.fundedAt(), f.ts(), s.feesPaid() + f.amount(),
                            s.firstNav() == null ? f.nav() : s.firstNav(),
                            s.firstBasket() == null ? f.basketValue() : s.firstBasket()));
                }
                default -> { }
            }
        }
    }

    public java.util.Optional<State> state(String fund) {
        return java.util.Optional.ofNullable(states.get(fund));
    }
}
