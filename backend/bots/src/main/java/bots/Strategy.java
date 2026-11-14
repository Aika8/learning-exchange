package bots;

import java.util.List;
import java.util.Random;

/**
 * Pattern: Strategy — bots differ only in this decision. Each strategy is a small pure function of what it sees and
 * its own seeded randomness, so it is easy to test and replay. See docs/adr/0007-bots-are-api-clients.md.
 */
public interface Strategy {

    List<Intent> decide(MarketView view, Random random);
}
