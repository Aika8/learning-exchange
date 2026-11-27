package application.assistant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

/** AUTO-20261127-1: a short lead-in («а», «скажи», «so», «can you») or the polite «объясните» keeps a term question. */
class TermQuestionLeadInTest {

    final TemplateAssistant withGlossary = new TemplateAssistant(TemplateDefinitionTest.GLOSSARY);
    final TemplateAssistant without = new TemplateAssistant();

    private String ask(TemplateAssistant a, String text, String lang) {
        Assistant.Answer answer = a.answer(new Assistant.Question(text, lang, null), TemplateDefinitionTest.FACTS);
        assertFalse(new AdviceGuard().isAdvice(answer.text()), answer.text());
        return answer.text();
    }

    @ParameterizedTest
    @ValueSource(strings = {"а что такое спред?", "скажи, что такое спред?", "Объясните, пожалуйста, что такое спред",
            "объясните спред"})
    void russianLeadInsStillGetTheDefinition(String text) {
        assertEquals("Спред — Разница между лучшей ценой продажи и лучшей ценой покупки.", ask(withGlossary, text, "ru"));
    }

    @ParameterizedTest
    @ValueSource(strings = {"So what is a spread?", "Can you explain spread?"})
    void englishLeadInsStillGetTheDefinition(String text) {
        assertEquals("Spread — The difference between the best ask and the best bid.", ask(withGlossary, text, "en"));
    }

    @Test
    void politeExplainHowSomethingWentStaysAnOrdinaryQuestion() {
        String t = ask(withGlossary, "Объясните, как прошла сессия", "ru");
        assertFalse(t.contains("Этого слова я пока не знаю"), t);
        assertEquals(ask(without, "Объясните, как прошла сессия", "ru"), t);
    }

    @Test
    void soWhatIsMyResultStaysAnOrdinaryQuestion() {
        String t = ask(withGlossary, "So what is my result?", "en");
        assertFalse(t.contains("I don't know that word"), t);
        assertEquals(ask(without, "So what is my result?", "en"), t);
    }
}
