package application.assistant;

/**
 * Tries the primary assistant (the LLM); on any failure, an empty text, or text the {@link AdviceGuard} rejects, the
 * fallback (the template) answers. A question that asks for advice never reaches the model.
 *
 * <p>Pattern: Fallback / graceful degradation (a Decorator over the port). See docs/adr/0013-assistant-llm-with-fallback.md.
 */
public final class FallbackAssistant implements Assistant {

    private final Assistant primary;
    private final Assistant fallback;
    private final AdviceGuard guard;

    public FallbackAssistant(Assistant primary, Assistant fallback, AdviceGuard guard) {
        this.primary = primary;
        this.fallback = fallback;
        this.guard = guard;
    }

    @Override
    public Answer answer(Question question, Facts facts) {
        if (guard.asksForAdvice(question.text())) {
            return guarded(fallback.answer(question, facts));
        }
        Answer a;
        try {
            a = primary == null ? null : primary.answer(question, facts);
        } catch (RuntimeException e) {
            a = null;
        }
        if (a == null || a.text() == null || a.text().isBlank()) {
            return fallback.answer(question, facts);
        }
        if (guard.isAdvice(a.text())) {
            return guarded(fallback.answer(question, facts));
        }
        return a;
    }

    private static Answer guarded(Answer a) {
        return new Answer(a.text(), a.source(), a.model(), a.disclaimer(), true, a.facts());
    }
}
