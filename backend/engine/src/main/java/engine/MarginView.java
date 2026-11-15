package engine;

/** Read view of a leveraged position, valued at the last trade price. Nullable fields are null until known. */
public record MarginView(long positionId, String account, String instrument, Order.Side side, long qty, int leverage,
                         long collateral, long loanQuote, long loanBase, long entryPrice, Long lastPrice, long equity,
                         long stopOutEquity, Long stopOutPrice, Status status, String closeReason, Long returned,
                         Long badDebt, long openedTs, Long closedTs) {

    public enum Status { OPEN, CLOSING, CLOSED }
}
