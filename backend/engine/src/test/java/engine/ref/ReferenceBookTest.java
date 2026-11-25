package engine.ref;

import static engine.Order.Side.BUY;
import static engine.Order.Side.SELL;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import org.junit.jupiter.api.Test;

/** One example per invariant of intent/01-order-book.md, plus the edges the differential tests will lean on. */
class ReferenceBookTest {

    private final ReferenceBook book = new ReferenceBook();

    @Test
    void inv1_earlierOrderAtSamePriceExecutesFirst() {
        long first = book.submitLimit(SELL, 100, 5);
        long second = book.submitLimit(SELL, 100, 5);
        long buy = book.submitLimit(BUY, 100, 7);
        assertEquals(List.of(
                new RefTrade(buy, first, 100, 5, BUY),
                new RefTrade(buy, second, 100, 2, BUY)), book.lastTrades());
        assertEquals(List.of(new RefLevel(100, 3, 1)), book.asks(5));
    }

    @Test
    void inv1_betterPriceBeatsEarlierArrival() {
        long worse = book.submitLimit(BUY, 99, 5);
        long better = book.submitLimit(BUY, 100, 5);
        long sell = book.submitMarket(SELL, 6);
        assertEquals(List.of(
                new RefTrade(better, sell, 100, 5, SELL),
                new RefTrade(worse, sell, 99, 1, SELL)), book.lastTrades());
    }

    @Test
    void inv2_limitNeverExecutesWorseThanItsLimit_andTradesAtRestingPrice() {
        long cheap = book.submitLimit(SELL, 98, 2);
        book.submitLimit(SELL, 101, 5);
        long buy = book.submitLimit(BUY, 100, 10);
        assertEquals(List.of(new RefTrade(buy, cheap, 98, 2, BUY)), book.lastTrades());
        assertEquals(List.of(new RefLevel(100, 8, 1)), book.bids(5));
        assertEquals(List.of(new RefLevel(101, 5, 1)), book.asks(5));
    }

    @Test
    void inv3_bookIsNeverCrossed() {
        book.submitLimit(BUY, 100, 5);
        book.submitLimit(SELL, 100, 3); // would cross: trades instead of resting
        book.submitLimit(SELL, 99, 4);  // takes the rest of the bid, then rests at 99
        assertEquals(List.of(), book.bids(5));
        assertEquals(List.of(new RefLevel(99, 2, 1)), book.asks(5));
        book.submitLimit(BUY, 98, 1);
        assertTrue(book.bids(1).get(0).price() < book.asks(1).get(0).price());
    }

    @Test
    void inv4_marketRemainderIsCancelledAndNeverRests() {
        long sell = book.submitLimit(SELL, 100, 3);
        long buy = book.submitMarket(BUY, 10);
        assertEquals(List.of(new RefTrade(buy, sell, 100, 3, BUY)), book.lastTrades());
        assertEquals(List.of(), book.bids(5));
        assertEquals(List.of(), book.asks(5));
        assertFalse(book.cancel(buy));
    }

    @Test
    void inv5_cancelledOrderIsGoneAndNeverExecutes() {
        long first = book.submitLimit(SELL, 100, 5);
        long second = book.submitLimit(SELL, 100, 5);
        assertTrue(book.cancel(first));
        assertFalse(book.cancel(first));
        assertEquals(List.of(new RefLevel(100, 5, 1)), book.asks(5));
        long buy = book.submitMarket(BUY, 10);
        assertEquals(List.of(new RefTrade(buy, second, 100, 5, BUY)), book.lastTrades());
    }

    @Test
    void inv6_emptyLevelIsRemoved_bestPriceHasQuantity() {
        book.submitLimit(SELL, 100, 2);
        book.submitLimit(SELL, 101, 4);
        book.submitLimit(BUY, 100, 2);
        assertEquals(List.of(new RefLevel(101, 4, 1)), book.asks(5));
        long last = book.submitLimit(SELL, 102, 1);
        book.cancel(last);
        assertEquals(List.of(new RefLevel(101, 4, 1)), book.asks(5));
    }

    @Test
    void inv7_filledNeverExceedsQuantity_remainingIsQuantityMinusFilled() {
        long sell = book.submitLimit(SELL, 100, 10);
        book.submitMarket(BUY, 3);
        assertEquals(List.of(new RefLevel(100, 7, 1)), book.asks(5));
        long buy = book.submitMarket(BUY, 20);
        assertEquals(List.of(new RefTrade(buy, sell, 100, 7, BUY)), book.lastTrades());
        assertEquals(List.of(), book.asks(5));
        assertFalse(book.cancel(sell)); // fully filled: nothing left to cancel
    }

    @Test
    void marketOrderOnEmptySideGetsAnIdAndNoTrades() {
        book.submitLimit(BUY, 100, 5);
        long id = book.submitMarket(BUY, 5);
        assertEquals(2, id);
        assertEquals(List.of(), book.lastTrades());
        assertEquals(List.of(new RefLevel(100, 5, 1)), book.bids(5));
    }

    @Test
    void cancelOfUnknownIdReturnsFalse() {
        assertFalse(book.cancel(42));
        book.submitLimit(BUY, 100, 1);
        assertFalse(book.cancel(42));
        assertEquals(List.of(new RefLevel(100, 1, 1)), book.bids(5));
    }

    @Test
    void idsStartAtOneAndEveryOrderTakesOne_rejectedOrdersTakeNone() {
        assertEquals(1, book.submitLimit(BUY, 100, 1));
        assertThrows(IllegalArgumentException.class, () -> book.submitLimit(BUY, 0, 1));
        assertThrows(IllegalArgumentException.class, () -> book.submitMarket(SELL, 0));
        assertEquals(2, book.submitMarket(SELL, 1)); // fills completely, still gets an id
        assertEquals(3, book.submitLimit(SELL, 100, 1));
    }

    @Test
    void levelsAreBestFirstAndAggregated() {
        book.submitLimit(BUY, 99, 1);
        book.submitLimit(BUY, 101, 2);
        book.submitLimit(BUY, 101, 3);
        book.submitLimit(BUY, 100, 4);
        assertEquals(List.of(new RefLevel(101, 5, 2), new RefLevel(100, 4, 1)), book.bids(2));
        book.submitLimit(SELL, 105, 1);
        book.submitLimit(SELL, 103, 1);
        assertEquals(List.of(new RefLevel(103, 1, 1), new RefLevel(105, 1, 1)), book.asks(5));
    }
}
