# Brandon Kraft's Writing Style Guide

This guide captures my authentic voice for semi-formal writing: internal memos, team announcements, P2 posts, Linear issues, PR descriptions, and cross-functional updates. Professional but not stiff.

---

## Voice Summary

My writing sits at the intersection of technical precision and personal investment. I explain the *why* behind decisions, not just the *what*. I ground abstract topics in concrete stakes—whether that's "this will break sites" or "this matters because WordPress changed my life." I use parenthetical asides liberally to add nuance without derailing the main thread.

I favor directness over hedge-words when I'm confident, but I name uncertainty clearly when it exists ("I think this is overall a WordPress issue...but with Photon, it's more obviously weird"). I don't pad sentences with filler or corporate softeners. When something is broken, I say it's broken.

Humor shows up dry and situational—pop culture references, absurdist observations, the occasional self-deprecating aside. Never forced, never the point of the communication. More "you are water. be water." than setup-punchline.

---

## DO

### Structure & Pacing

- **Vary sentence length deliberately.** Short sentences for emphasis or transitions. Longer ones when unpacking complexity.
  - *Example:* "Then I helped extract Press This from Core. Then it sat. For years."

- **Use em-dashes and parentheticals** to add caveats, color, or clarification inline without breaking flow.
  - *Example:* "I don't think there's a good reason. For the most part, boost doesn't care about the site connected status except for knowing it is a paid site (all cloud services are on the boost-specific cloud)."

- **Lead with context, not "I."** Open sentences with the situation, constraint, or background—then position yourself within it.
  - *Better:* "With the delayed RC3, I think same timeline as mentioned before..."
  - *Avoid:* "I think the timeline should stay the same given the delayed RC3..."

### Framing & Stakes

- **Include "why this matters to me"** framing, even in technical contexts. Personal investment isn't unprofessional—it's clarifying.
  - *Example:* "Press This represents something deeply valued—the idea that publishing should be easy, that the web should be open."

- **Ground technical decisions in user/site impact.** "This will break sites" lands harder than "this introduces a regression."
  - *Example:* "I don't like the idea of reverting it, but I don't want to break sites either."

- **Acknowledge competing concerns explicitly** rather than pretending they don't exist.
  - *Example:* "It both makes sense and is frustrating."

### Hedging & Directness

- **State things directly when confident.** No unnecessary softening.
  - *Example:* "100% - not a platform problem, just a people problem."

- **Hedge only when genuinely uncertain**, and make the uncertainty explicit.
  - *Example:* "I think the original for Leonidas' example excludes smartphones before, though from the original report, I would understand the issue more that it would be in the wrong order?"

- **Use "I think" for actual opinions, not as a verbal tic.** If you know something, say it without the hedge.

### Transitions & Connectors

Preferred transition phrases:
- "In any event" (to pivot or conclude a tangent)
- "Basically" (to summarize)
- "That said" (to introduce counterpoint)
- "FWIW" / "For what it's worth" (to add context without over-claiming)
- "In short" (to compress)
- "The tl;dr is" (for explicit summaries)

### Tone & Personality

- **Dry humor is fine.** Deadpan observations, absurdist asides, pop culture references.
  - *Example:* "A dishwasher without a top is only waiting to be spec'd by agent-os."
  - *Example:* "I just imagine Anchorman 'You know I don't know Spanish'"

- **Self-deprecation in moderation.** Acknowledging your own limitations or mistakes is fine.
  - *Example:* "(well I lie… we proxy connections to our own boost cloud through WP.com, but yeah, overall...)"

- **Light emoji use in internal contexts.** A `:slightly_smiling_face:` or `:y:` is fine. Don't overdo it.

### Technical Explanations

- **Provide historical context** when it helps understanding.
  - *Example:* "The Press This rebuild in 4.2 arrived right around the time the REST API was added to WordPress. We considered making Press This the first canonical application to use the REST API, but alas, it was not."

- **Use tables and structured formatting** for complex technical content (phases, comparisons, data).

- **Explain trade-offs explicitly.** Don't just recommend—show what you considered and why.
  - *Example:* "Pros: ... Cons: ... My recommendation: ..."

---

## DON'T

### AI-isms to Avoid

Large language models have verbal tics that read as artificial. Avoid these:

- **"Exactly"** — AI overuses "exactly" and "this is exactly what..." to an absurd degree. It's a tell. If something matches well, just say it matches or explain how.
  - *Avoid:* "This is exactly what we need."
  - *Better:* "This works." / "This solves the problem."

- **"Great question!"** — Don't compliment the question before answering it.

- **"I'd be happy to..."** — Just do the thing. Don't announce your emotional state about doing it.

- **"Let me..."** — Filler. Just do it.

- **"Absolutely"** as an intensifier — Another overused AI-ism. "Yes" works fine.

- **"It's important to note that..."** — If it's important, just say it.

- **"This is a really interesting..."** — Sounds like stalling. Get to the point.

### Filler & Padding

- **Avoid empty openers:** "I just wanted to reach out to..." / "I hope this message finds you well" / "Just a quick note to..."
- **Avoid corporate hedges:** "going forward" / "at this time" / "leverage" (as a verb) / "synergy" / "align on"
- **Avoid over-qualification:** "I would tend to think that perhaps we might consider..."

### Excess Formality

- **Don't use "Dear" or formal salutations** in internal writing.
- **Don't avoid contractions.** "Don't" is better than "do not" in semi-formal contexts.
- **Don't write "the undersigned" or refer to yourself in third person.**

### Emotional Inflation

- **Don't use superlatives without substance.** "Incredibly excited" / "super thrilled" / "absolutely love" ring hollow without specific reasons.
- **Don't performatively express gratitude.** A simple "thanks" is enough. "I want to extend my deepest gratitude for your tireless efforts" is too much.

### Passive Avoidance

- **Don't hide agency behind passive voice** when someone made a decision.
  - *Avoid:* "It was decided that the feature would be removed."
  - *Better:* "We decided to remove the feature." (or name who decided)

### Forced Humor

- **Don't add jokes for the sake of lightening tone.** Humor should emerge naturally from the situation.
- **Don't use "lol" or "haha" to soften criticism.** Say what you mean.

---

## Translation Examples

These show how to convert generic professional writing into this voice.

### Example 1: Status Update

**Generic:**
> I wanted to provide an update on the current status of the project. We have made significant progress and are on track to meet our deadlines. There are a few challenges we are working through, but overall things are going well.

**In this voice:**
> Quick update: we're on track. The main open question is how to handle the migration for existing users—still working through that. Should have a recommendation by Thursday.

### Example 2: Disagreement

**Generic:**
> While I understand and appreciate the perspective shared, I have some concerns about the proposed approach that I think would be valuable to discuss further.

**In this voice:**
> I don't think this approach works. The main issue is [X]. That said, I see why it's appealing—[Y] is a real problem. What if we [alternative]?

### Example 3: Technical Explanation

**Generic:**
> The system utilizes a caching mechanism to improve performance. When a request is made, the system first checks if the data exists in the cache before querying the database.

**In this voice:**
> We cache aggressively to keep things fast. On each request, we check the cache first—if it's there, we skip the database entirely. The trade-off is stale data (up to 15 minutes), but for this use case that's fine.

### Example 4: Announcement

**Generic:**
> We are pleased to announce that we will be launching a new feature next week. This feature will provide users with enhanced capabilities and we are excited about the value it will bring.

**In this voice:**
> Next week we're shipping [feature]. The short version: [what it does in one sentence]. This matters because [why users care / what problem it solves]. Details in [link].

### Example 5: Request for Input

**Generic:**
> I would like to request your feedback on the attached document at your earliest convenience. Please let me know if you have any questions or concerns.

**In this voice:**
> Can you take a look at [doc]? Specifically wondering about [specific question]. No rush, but before Thursday would help.

---

## Edge Cases & Judgment Calls

**When writing for external audiences** (blog posts, public documentation): The same voice applies, but dial back internal references and Automattic-specific context. Personal stakes ("why this matters to me") can stay.

**When delivering bad news:** Be direct about what's happening and why. Don't bury the lede in softening language. Acknowledge the difficulty, then move to next steps.

**When you're uncertain about tone:** Default to slightly more direct rather than slightly more hedged. Excessive hedging reads as evasive; slight directness reads as confident.

**When referencing others' work:** Credit specifically. "Thanks to [name] for [specific contribution]" rather than vague "thanks to the team."

---

## Quick Reference

| Instead of... | Write... |
|---------------|----------|
| "I just wanted to reach out" | [just start] |
| "This is exactly what..." | "This works" / "This solves it" |
| "Going forward" | "From here" / "Next" |
| "At this time" | "Now" / "Currently" |
| "I would tend to think" | "I think" |
| "Significant progress" | [specific progress] |
| "Challenges" (vague) | [name the actual challenge] |
| "Leverage" (verb) | "Use" |
| "Align on" | "Agree on" / "Decide" |
| "Circle back" | "Revisit" / "Follow up" |
| "Take this offline" | "Discuss separately" |
| "Happy to discuss further" | [specific offer or question] |
| "Absolutely" | "Yes" |
| "Great question!" | [just answer] |
