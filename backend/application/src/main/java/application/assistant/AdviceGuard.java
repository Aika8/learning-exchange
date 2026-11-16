package application.assistant;

import java.util.regex.Pattern;

/**
 * Rejects text that tells the person to buy or sell (ru and en). The model is told not to advise; this guard does
 * not trust it. A question that asks for advice is recognised too, so the template can say why it won't answer.
 *
 * <p>Plain code, no pattern: a list of regular expressions is clearer than a rule engine here.
 */
public final class AdviceGuard {

    private static final int FLAGS = Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE | Pattern.UNICODE_CHARACTER_CLASS;

    private static final Pattern ADVICE = Pattern.compile(String.join("|",
            "\\b(купи(те)?|продай(те)?|покупайте|продавайте|докупи(те)?|закупись|шорти(те)?)\\b",
            "\\b(стоит|следует|советую|рекомендую|нужно|надо)\\s+(сейчас\\s+)?(купить|продать|покупать|продавать|вложить|докупить)",
            "\\b(you\\s+should|i\\s+(would\\s+)?recommend|i\\s+suggest|it'?s\\s+time\\s+to|consider)\\s+(buying|selling|to\\s+buy|to\\s+sell|buy|sell)\\b",
            "(^|[.!?]\\s*)(buy|sell|short)\\s+(now|more|it|this|the|some|\\p{Lu}{3,})",
            "\\b(strong\\s+)?(buy|sell)\\s+(signal|rating|recommendation)\\b"), FLAGS);

    private static final Pattern ASKS_ADVICE = Pattern.compile(String.join("|",
            "(что|какие|какую|какой|стоит ли|надо ли|нужно ли)\\s+.{0,30}(купить|продать|покупать|продавать|вложить)",
            "\\b(should\\s+i|what\\s+(should|to)\\s+i?\\s*)\\s*(buy|sell|invest)",
            "\\bwhat\\s+to\\s+(buy|sell)\\b"), FLAGS);

    public boolean isAdvice(String text) {
        return text != null && ADVICE.matcher(text).find();
    }

    public boolean asksForAdvice(String question) {
        return question != null && ASKS_ADVICE.matcher(question).find();
    }
}
