package engine;

/**
 * One execution between an incoming order and a resting order, at the resting order's price.
 * {@code aggressorSide} is the side of the incoming order.
 */
public record Trade(long buyOrderId, long sellOrderId, long price, long qty, Order.Side aggressorSide) {

    @Override
    public String toString() {
        return "TRADE " + qty + "@" + price + " (buy #" + buyOrderId + ", sell #" + sellOrderId
                + ", aggressor " + aggressorSide + ")";
    }
}
