package bots;

import engine.OrderView;
import java.util.List;

/**
 * What a bot sees before deciding: the same public data a person sees in a client, plus its own orders and money.
 * Prices in quote minor units; {@code null} when there is none.
 */
public record MarketView(String instrument, Long bestBid, Long bestAsk, Long lastPrice, long fairValue,
                         List<OrderView> myOpenOrders, long baseAvailable, long quoteAvailable, long baseTotal) {
}
