package engine;

/** One execution between an incoming order and a resting order, at the resting order's price. */
public record Trade(long buyOrderId, long sellOrderId, long price, long qty) {

    @Override
    public String toString() {
        return "TRADE " + qty + "@" + price + " (buy #" + buyOrderId + ", sell #" + sellOrderId + ")";
    }
}
