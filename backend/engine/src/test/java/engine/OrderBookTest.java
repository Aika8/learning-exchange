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
        SubmitResult result = book.submit(Order.limit(BUY, 100, 10));

        assertTrue(result.trades().isEmpty());
        assertEquals(Optional.of(100L), book.bestBid());
        assertEquals(Optional.empty(), book.bestAsk());
        assertEquals(List.of(new OrderBook.Level(100, 10, 1)), book.bids(5));
    }

    @Test
    void limitBuySweepsTwoAskLevelsAtRestingPrices() {
        long ask100 = book.submit(Order.limit(SELL, 100, 5)).orderId();
        long ask101 = book.submit(Order.limit(SELL, 101, 10)).orderId();

        SubmitResult buy = book.submit(Order.limit(BUY, 101, 12));

        assertEquals(List.of(
                new Trade(buy.orderId(), ask100, 100, 5, BUY),
                new Trade(buy.orderId(), ask101, 101, 7, BUY)), buy.trades());
        assertEquals(12, buy.filledQty());
        assertEquals(Optional.empty(), book.bestBid());
        assertEquals(List.of(new OrderBook.Level(101, 3, 1)), book.asks(5));
    }

    @Test
    void tradeRecordsIncomingLimitBuyAsAggressor() {
        book.submit(Order.limit(SELL, 100, 5));
        book.submit(Order.limit(SELL, 101, 10));

        SubmitResult buy = book.submit(Order.limit(BUY, 101, 12));

        assertEquals(2, buy.trades().size());
        assertTrue(buy.trades().stream().allMatch(t -> t.aggressorSide() == BUY));
    }

    @Test
    void marketBuyFillsAvailableLiquidityAndCancelsTheRest() {
        book.submit(Order.limit(SELL, 100, 20));
        book.submit(Order.limit(SELL, 102, 15));

        SubmitResult buy = book.submit(Order.market(BUY, 40));

        assertEquals(35, buy.filledQty());
        assertEquals(5, 40 - buy.filledQty());
        assertEquals(Optional.empty(), book.bestBid());
        assertEquals(Optional.empty(), book.bestAsk());
        assertFalse(book.cancel(buy.orderId()), "market remainder must not rest");
    }

    @Test
    void limitBuyPartiallyFillsAndRemainderRestsOnBidSide() {
        long ask = book.submit(Order.limit(SELL, 100, 5)).orderId();

        SubmitResult buy = book.submit(Order.limit(BUY, 100, 12));

        assertEquals(List.of(new Trade(buy.orderId(), ask, 100, 5, BUY)), buy.trades());
        assertEquals(Optional.empty(), book.bestAsk());
        assertEquals(Optional.of(100L), book.bestBid());
        assertEquals(List.of(new OrderBook.Level(100, 7, 1)), book.bids(5));
    }

    @Test
    void cancelRemovesOrderAndEmptiesItsLevel() {
        long bid99 = book.submit(Order.limit(BUY, 99, 10)).orderId();
        book.submit(Order.limit(BUY, 98, 10));
        long ask101 = book.submit(Order.limit(SELL, 101, 10)).orderId();

        assertTrue(book.cancel(bid99));
        assertTrue(book.cancel(ask101));

        assertEquals(Optional.of(98L), book.bestBid());
        assertEquals(Optional.empty(), book.bestAsk());
        assertEquals(List.of(new OrderBook.Level(98, 10, 1)), book.bids(5));
        assertFalse(book.cancel(bid99), "cancelled order is no longer in the book");
    }

    @Test
    void newOrderAfterCancelGetsStrictlyGreaterId() {
        long cancelled = book.submit(Order.limit(BUY, 99, 10)).orderId();
        assertTrue(book.cancel(cancelled));

        long next = book.submit(Order.limit(BUY, 99, 10)).orderId();

        assertTrue(next > cancelled, "id " + next + " must be greater than cancelled id " + cancelled);
    }

    @Test
    void earlierOrderAtSamePriceFillsFirst() {
        long first = book.submit(Order.limit(SELL, 100, 5)).orderId();
        long second = book.submit(Order.limit(SELL, 100, 5)).orderId();

        SubmitResult buy = book.submit(Order.limit(BUY, 100, 7));

        assertEquals(List.of(
                new Trade(buy.orderId(), first, 100, 5, BUY),
                new Trade(buy.orderId(), second, 100, 2, BUY)), buy.trades());
        assertEquals(List.of(new OrderBook.Level(100, 3, 1)), book.asks(5));
    }
}
