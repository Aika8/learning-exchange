package engine;

/** Read view of one order and how far it got. */
public record OrderView(long orderId, String account, String instrument, Order.Side side, Order.Type type,
                        long price, long qty, long filledQty, Status status, long createdTs) {

    public enum Status { NEW, PARTIALLY_FILLED, FILLED, CANCELLED, EXPIRED }

    public long remainingQty() {
        return qty - filledQty;
    }

    public boolean open() {
        return status == Status.NEW || status == Status.PARTIALLY_FILLED;
    }
}
