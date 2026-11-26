package app.assistant;

import app.bff.Catalogue;
import application.assistant.GlossaryTerms;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;

/**
 * The assistant's glossary (LE-097) over the terms the {@link Catalogue} already loaded from
 * {@code docs/lore/glossary.yaml}: no second read of the file. Every real and lore name, in ru and en, is a key, written
 * the way {@code TemplateAssistant} writes the asked word (lower case, no punctuation, no leading article); a name with
 * a bracket («Налог на доход (ИПН 10%)») is also found without it.
 *
 * <p>Pattern: Port & Adapter — adapts the BFF catalogue to the application's {@link GlossaryTerms} port.
 * See docs/adr/0013-assistant-llm-with-fallback.md.
 */
public final class CatalogueGlossary implements GlossaryTerms {

    private final Map<String, Catalogue.Term> byName = new LinkedHashMap<>();

    public CatalogueGlossary(Catalogue catalogue) {
        for (Catalogue.Term t : catalogue.terms()) {
            for (Catalogue.Name n : new Catalogue.Name[] {t.real(), t.lore()}) {
                if (n == null) {
                    continue;
                }
                for (String name : new String[] {n.ru(), n.en()}) {
                    if (name == null) {
                        continue;
                    }
                    byName.putIfAbsent(key(name), t);
                    byName.putIfAbsent(key(name.replaceAll("\\(.*?\\)", " ")), t);
                }
            }
        }
        byName.remove("");
    }

    @Override
    public Optional<Term> find(String word, String lang) {
        if (word == null) {
            return Optional.empty();
        }
        boolean en = "en".equals(lang);
        return Optional.ofNullable(byName.get(key(word))).map(t -> new Term(t.id(),
                pick(t.real(), en), pick(t.lore(), en), pick(t.definition(), en)));
    }

    /** Lower case, letters and digits only, hyphens as spaces («stop-loss» = «stop loss»), no leading article. */
    static String key(String s) {
        String k = s.toLowerCase(Locale.ROOT).replace('ё', 'е')
                .replaceAll("[^\\p{L}\\p{N}]", " ").trim().replaceAll("\\s+", " ");
        return k.replaceFirst("^(a|an|the) ", "");
    }

    private static String pick(Catalogue.Name n, boolean en) {
        return n == null ? null : en ? n.en() : n.ru();
    }
}
