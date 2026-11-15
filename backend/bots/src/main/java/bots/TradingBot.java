package bots;

import application.CommandRejected;
import application.TradingService;
import engine.Balance;
import engine.OrderView;
import java.util.List;
import java.util.Random;

/**
 * One bot: its own account, its own seeded randomness, one strategy. It reaches the market only through the
 * {@link TradingService} port, like a person through REST, and pays the same fees (intent 02, invariant 3).
 *
 * <p>Pattern: Template Method — {@link #step} fixes the lifecycle (observe → decide → act); the {@link Strategy}
 * fills in the decision. See docs/adr/0007-bots-are-api-clients.md.
 */
public final class TradingBot {

    private final String name;
    private final String accountId;
    private final String instrument;
    private final Strategy strategy;
    private final Random random;
    private final TradingService market;
    private long rejected;
    private final java.util.ArrayDeque<Long> recent = new java.util.ArrayDeque<>();
    private long steps;
    private WorldFeed world;

    /** Price history kept for momentum and mean-reversion: the last trade price seen at each step. */
    static final int WINDOW = 20;

    public TradingBot(String name, String accountId, String instrument, Strategy strategy, long seed, TradingService market) {
        this.name = name;
        this.accountId = accountId;
        this.instrument = instrument;
        this.strategy = strategy;
        this.random = new Random(seed);
        this.market = market;
    }

    /** Gives the bot the published fundamentals (for the fundamentalist). */
    public TradingBot withWorld(WorldFeed world) {
        this.world = world;
        return this;
    }

    public final void step(long fairValue) {
        MarketView view = observe(fairValue);
        for (Intent intent : strategy.decide(view, random)) {
            act(intent);
        }
    }

    public String name() {
        return name;
    }

    public String accountId() {
        return accountId;
    }

    /** Commands the exchange refused (e.g. not enough money); a bot just carries on, like a person would. */
    public long rejected() {
        return rejected;
    }

    private MarketView observe(long fairValue) {
        TradingService.BookSnapshot book = market.book(instrument, 1);
        List<OrderView> mine = market.orders(accountId, true, 200);
        var i = market.instruments().stream().filter(x -> x.id().equals(instrument)).findFirst().orElseThrow();
        List<Balance> balances = market.balances(accountId);
        Balance base = find(balances, i.base());
        Balance quote = find(balances, i.quote());
        if (book.lastPrice() != null) {
            recent.addLast(book.lastPrice());
            while (recent.size() > WINDOW) {
                recent.removeFirst();
            }
        }
        return new MarketView(instrument,
                book.bids().isEmpty() ? null : book.bids().getFirst().price(),
                book.asks().isEmpty() ? null : book.asks().getFirst().price(),
                book.lastPrice(), fairValue, mine, base.available(), quote.available(), base.total(),
                List.copyOf(recent), world == null ? null : world.annualEps(instrument), steps++);
    }

    private void act(Intent intent) {
        try {
            switch (intent) {
                case Intent.CancelAllMine c -> {
                    for (OrderView o : market.orders(accountId, true, 200)) {
                        market.cancel(accountId, o.orderId());
                    }
                }
                case Intent.Place p -> market.place(accountId, instrument, p.side(), p.type(), p.price(), p.qty(), null);
            }
        } catch (CommandRejected e) {
            rejected++;
        }
    }

    private static Balance find(List<Balance> balances, String asset) {
        return balances.stream().filter(b -> b.asset().equals(asset)).findFirst().orElse(new Balance(asset, 0, 0));
    }
}
