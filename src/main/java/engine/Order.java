package engine;

/**
 * An order for the single instrument. Identity and terms are immutable;
 * only the filled quantity changes as the order executes.
 */
public final class Order {

    public enum Side { BUY, SELL }

    public enum Type { LIMIT, MARKET }

    private final long id;
    private final Side side;
    private final Type type;
    private final long price;
    private final long qty;
    private final long timestamp;
    private long filled;

    public Order(long id, Side side, Type type, long price, long qty, long timestamp) {
        if (side == null || type == null) {
            throw new IllegalArgumentException("side and type are required");
        }
        if (qty <= 0) {
            throw new IllegalArgumentException("qty must be positive: " + qty);
        }
        if (type == Type.LIMIT && price <= 0) {
            throw new IllegalArgumentException("limit price must be positive: " + price);
        }
        if (type == Type.MARKET && price != 0) {
            throw new IllegalArgumentException("market order must have price 0: " + price);
        }
        this.id = id;
        this.side = side;
        this.type = type;
        this.price = price;
        this.qty = qty;
        this.timestamp = timestamp;
    }

    public static Order limit(long id, Side side, long price, long qty, long timestamp) {
        return new Order(id, side, Type.LIMIT, price, qty, timestamp);
    }

    public static Order market(long id, Side side, long qty, long timestamp) {
        return new Order(id, side, Type.MARKET, 0, qty, timestamp);
    }

    public long id() { return id; }
    public Side side() { return side; }
    public Type type() { return type; }
    public long price() { return price; }
    public long qty() { return qty; }
    public long timestamp() { return timestamp; }
    public long filled() { return filled; }
    public long remaining() { return qty - filled; }

    void fill(long amount) {
        if (amount <= 0 || amount > remaining()) {
            throw new IllegalStateException("bad fill " + amount + " for remaining " + remaining());
        }
        filled += amount;
    }

    @Override
    public String toString() {
        String at = type == Type.LIMIT ? "@" + price : " MKT";
        return "#" + id + " " + side + " " + remaining() + "/" + qty + at;
    }
}
