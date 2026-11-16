package application.assistant;

import java.util.List;

/**
 * The assistant port (ADR-0013): «Помощник» in the app and the web, «Летописец» in the game. Numbers come from code
 * ({@link Facts}); an adapter only turns them into words.
 *
 * <p>Pattern: Port & Adapter — the LLM and the template are interchangeable behind this interface.
 * See docs/adr/0013-assistant-llm-with-fallback.md.
 */
public interface Assistant {

    Answer answer(Question question, Facts facts);

    enum Persona { HELPER, CHRONICLER }

    enum Source { CLAUDE, TEMPLATE }

    record Question(String text, String lang, Persona persona) {
        public Question {
            lang = "en".equals(lang) ? "en" : "ru";
            persona = persona == null ? Persona.HELPER : persona;
        }

        public boolean english() {
            return "en".equals(lang);
        }
    }

    /** {@code guarded}: the model's text (or the question) looked like advice and the template answered instead. */
    record Answer(String text, Source source, String model, String disclaimer, boolean guarded, List<Facts.Fact> facts) {}

    static String disclaimer(String lang) {
        return "en".equals(lang)
                ? "Learning exchange, play money. This explains your own numbers; it is not investment advice."
                : "Учебная биржа, игровые деньги. Это разбор ваших собственных цифр, а не инвестиционный совет.";
    }
}
