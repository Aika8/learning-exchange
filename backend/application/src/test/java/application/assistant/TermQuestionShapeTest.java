package application.assistant;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

/** LE-406: a term question is a question about a word, not any sentence that contains «what is» / «объясни». */
class TermQuestionShapeTest {

    final TemplateAssistant withGlossary = new TemplateAssistant(TemplateDefinitionTest.GLOSSARY);
    final TemplateAssistant without = new TemplateAssistant();

    private String ask(TemplateAssistant a, String text, String lang) {
        Assistant.Answer answer = a.answer(new Assistant.Question(text, lang, null), TemplateDefinitionTest.FACTS);
        assertFalse(new AdviceGuard().isAdvice(answer.text()), answer.text());
        return answer.text();
    }

    @Test
    void aQuestionAboutMyNumbersIsNotATermQuestion() {
        String t = ask(withGlossary, "What is my result?", "en");
        assertFalse(t.contains("I don't know that word"), t);
        assertEquals(ask(without, "What is my result?", "en"), t);
    }

    @Test
    void explainHowSomethingWentIsNotATermQuestion() {
        String t = ask(withGlossary, "Объясни, как прошла сессия", "ru");
        assertFalse(t.contains("Этого слова я пока не знаю"), t);
        assertEquals(ask(without, "Объясни, как прошла сессия", "ru"), t);
    }

    @Test
    void thePhraseInTheMiddleOfAQuestionDoesNotMakeItATermQuestion() {
        String t = ask(withGlossary, "Скажи честно, что такое со мной сегодня было на рынке?", "ru");
        assertFalse(t.contains("Этого слова я пока не знаю"), t);
        assertTrue(t.startsWith("3 заявок, 1 в плюсе;"), t);
    }

    @Test
    void aPlainTermQuestionStillGetsTheGlossaryAnswer() {
        assertEquals("Спред — Разница между лучшей ценой продажи и лучшей ценой покупки.",
                ask(withGlossary, "Что такое спред?", "ru"));
    }

    @Test
    void anUnknownShortTermStillSaysSo() {
        assertTrue(ask(withGlossary, "Что такое дивиденд?", "ru").startsWith("Этого слова я пока не знаю"));
    }

    @Test
    void aTermAndMyLossGetTheDefinitionAndTheCostNumbers() {
        String t = ask(withGlossary, "Что такое спред и сколько я на нём потерял?", "ru");
        assertTrue(t.startsWith("Спред — Разница между лучшей ценой продажи и лучшей ценой покупки. "), t);
        assertTrue(t.contains("0.78 SPARK комиссий и около 0.75 SPARK спреда"), t);
    }

    @Test
    void englishTermAndWhatIPaidGetTheDefinitionAndTheNumbers() {
        String t = ask(withGlossary, "What is the spread and how much did I pay for it?", "en");
        assertTrue(t.startsWith("Spread — The difference between the best ask and the best bid. "), t);
        assertTrue(t.contains("0.78 SPARK in fees and about 0.75 SPARK in spread"), t);
    }
}
