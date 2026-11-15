package application;

import engine.Balance;
import engine.Conditional;
import engine.ConditionalView;
import engine.MarginView;
import engine.SavingsView;
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

    // ---- M2a ----

    /** A stop or take-profit kept outside the book (ADR-0008). Unused prices are 0. */
    ConditionalView placeConditional(String accountId, String instrument, Conditional.Kind kind, Order.Side side,
                                     long qty, long triggerPrice, long limitPrice, long activationPrice, long offset,
                                     long protectiveSpread, String idempotencyKey);

    default ConditionalView placeConditional(String accountId, String instrument, Conditional.Kind kind, Order.Side side,
                                             long qty, long triggerPrice, long limitPrice, long activationPrice,
                                             long offset, long protectiveSpread) {
        return placeConditional(accountId, instrument, kind, side, qty, triggerPrice, limitPrice, activationPrice, offset,
                protectiveSpread, null);
    }

    ConditionalView cancelConditional(String accountId, long conditionalId);

    List<ConditionalView> conditionals(String accountId, int limit);

    MarginView openMargin(String accountId, String instrument, Order.Side side, long qty, int leverage,
                          String idempotencyKey);

    default MarginView openMargin(String accountId, String instrument, Order.Side side, long qty, int leverage) {
        return openMargin(accountId, instrument, side, qty, leverage, null);
    }

    MarginView closeMargin(String accountId, long positionId);

    List<MarginView> positions(String accountId, int limit);

    SavingsProduct savingsProduct();

    SavingsView openSavings(String accountId, long amount, String idempotencyKey);

    default SavingsView openSavings(String accountId, long amount) {
        return openSavings(accountId, amount, null);
    }

    SavingsView closeSavings(String accountId, long depositId);

    List<SavingsView> savings(String accountId);

    /** Pays interest for the bank days passed by now; called by a timer. */
    void accrueInterest();

    /** My statement for simulation time {@code [from, to)}. */
    StatementProjection.Statement statement(String accountId, long from, long to);

    /** The savings deposit on offer: annual rate, and how long a bank day is in simulation time. */
    record SavingsProduct(String asset, long rateBps, long dayMillis) {}

    record Account(String accountId, String name) {}

    record BookSnapshot(String instrument, List<OrderBook.Level> bids, List<OrderBook.Level> asks, Long lastPrice,
                        long ts) {}

    record ClockState(long now, boolean paused, int speed) {}
}
