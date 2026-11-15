package engine;

/** Read view of a savings deposit. */
public record SavingsView(long depositId, String account, String asset, long principal, long balance, long rateBps,
                          boolean open, long openedTs, Long closedTs) {

    public long interest() {
        return balance - principal;
    }
}
