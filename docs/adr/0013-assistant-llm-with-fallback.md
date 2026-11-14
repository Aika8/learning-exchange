# 0013. Assistant «Летописец»: LLM behind a port, rules-based fallback

- Status: Proposed
- Date: 2026-11-12
- Pattern(s): Port & Adapter, Fallback / Graceful degradation, Retrieval of facts before generation

## Context
After a session the player should see what happened in R-multiples, how much went to spread and fees, and compare to
buy-and-hold (vault `finance/must-know.md` #9–#15). An LLM explains well but costs money, needs a key and can make up numbers.

## Decision
- Port `Assistant` with `reviewSession(SessionFacts)` and `answer(question, SessionFacts)`.
- `SessionFacts` are computed deterministically from the journal (R per trade, expectancy, fees, spread paid, buy-and-hold benchmark,
  drawdown). The LLM only **narrates** these facts; it never computes numbers.
- Adapters: `ClaudeAssistant` (Anthropic API, model from config, key from env `ANTHROPIC_API_KEY`), `TemplateAssistant` (no key: fixed texts with numbers filled in).
- Persona per client: in-game «Летописец» (lore words), in-app «Помощник» (real words), same facts.
- Never gives investment advice; the system prompt says so and shows the disclaimer.

## Why this and not the alternatives
| Alternative | Why not |
|---|---|
| LLM computes the review from raw trades | Hallucinated numbers in a finance lesson |
| Only templates | Works, but dull and can't answer follow-up questions |

## Pros
- Works offline and in tests (template adapter); better with a key.
- Facts are unit-tested; text is the only fuzzy part.

## Risks and costs
- API cost — cache per session review, cheap model by default.
- Prompt injection via player-entered names/notes — facts are passed as data, not instructions.

## How to explain it
"Numbers come from code, words come from the model. If there's no API key the assistant degrades to templates."
