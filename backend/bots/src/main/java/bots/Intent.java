package bots;

import engine.Order;

/** What a strategy wants to do; the bot turns intents into calls on the TradingService port. */
public sealed interface Intent {

    record Place(Order.Side side, Order.Type type, long price, long qty) implements Intent {}

    record CancelAllMine() implements Intent {}
}
