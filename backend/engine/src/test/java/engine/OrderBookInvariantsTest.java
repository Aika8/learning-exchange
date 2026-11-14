package engine;

import static engine.Order.Side.BUY;
import static engine.Order.Side.SELL;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Random;
import org.junit.jupiter.api.Test;

/** Intent 01 invariants №2 (limit price is respected) and №3 (book never crossed). */
class OrderBookInvariantsTest {

    @Test
    void limitBuyNeverPaysMoreThanItsLimit() {
        OrderBook book = new OrderBook();
        book.submit(Order.limit(SELL, 100, 5));
        book.submit(Order.limit(SELL, 102, 5));

        SubmitResult buy = book.submit(Order.limit(BUY, 101, 10));

        assertEquals(5, buy.filledQty());
        buy.trades().forEach(t -> assertTrue(t.price() <= 101));
        assertEquals(Optional.of(101L), book.bestBid());
        assertEquals(Optional.of(102L), book.bestAsk());
    }

    @Test
    void limitSellNeverReceivesLessThanItsLimit() {
        OrderBook book = new OrderBook();
        book.submit(Order.limit(BUY, 100, 5));
        book.submit(Order.limit(BUY, 98, 5));

        SubmitResult sell = book.submit(Order.limit(SELL, 99, 10));

        assertEquals(5, sell.filledQty());
        sell.trades().forEach(t -> assertTrue(t.price() >= 99));
        assertEquals(Optional.of(98L), book.bestBid());
        assertEquals(Optional.of(99L), book.bestAsk());
    }

    @Test
    void limitOrderAtExactlyTheBestOppositePriceTradesAndLeavesBookUncrossed() {
        OrderBook book = new OrderBook();
        book.submit(Order.limit(SELL, 100, 3));

        SubmitResult buy = book.submit(Order.limit(BUY, 100, 5));

        assertEquals(List.of(100L), buy.trades().stream().map(Trade::price).toList());
        assertEquals(Optional.of(100L), book.bestBid());
        assertEquals(Optional.empty(), book.bestAsk());
    }

    /** Seeded random flow: after every operation №2 and №3 hold. */
    @Test
    void invariantsHoldOverRandomOrderFlow() {
        Random random = new Random(42);
        OrderBook book = new OrderBook();
        List<Long> ids = new ArrayList<>();

        for (int i = 0; i < 5_000; i++) {
            int kind = random.nextInt(10);
            if (kind < 7) {
                Order.Side side = random.nextBoolean() ? BUY : SELL;
                long price = 90 + random.nextInt(21);
                long qty = 1 + random.nextInt(20);
                SubmitResult result = book.submit(Order.limit(side, price, qty));
                ids.add(result.orderId());
                for (Trade t : result.trades()) {
                    assertTrue(side == BUY ? t.price() <= price : t.price() >= price,
                            "limit " + side + "@" + price + " traded at " + t.price());
                }
            } else if (kind < 9 && !ids.isEmpty()) {
                book.cancel(ids.get(random.nextInt(ids.size())));
            } else {
                Order.Side side = random.nextBoolean() ? BUY : SELL;
                ids.add(book.submit(Order.market(side, 1 + random.nextInt(30))).orderId());
            }

            Optional<Long> bid = book.bestBid();
            Optional<Long> ask = book.bestAsk();
            if (bid.isPresent() && ask.isPresent()) {
                assertTrue(bid.get() < ask.get(), "crossed at step " + i + ": " + bid.get() + " >= " + ask.get());
            }
        }
    }
}
