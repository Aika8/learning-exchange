package engine;

import static engine.Order.Side.BUY;
import static engine.Order.Side.SELL;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class OrderBookTest {

    private final OrderBook book = new OrderBook();

    @Test
    void limitBuyRestsWhenBookIsEmpty() {
        List<Trade> trades = book.submit(Order.limit(1, BUY, 100, 10, 1));

        assertTrue(trades.isEmpty());
        assertEquals(Optional.of(100L), book.bestBid());
        assertEquals(Optional.empty(), book.bestAsk());
        assertEquals(List.of(new OrderBook.Level(100, 10, 1)), book.bids(5));
    }

    @Test
    void limitBuySweepsTwoAskLevelsAtRestingPrices() {
        book.submit(Order.limit(1, SELL, 100, 5, 1));
        book.submit(Order.limit(2, SELL, 101, 10, 2));
        Order buy = Order.limit(3, BUY, 101, 12, 3);

        List<Trade> trades = book.submit(buy);

        assertEquals(List.of(new Trade(3, 1, 100, 5), new Trade(3, 2, 101, 7)), trades);
        assertEquals(0, buy.remaining());
        assertEquals(Optional.empty(), book.bestBid());
        assertEquals(List.of(new OrderBook.Level(101, 3, 1)), book.asks(5));
    }

    @Test
    void marketBuyFillsAvailableLiquidityAndCancelsTheRest() {
        book.submit(Order.limit(1, SELL, 100, 20, 1));
        book.submit(Order.limit(2, SELL, 102, 15, 2));
        Order buy = Order.market(3, BUY, 40, 3);

        List<Trade> trades = book.submit(buy);

        assertEquals(35, trades.stream().mapToLong(Trade::qty).sum());
        assertEquals(35, buy.filled());
        assertEquals(5, buy.remaining());
        assertEquals(Optional.empty(), book.bestBid());
        assertEquals(Optional.empty(), book.bestAsk());
        assertFalse(book.cancel(3), "market remainder must not rest");
    }

    @Test
    void limitBuyPartiallyFillsAndRemainderRestsOnBidSide() {
        book.submit(Order.limit(1, SELL, 100, 5, 1));

        List<Trade> trades = book.submit(Order.limit(2, BUY, 100, 12, 2));

        assertEquals(List.of(new Trade(2, 1, 100, 5)), trades);
        assertEquals(Optional.empty(), book.bestAsk());
        assertEquals(Optional.of(100L), book.bestBid());
        assertEquals(List.of(new OrderBook.Level(100, 7, 1)), book.bids(5));
    }

    @Test
    void cancelRemovesOrderAndEmptiesItsLevel() {
        book.submit(Order.limit(1, BUY, 99, 10, 1));
        book.submit(Order.limit(2, BUY, 98, 10, 2));
        book.submit(Order.limit(3, SELL, 101, 10, 3));

        assertTrue(book.cancel(1));
        assertTrue(book.cancel(3));

        assertEquals(Optional.of(98L), book.bestBid());
        assertEquals(Optional.empty(), book.bestAsk());
        assertEquals(List.of(new OrderBook.Level(98, 10, 1)), book.bids(5));
        assertFalse(book.cancel(1), "cancelled order is no longer in the book");
    }

    @Test
    void earlierOrderAtSamePriceFillsFirst() {
        book.submit(Order.limit(1, SELL, 100, 5, 1));
        book.submit(Order.limit(2, SELL, 100, 5, 2));

        List<Trade> trades = book.submit(Order.limit(3, BUY, 100, 7, 3));

        assertEquals(List.of(new Trade(3, 1, 100, 5), new Trade(3, 2, 100, 2)), trades);
        assertEquals(List.of(new OrderBook.Level(100, 3, 1)), book.asks(5));
    }
}
