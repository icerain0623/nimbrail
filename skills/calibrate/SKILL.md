---
name: calibrate
description: Tune continuous UI values (spacing, color, radius, shadow, timing) with browser sliders instead of describing them in chat. Use on the second round of eyeball adjustment to the same element.
---

# calibrate

A continuous value is judged by eye in under a second and put into words badly, so every
round trip through chat spends a minute moving a number the user could already see. This
skill takes that one class out of the conversation. The browser gets sliders; what is
left here is the half sliders cannot do — lifting literals into tokens, and applying what
comes back.

Structure stays in the conversation. Layout, hierarchy, copy and component boundaries are
discrete decisions, and words are exact about those.

## When to offer it

The **second** round of continuous-value adjustment on the same element. A first round
often lands in one shot; the second is what proves the loop has formed. Offer once — if
the user passes, stay quiet for the rest of the session.

## 1. Tokens, or there is nothing to calibrate

The panel reads custom properties that resolve on `:root`. Grep the stylesheets for them.
Absent, the panel opens empty and the real job is extraction: collect the repeated
literals, name them, declare them once, replace the occurrences. Do that first — it is
worth more than the sliders, and it is the part a slider can never do.

## 2. Hand over the panel

`calibrator.js` sits beside this file. It is pasted once per browser profile into
DevTools → Sources → Snippets, and from then on it is one keystroke — so this step is a
sentence naming the snippet, and the full path with the setup only when the user has not
saved it yet.

Say to re-paste when `calibrator.js` has changed here since: the browser holds its own
copy and goes stale without a sign.

## 3. Apply what comes back

Copy CSS returns only the tokens the user moved. Edit the existing declarations in place,
in the file that already declares them — a second `:root` block overriding the first is
how the source stops matching the screen. Then ⟳ in the panel re-reads those values as
the new baseline.

## Rules

- Do not edit the same values in the repo while the panel is open. Its overrides are
  inline styles on the root element and outrank the stylesheet, so the screen would stop
  reflecting what was just written.
- Nothing the panel does is persisted. Until step 3 lands, the tuning exists only in the
  browser's localStorage.
- Offer, never insist. It costs the user a switch into DevTools, which only pays once the
  conversation has already missed the same value twice.
