package application.assistant;

import java.util.Optional;

/**
 * Where the assistant looks up a finance term (LE-096): «что такое спред?», «what is a stop-loss?». The app implements
 * it over {@code docs/lore/glossary.yaml} (LE-097); the application layer does not read files.
 *
 * <p>Pattern: Port & Adapter — the template asks for a term without knowing where the glossary lives.
 * See docs/adr/0013-assistant-llm-with-fallback.md.
 */
public interface GlossaryTerms {

    /** One term in one language: the real name, the lore name (game) and a one-line definition. */
    record Term(String id, String realName, String loreName, String definition) {}

    /**
     * Finds a term by a word or phrase in ru or en (its real or lore name). {@code word} is lower-case, trimmed, without
     * punctuation and without a leading English article. {@code lang} ("ru" or "en") picks the language of the answer.
     */
    Optional<Term> find(String word, String lang);

    /** A glossary that knows no terms: the assistant then answers as before LE-096. */
    static GlossaryTerms empty() {
        return (word, lang) -> Optional.empty();
    }
}
