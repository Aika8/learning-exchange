package app;

import static org.junit.jupiter.api.Assertions.assertEquals;

import app.bff.Catalogue;
import java.nio.file.Path;
import org.junit.jupiter.api.Test;

/** LE-093: the spread's English lore name is «the Chasm», and a market order leaps over it. */
class ChasmNameTest {

    final Catalogue c = new Catalogue(Path.of("docs/lore/catalogue.yaml"), Path.of("docs/lore/glossary.yaml"));

    Catalogue.Term term(String id) {
        return c.terms().stream().filter(t -> t.id().equals(id)).findFirst().orElseThrow();
    }

    @Test
    void spreadLoreNameIsTheChasm() {
        assertEquals("the Chasm", term("spread").lore().en());
        assertEquals("Пропасть", term("spread").lore().ru());
    }

    @Test
    void marketOrderLeapsOverTheChasm() {
        assertEquals("Leap over the Chasm", term("market-order").lore().en());
    }
}
