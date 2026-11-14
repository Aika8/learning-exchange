# Prompt for Gemini: mobile app design «Ветрило»

> Where to run: **Google Stitch** (stitch.withgoogle.com — Gemini-based UI designer, exports to Figma and code) is the best fit;
> the Gemini app works too for the design system part.
> Send it in two steps: Part 1 (design system), then Part 2 (screens) in the same project.
> Save the results to `docs/design/`: `tokens.json`, screenshots/PNGs per screen in `docs/design/screens/`, Figma link in `docs/design/README.md`.

---

## Part 1 — Design system

You are a senior product designer for fintech mobile apps. Design the visual system for **«Ветрило»** (Vetrilo) — a learning
super-app: bank + currency exchange + brokerage + deposits, for people who are new to investing. It is the "real world"
face of a game world about sky islands and trade winds, so it can carry a light hint of wind, sky and sails —
but it must look like a trustworthy modern bank first, not like a game.

Audience: 20–40, Kazakhstan/CIS. **Two languages from day one: Russian and English, switchable in settings** —
design every screen so both fit (Russian is ~20–30% longer); show at least screens 1–4 in both languages.
All finance terms are the real ones (стакан, спред, стоп-лосс, лимитная заявка), never invented words.
Platform: iOS and Android (React Native), phones 360–430 pt wide.

Hard rules:
- Original brand. Do **not** imitate the colours, logos or layouts of any existing bank or app (no Kaspi red, no BCC look, no Revolut clone).
- Accessibility: WCAG AA contrast, minimum touch target 44 pt, numbers in tabular figures.
- Light and dark themes, both first-class.
- Money is serious: gains/losses must not rely on red/green alone (add sign and arrow); no casino vibes, no confetti for trades,
  no urgency timers.

Deliver:
1. Brand: name lockup «Ветрило» / Vetrilo (ветрило = old Russian word for «sail»), small symbol idea (wind/sail motif), tone of voice in 3 sentences.
2. **Design tokens as JSON** in this exact shape (values are examples):
```json
{
  "color": {
    "light": { "bg": "#…", "surface": "#…", "surfaceAlt": "#…", "textPrimary": "#…", "textSecondary": "#…",
               "primary": "#…", "onPrimary": "#…", "accent": "#…", "positive": "#…", "negative": "#…",
               "warning": "#…", "info": "#…", "border": "#…", "bid": "#…", "ask": "#…", "spread": "#…" },
    "dark":  { "…": "same keys" }
  },
  "typography": { "fontFamily": { "text": "…", "numeric": "…" },
                  "scale": { "display": {"size": 34, "lineHeight": 40, "weight": 700}, "title": {}, "headline": {}, "body": {}, "caption": {}, "numericLarge": {} } },
  "spacing": [0, 4, 8, 12, 16, 20, 24, 32, 40],
  "radius": { "sm": 8, "md": 12, "lg": 20, "pill": 999 },
  "elevation": { "card": "…", "sheet": "…" },
  "motion": { "fast": 120, "normal": 220, "easing": "…" }
}
```
   Use free fonts available on Google Fonts with full Cyrillic support.
3. Core components with states (default / pressed / disabled / loading / error): button (primary, secondary, ghost), text field
   with amount input, segmented control, list row (operation), balance card, tab bar (5 tabs), bottom sheet, chip, toast, empty state,
   **order book row** (bid/ask with depth bar), **spread indicator**, **"glossary" chip** (shows a term's game-world name on tap).

## Part 2 — Screens

Using the design system above, design these screens (light and dark for 1–4, light only for the rest):

1. **Home** — total balance in ₸-like base currency (call it «искра», symbol ✦, displayed as "₸-style" amount), accounts list
   (current, FX, brokerage, deposit), quick actions (Перевести, Обменять, Купить, Вклад), recent operations with fees visible.
2. **Exchange (обменник)** — pair АМБЕР/ИСКРА, two prices "Покупка / Продажа" with the **spread shown explicitly** in currency and %,
   amount input, "you get / you pay / fee" breakdown, small 1D/1W/1M chart, "Купить, когда курс составит…" (limit order, valid up to 5 days).
3. **Instrument (брокер)** — price and change, chart, **order book (стакан)** 10 levels each side with depth bars and the spread in the middle,
   trades tape, buttons Купить / Продать.
4. **Order ticket (bottom sheet)** — limit/market switch, price, quantity, **mandatory stop-loss field**, optional take-profit
   (fixed or trailing), **risk panel**: "Риск на сделку: 1% капитала = 10 000 ✦", suggested quantity from the stop,
   R:R ratio, fee estimate, warning when risk > 2%. Confirmation step.
5. **Orders & stops** — active orders and conditional orders with a clear lifecycle: Ждёт → Сработал → Отправлена → Исполнена / Не исполнена
   (explain "сработал ≠ исполнена" with an info icon).
6. **Leverage position** — ×4 position card with collateral, P&L, distance to stop-out (50% of collateral) as a progress bar.
7. **Deposit** — open a deposit, rate, term, compound interest projection chart, "Правило 72: удвоение за ~N лет" hint,
   note that this deposit is insured but the brokerage/metal account is not.
8. **Statement (выписка)** — period filter, each operation with fee, spread paid, and a year summary with **10% income tax** estimate.
9. **Assistant «Помощник»** — chat screen with a session review card: "Сделок 7 · Итог +1.4R · Пошлины и спред −2 300 ✦ ·
   Просто держать индекс: +0.8%"; disclaimer "Это не инвестиционный совет".
10. **Glossary «Словарь мира»** — list of real terms with a short definition; when the setting is on, also the game-world name in smaller muted text
    (Стоп-лосс · Якорь, Спред · Пропасть, Стакан · Лестница…). Settings screen with **language switch RU / EN** and the «Словарь мира» toggle.
11. **Onboarding (3 screens)** — what the app is (learning, no real money), the one rule ("выход до входа" — stop before entry), choose dev profile.
12. **Real world (Реальный мир)** — real USD/KZT (and other KZT pairs) with **source and timestamp** ("Нацбанк РК, курс на 12.11.2026"),
    "delayed" badge, chart, and a "paper position" (учебная позиция) button clearly different from real trading.
13. **Company card (Компания)** — key metrics (выручка и рост, чистая прибыль, EPS, P/E, долг / прибыль, дивидендная доходность),
    **last report vs expectations** shown as "факт / ожидание / сюрприз %" for each line, the price reaction on the report day,
    earnings calendar ("Отчёт через 3 дня, после закрытия торгов"), and a warning banner when the user has a stop on this stock
    before a report ("Отчёт ночью: утром возможен гэп, стоп может не исполниться"), insider trades list ("Директор купил 2 000 акций, 3 дня назад"),
    dividend ex-date marked on the chart ("Отсечка: цена снизится на размер дивиденда"). No buy/sell recommendations.
14. **Economic calendar (Календарь событий)** — list by day: central bank rate decisions (with current rate, consensus, result), inflation,
    company reports, dividend ex-dates; importance level; filter "только по моим бумагам"; banner "У вас 2 позиции со стопом перед решением по ставке".
15. **Bond (Облигация)** — issuer, credit rating badge, coupon, maturity, price, **yield to maturity (main number)**, duration with a one-line
    explanation ("если ставки вырастут на 1 п.п., цена упадёт примерно на N%"), coupon schedule.
16. **Fund card (Фонд)** — what's inside, **expense ratio (TER) prominently**, a "20 лет при 0,1% vs 2%" comparison chart, rebalancing reminder setting.
17. **Order ticket additions** — stop mode "от волатильности: 2 × ATR" next to the manual stop; journal fields "Почему вхожу" (required), "Состояние рынка", "Настроение".

Tab bar: Главная · Платежи · Обмен · Инвестиции · Ещё.

For every screen give: the layout, component names from Part 1, and copy in Russian and English. Keep copy short and plain.
Export: Figma (preferred) + PNG per screen + the tokens JSON as a separate block I can copy.
