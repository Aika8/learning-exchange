package app;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import app.bff.Catalogue;
import java.nio.file.Path;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.junit.jupiter.api.Test;

/**
 * LE-088: the terms the app and the game already show (trailing take-profit, ATR, fund TER, price level) are in the
 * glossary, so both BFFs can define them.
 */
class GlossaryHasToolTermsTest {

    final Catalogue c = new Catalogue(Path.of("docs/lore/catalogue.yaml"), Path.of("docs/lore/glossary.yaml"));

    @Test
    void toolTermsArePresentWithAllSixStrings() {
        Map<String, Catalogue.Term> byId = c.terms().stream().collect(Collectors.toMap(Catalogue.Term::id, Function.identity()));
        for (String id : new String[] {"trailing-take-profit", "atr", "fund-ter", "price-level"}) {
            Catalogue.Term t = byId.get(id);
            assertTrue(t != null, "glossary has no term " + id);
            for (Catalogue.Name n : new Catalogue.Name[] {t.real(), t.lore(), t.definition()}) {
                assertFalse(n == null || n.ru() == null || n.en() == null || n.ru().isBlank() || n.en().isBlank(), id);
            }
        }
    }

    @Test
    void ruLoreNamesFollowTheWorldBible() {
        Map<String, String> lore = c.terms().stream().collect(Collectors.toMap(Catalogue.Term::id, t -> t.lore().ru()));
        Map<String, String> expected = Map.of(
                "trailing-take-profit", "Попутный парус",
                "atr", "Высота волны",
                "fund-ter", "Плата за ведение фонда",
                "price-level", "Ступень");
        expected.forEach((id, ru) -> assertTrue(ru.equals(lore.get(id)), id + ": " + lore.get(id)));
    }
}
