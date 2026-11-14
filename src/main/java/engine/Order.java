package engine;

/**
 * Parameters of an order for the single instrument. Immutable; the book assigns
 * the id and tracks execution when the order is submitted.
 */
public sealed interface Order permits Order.Limit, Order.Market {

    enum Side { BUY, SELL }

    enum Type { LIMIT, MARKET }

    Side side();

    long qty();

    Type type();

    static Limit limit(Side side, long price, long qty) {
        return new Limit(side, price, qty);
    }

    static Market market(Side side, long qty) {
        return new Market(side, qty);
    }

    record Limit(Side side, long price, long qty) implements Order {
        public Limit {
            requireSideAndQty(side, qty);
            if (price <= 0) {
                throw new IllegalArgumentException("limit price must be positive: " + price);
            }
        }

        @Override
        public Type type() { return Type.LIMIT; }

        @Override
        public String toString() { return side + " " + qty + "@" + price; }
    }

    record Market(Side side, long qty) implements Order {
        public Market {
            requireSideAndQty(side, qty);
        }

        @Override
        public Type type() { return Type.MARKET; }

        @Override
        public String toString() { return side + " " + qty + " MKT"; }
    }

    private static void requireSideAndQty(Side side, long qty) {
        if (side == null) {
            throw new IllegalArgumentException("side is required");
        }
        if (qty <= 0) {
            throw new IllegalArgumentException("qty must be positive: " + qty);
        }
    }
}
