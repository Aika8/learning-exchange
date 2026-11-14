package application;

import engine.Balance;
import engine.Event;
import engine.Instrument;
import engine.Order;
import engine.OrderBook;
import engine.OrderView;
import java.util.List;
import java.util.Optional;

/**
 * Port offered by the core to every driver: REST for people, the bot runner for bots. Bots get no other door
 * (intent 02, invariant 3). See docs/adr/0002-hexagonal-architecture.md and 0007-bots-are-api-clients.md.
 */
public interface TradingService {

    /** Dev login: the name is the identity; a new name opens an account with the starting balance. */
    Account login(String name);

    Optional<Account> account(String accountId);

    List<Balance> balances(String accountId);

    /** Dev top-up, journalled as a deposit. */
    void deposit(String accountId, String asset, long amount);

    OrderView place(String accountId, String instrument, Order.Side side, Order.Type type, long price, long qty,
                    String idempotencyKey);

    OrderView cancel(String accountId, long orderId);

    List<OrderView> orders(String accountId, boolean openOnly, int limit);

    List<Instrument> instruments();

    BookSnapshot book(String instrument, int depth);

    List<Event.TradeExecuted> trades(String instrument, int limit);

    ClockState clock();

    ClockState setClock(boolean paused, int speed);

    void subscribe(MarketListener listener);

    record Account(String accountId, String name) {}

    record BookSnapshot(String instrument, List<OrderBook.Level> bids, List<OrderBook.Level> asks, Long lastPrice,
                        long ts) {}

    record ClockState(long now, boolean paused, int speed) {}
}
