package repl;

import engine.Order;
import engine.OrderBook;
import engine.Trade;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.List;

/** Line-based console for the order book. Ids and timestamps come from one counter. */
public final class Repl {

    private static final int DEPTH = 5;

    private final OrderBook book = new OrderBook();
    private long nextId = 1;

    public static void main(String[] args) throws IOException {
        new Repl().run(new BufferedReader(new InputStreamReader(System.in)));
    }

    private void run(BufferedReader in) throws IOException {
        System.out.println("commands: buy|sell <qty>[@<price>], cancel <id>, book, quit");
        String line;
        while (prompt() && (line = in.readLine()) != null) {
            line = line.trim();
            if (line.isEmpty()) {
                continue;
            }
            if (line.equals("quit")) {
                return;
            }
            try {
                execute(line);
            } catch (IllegalArgumentException e) {
                System.out.println("error: " + e.getMessage());
            }
        }
    }

    private static boolean prompt() {
        System.out.print("> ");
        System.out.flush();
        return true;
    }

    private void execute(String line) {
        String[] parts = line.split("\\s+");
        List<Trade> trades = List.of();
        switch (parts[0]) {
            case "buy", "sell" -> {
                if (parts.length != 2) {
                    throw new IllegalArgumentException("usage: " + parts[0] + " <qty>[@<price>]");
                }
                trades = submit(parts[0].equals("buy") ? Order.Side.BUY : Order.Side.SELL, parts[1]);
            }
            case "cancel" -> {
                if (parts.length != 2) {
                    throw new IllegalArgumentException("usage: cancel <id>");
                }
                long id = parseLong(parts[1], "id");
                System.out.println(book.cancel(id) ? "cancelled #" + id : "no resting order #" + id);
            }
            case "book" -> { }
            default -> throw new IllegalArgumentException("unknown command: " + parts[0]);
        }
        trades.forEach(System.out::println);
        printBook();
    }

    private List<Trade> submit(Order.Side side, String terms) {
        long id = nextId++;
        int at = terms.indexOf('@');
        Order order = at < 0
                ? Order.market(id, side, parseLong(terms, "qty"), id)
                : Order.limit(id, side, parseLong(terms.substring(at + 1), "price"),
                        parseLong(terms.substring(0, at), "qty"), id);
        List<Trade> trades = book.submit(order);
        System.out.println("order " + order);
        if (order.type() == Order.Type.MARKET && order.remaining() > 0) {
            System.out.println("cancelled unfilled market remainder: " + order.remaining());
        }
        return trades;
    }

    private void printBook() {
        System.out.println("  ASKS");
        List<OrderBook.Level> asks = book.asks(DEPTH);
        for (int i = asks.size() - 1; i >= 0; i--) {
            printLevel(asks.get(i));
        }
        System.out.println("  ----");
        book.bids(DEPTH).forEach(Repl::printLevel);
        System.out.println("  BIDS");
    }

    private static void printLevel(OrderBook.Level level) {
        System.out.printf("  %8d  %8d  (%d)%n", level.price(), level.qty(), level.orders());
    }

    private static long parseLong(String s, String what) {
        try {
            return Long.parseLong(s);
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("bad " + what + ": " + s);
        }
    }
}
