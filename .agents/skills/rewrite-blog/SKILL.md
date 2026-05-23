---
name: rewrite-blog
description: Rewrite a blog post draft into Matt's personal writing voice
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep
---

# Rewrite Blog Post

Rewrite a blog post draft from Claude's default style (or any generic style) into Matt's personal voice.

## Usage

`/rewrite-blog` — then paste the draft text or provide a file path
`/rewrite-blog path/to/draft.md`

## Input

Accept one of:
1. **A file path** passed as an argument — read the file
2. **Pasted text** in the user's message — use it directly
3. **Neither** — ask the user to paste a draft or provide a file path

## Rewriting Instructions

Rewrite the draft applying the style guide below. Preserve all technical accuracy, code samples, and factual claims from the original. The rewrite changes *voice and structure*, not *substance*.

Output the rewritten post directly in the conversation. If the user provided a file path, also offer to write the rewritten version to a file (e.g., the same path or a `-rewritten` variant).

---

## Matt's Voice — Style Guide

This guide was derived from analysis of Matt's writing across three platforms: a philosophy blog (b4yb.blogspot.com, ~2010), a LiveJournal (punk1290, 2002-2006), and Twitter (@punk1290, ~2019-2021). The target is the **mature Blogspot-era voice** adapted for technical content.

### Core Voice

- **Conversational-academic hybrid.** Explain complex topics like you're talking to smart friends at a bar. Never lecture.
- **Earnest enthusiasm without irony.** When something is cool, say so directly. ("I love this weird shit." / "So damn good." / "This is just art.")
- **Self-deprecating humor** as an entry point to serious topics. Use your own mistakes or frustrations as the hook.
- **Honest hedging.** After presenting a position, openly say where you're unsure or where it breaks down. ("I don't really know" / "probably" / "not necessarily" / "I don't 100% agree with")
- **Direct reader engagement.** Address the audience as peers: "you", "y'all". Never talk down.
- **Fragment punches.** Follow a flowing paragraph with a terse sentence for emphasis. ("Not acceptable." / "Holy shit." / "Really.")

### Sentence-Level Patterns

- **Short declarative fragments** for emphasis, mixed with longer exploratory sentences
- **Casual intensifiers:** "freaking", "damn", "really", "insanely", "so"
- **Transition words:** "So,", "Anyways,", "Basically,", "However"
- **Hedges:** "pretty much", "I don't really", "probably", "not necessarily"
- **Contractions always.** "don't", "can't", "wouldn't", "it's" — never the expanded form

### Structural Patterns for Tech Posts

Apply these patterns where they fit naturally. Not every post needs all of them.

1. **The Mundane Pivot** — Open with a relatable frustration, everyday scenario, or personal anecdote. Then swerve into the technical topic with "So," or "Anyways,". The reader should feel grounded before the technical content starts.

2. **The Question Cascade** — After introducing a concept, stack 3-5 questions that drill deeper. Each question should build on the previous one, pulling the reader into the problem space. Use these mid-post to re-engage, not as conclusions.

3. **The Honest Hedge** — Present a technical opinion or recommendation, then openly say where you're unsure or where it might not apply. This builds trust. ("This worked great for us. Whether it scales past 10k requests/sec? Honestly, no idea.")

4. **The Fragment Punch** — After a flowing technical explanation, drop a one-word or one-phrase sentence. Creates rhythm and emphasis.

5. **The Practical Landing** — End with a concrete takeaway, a specific recommendation, or "here's what I'd actually do." Land the plane. Don't trail off with open-ended philosophical questions.

6. **The Numbered Enumeration** — Use numbered lists for multi-step explanations. Matt consistently reaches for enumeration across all writing eras.

### Anti-Patterns — Things to Avoid

These are Claude-isms and generic blog patterns that are NOT Matt's voice:

- **No "Great question!" / "Absolutely!" / "That's a great point!" openers.** Just start.
- **No "Let's dive in" / "In conclusion" / "Furthermore" / "Moreover".** These are essay-speak, not conversation.
- **No trailing summaries.** The piece ends when it ends. Don't restate what you just said.
- **No hedge-stacking.** One hedge is honest. Three in a row is weaseling. ("It's worth noting that it might be important to consider..." — never.)
- **No corporate/marketing tone.** No "leverage", "utilize", "streamline", "cutting-edge", "game-changer".
- **No pretentious jargon without translation.** If you use a technical term, make sure the surrounding context makes it approachable.
- **No vague philosophical endings.** Land the plane with something actionable.
- **No emojis in long-form writing.** (Matt uses emojis on Twitter, not in blog posts.)
- **No over-explaining jokes.** If the humor doesn't land on its own, cut it.
- **No "I" avoidance.** Matt writes in first person freely. Don't dance around it with passive voice.
- **No dramatic reveal phrases.** ("That's when it hit me", "And then I realized", "It dawned on me") — just state the realization directly.
- **No em-dash interrupted lists for inline enumeration.** Use flowing clauses instead ("whether thats X or Y", not "— X, Y").
- **No over-polished punctuation.** Let sentences read like natural speech, not edited prose.

### AI Writing Tells to Avoid

These patterns are documented red flags for AI-generated text (sourced from [Wikipedia:Signs of AI writing](https://en.wikipedia.org/wiki/Wikipedia:Signs_of_AI_writing)). If you catch yourself using several of these, rewrite until they're gone.

**Vocabulary red flags.** These words are statistically overrepresented in LLM output. One in isolation is fine. Three or more in a paragraph means you're writing like a chatbot:

> Additionally, align with, boasts, bolstered, crucial, delve, emphasizing, enduring, enhance, fostering, garner, highlight (as verb), interplay, intricate/intricacies, key (adjective), landscape (abstract noun), meticulous/meticulously, pivotal, profound, renowned, showcase, tapestry (abstract noun), testament, underscore (as verb), valuable, vibrant, groundbreaking, diverse array, nestled, exemplifies, commitment to

**Copula avoidance.** LLMs replace "is" and "are" with fancier constructions. Say "X is Y", not "X serves as Y" or "X stands as Y" or "X represents Y" or "X marks Y." Just use "is."

**Significance puffery.** Don't remind the reader how important something is. No "marking a pivotal moment", "setting the stage for", "indelible mark on", "deeply rooted in." If it's important, the content will show that. You don't need to announce it.

**Dangling -ing analyses.** Don't tack present participles onto sentences to add fake depth: "highlighting its importance", "underscoring its significance", "reflecting broader trends", "contributing to the evolving landscape", "fostering innovation." Cut these. They say nothing.

**The "despite challenges" formula.** Never write "Despite its [positive thing], [subject] faces challenges including..." followed by vague optimism about the future. This is the single most recognizable AI paragraph shape.

**Mechanical rule of three.** LLMs love triplets: "adjective, adjective, and adjective" or "phrase, phrase, and phrase." One or two is natural. Three in a row with parallel structure is a tell, especially when the third item adds nothing the first two didn't cover.

**Elegant variation.** Don't cycle through synonyms to avoid repeating a word. If you're talking about a tool, call it "the tool" every time. Don't rotate through "the tool", "the platform", "the solution", "the system." Repetition is more natural than forced variety.

**"Not just X, but also Y."** LLMs use negative parallelisms to sound balanced: "It's not just about performance, it's about developer experience." Humans say this sometimes but LLMs do it constantly. Use sparingly if at all.

**Vague attributions.** Don't write "Experts argue", "Industry reports suggest", "Observers have noted." Either name the source or state it as your own opinion.

**Self-check.** After drafting the rewrite, scan it once for the vocabulary red flags and structural tells above. If you find clusters of them, revise those paragraphs until they read like a person wrote them.

### Example Transformations

**Claude default:**
> Observability is a critical aspect of modern software systems. It enables teams to understand the internal state of their applications through external outputs. Let's explore three key pillars of observability and how they work together to provide comprehensive system insights.

**Matt's voice:**
> So I spent three hours last Tuesday staring at a dashboard that told me absolutely nothing useful. The service was slow, the users were mad, and I had seventeen metrics that all said "looks fine to me." I had monitoring, but I didn't have observability. There's a difference, and it matters more than most people think.

**Claude default:**
> In conclusion, adopting a microservices architecture requires careful consideration of the trade-offs involved. While it offers benefits in terms of scalability and team autonomy, it introduces significant complexity in areas such as service discovery, data consistency, and operational overhead.

**Matt's voice:**
> Here's what I'd actually tell someone thinking about microservices: start with a monolith. Seriously. Pull services out when you have a real reason whether thats a team that needs to deploy independently or a component that needs to scale differently. Not because a blog post told you to. The complexity cost is real, and you'll feel it in every on-call rotation.
