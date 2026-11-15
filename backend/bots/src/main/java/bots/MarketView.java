package bots;

import engine.OrderView;
import java.util.List;

/**
 * What a bot sees before deciding: the same public data a person sees in a client, plus its own orders and money.
 * Prices in quote minor units; {@code null} when there is none.
 */
public record MarketView(String instrument, Long bestBid, Long bestAsk, Long lastPrice, long fairValue,
                         List<OrderView> myOpenOrders, long baseAvailable, long quoteAvailable, long baseTotal,
                         List<Long> recentPrices, Long fundamentalValue, long step) {

    /** M1/M2a shape: no price history, no published fundamentals. */
    public MarketView(String instrument, Long bestBid, Long bestAsk, Long lastPrice, long fairValue,
                      List<OrderView> myOpenOrders, long baseAvailable, long quoteAvailable, long baseTotal) {
        this(instrument, bestBid, bestAsk, lastPrice, fairValue, myOpenOrders, baseAvailable, quoteAvailable, baseTotal,
                List.of(), null, 0);
    }
}
