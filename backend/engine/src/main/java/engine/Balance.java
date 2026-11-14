package engine;

/** Holdings of one asset in one account: {@code available} can be spent, {@code reserved} backs open orders. */
public record Balance(String asset, long available, long reserved) {

    public long total() {
        return available + reserved;
    }
}
