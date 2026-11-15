package app;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import app.bff.Catalogue;
import application.economy.Securities;
import engine.Instrument;
import java.nio.file.Path;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

/** ADR-0012: every engine instrument and every glossary term has real and lore names in ru and en. */
class CatalogueTest {

    final Catalogue c = new Catalogue(Path.of("docs/lore/catalogue.yaml"), Path.of("docs/lore/glossary.yaml"));

    static void complete(Catalogue.Name n, String what) {
        assertFalse(n == null || n.ru() == null || n.en() == null || n.ru().isBlank() || n.en().isBlank(), what);
    }

    @Test
    void everyInstrumentHasFourNamesAndItsKind() {
        assertEquals(Instrument.ALL.stream().map(Instrument::id).toList(), c.items().stream().map(Catalogue.Item::instrument).toList());
        for (Catalogue.Item i : c.items()) {
            complete(i.real(), i.instrument());
            complete(i.lore(), i.instrument());
            assertEquals(Securities.kind(i.instrument()), i.kind(), i.instrument());
        }
    }

    @Test
    void everyTermHasSixStrings() {
        assertFalse(c.terms().isEmpty());
        for (Catalogue.Term t : c.terms()) {
            Stream.of(t.real(), t.lore(), t.definition()).forEach(n -> complete(n, t.id()));
        }
    }
}
