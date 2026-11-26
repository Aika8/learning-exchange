package application.assistant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Locale;
import java.util.Optional;
import org.junit.jupiter.api.Test;

/** LE-096: «what is X?» is answered from the glossary; unknown words and other questions get the numbers. */
class TemplateDefinitionTest {

    /** Three terms, ru and en, in the shape of docs/lore/glossary.yaml. */
    record Entry(String id, String realRu, String realEn, String loreRu, String loreEn, String defRu, String defEn) {}

    static final List<Entry> ENTRIES = List.of(
            new Entry("spread", "Спред", "Spread", "Пропасть", "the Chasm",
                    "Разница между лучшей ценой продажи и лучшей ценой покупки.",
                    "The difference between the best ask and the best bid."),
            new Entry("stop-loss", "Стоп-лосс", "Stop-loss", "Якорь", "the Anchor",
                    "Заявка, которая закрывает позицию, если цена сделки дошла до уровня стопа.",
                    "An order that closes a position when a trade prints at the stop level."),
            new Entry("fee", "Комиссия", "Fee", "Пошлина Биржи", "Exchange toll",
                    "Плата бирже с каждой сделки.", "What the exchange charges on every trade."));

    static final GlossaryTerms GLOSSARY = (word, lang) -> ENTRIES.stream()
            .filter(e -> List.of(e.realRu(), e.realEn(), e.loreRu(), e.loreEn()).stream()
                    .map(n -> n.toLowerCase(Locale.ROOT).replaceFirst("^the ", ""))
                    .anyMatch(word::equals))
            .findFirst()
            .map(e -> "en".equals(lang)
                    ? new GlossaryTerms.Term(e.id(), e.realEn(), e.loreEn(), e.defEn())
                    : new GlossaryTerms.Term(e.id(), e.realRu(), e.loreRu(), e.defRu()));

    static final Facts FACTS = Facts.builder()
            .add("statement.fees", 78, Facts.Kind.MONEY)
            .add("statement.spreadPaid", 75, Facts.Kind.MONEY)
            .add("statement.tax", 0, Facts.Kind.MONEY)
            .add("review.orders", 3, Facts.Kind.COUNT)
            .add("review.wins", 1, Facts.Kind.COUNT)
            .add("review.result", -84, Facts.Kind.MONEY)
            .build();

    final TemplateAssistant withGlossary = new TemplateAssistant(GLOSSARY);

    private String ask(TemplateAssistant a, String text, String lang, Assistant.Persona persona) {
        Assistant.Answer answer = a.answer(new Assistant.Question(text, lang, persona), FACTS);
        assertFalse(new AdviceGuard().isAdvice(answer.text()), answer.text());
        assertEquals(Assistant.Source.TEMPLATE, answer.source());
        return answer.text();
    }

    @Test
    void russianTermQuestionGetsRealNameAndDefinition() {
        assertEquals("Спред — Разница между лучшей ценой продажи и лучшей ценой покупки.",
                ask(withGlossary, "Что такое спред?", "ru", null));
    }

    @Test
    void englishTermQuestionGetsRealNameAndDefinition() {
        assertEquals("Stop-loss — An order that closes a position when a trade prints at the stop level.",
                ask(withGlossary, "What is a stop-loss?", "en", null));
    }

    @Test
    void chroniclerAddsTheLoreName() {
        assertEquals("Якорь (Стоп-лосс) — Заявка, которая закрывает позицию, если цена сделки дошла до уровня стопа.",
                ask(withGlossary, "Что значит стоп-лосс?", "ru", Assistant.Persona.CHRONICLER));
        assertEquals("the Chasm (Spread) — The difference between the best ask and the best bid.",
                ask(withGlossary, "What's the spread?", "en", Assistant.Persona.CHRONICLER));
    }

    @Test
    void termIsFoundAtTheStartOfALongerPhraseAndByItsLoreName() {
        assertEquals("Spread — The difference between the best ask and the best bid.",
                ask(withGlossary, "What does spread mean?", "en", null));
        assertTrue(ask(withGlossary, "Что такое спред и почему я теряю деньги сразу после покупки?", "ru", null)
                .startsWith("Спред — Разница"));
        assertEquals("Fee — What the exchange charges on every trade.",
                ask(withGlossary, "Explain the exchange toll", "en", null));
    }

    @Test
    void unknownTermSaysSoAndGivesTheNumbers() {
        String ru = ask(withGlossary, "Что такое дивиденд?", "ru", null);
        assertTrue(ru.startsWith("Этого слова я пока не знаю — вот ваши цифры. 3 заявок, 1 в плюсе;"), ru);
        String en = ask(withGlossary, "What is a dividend?", "en", null);
        assertTrue(en.startsWith("I don't know that word yet — here are your numbers. 3 orders, 1 in profit;"), en);
    }

    @Test
    void otherQuestionsAreUnchanged() {
        TemplateAssistant without = new TemplateAssistant();
        assertEquals(ask(without, "Как прошла сессия?", "ru", null), ask(withGlossary, "Как прошла сессия?", "ru", null));
        assertEquals(ask(without, "How did the session go?", "en", null),
                ask(withGlossary, "How did the session go?", "en", null));
    }

    @Test
    void withoutAGlossaryTermQuestionsGetTheUsualAnswer() {
        TemplateAssistant without = new TemplateAssistant();
        String t = ask(without, "What is a dividend?", "en", null);
        assertTrue(t.startsWith("3 orders, 1 in profit;"), t);
    }

    @Test
    void adviceGuardStillRunsFirst() {
        String t = ask(withGlossary, "Что такое спред и что купить сейчас?", "ru", null);
        assertTrue(t.startsWith("Я не говорю, что покупать или продавать. Вот что показывают ваши собственные цифры. "
                + "Спред — Разница"), t);
    }
}
