package engine;

import java.util.List;

/** Outcome of {@link OrderBook#submit}: the id the book assigned and the trades it produced. */
public record SubmitResult(long orderId, List<Trade> trades) {

    public SubmitResult {
        trades = List.copyOf(trades);
    }

    /** Total quantity executed by this submit. */
    public long filledQty() {
        return trades.stream().mapToLong(Trade::qty).sum();
    }
}
