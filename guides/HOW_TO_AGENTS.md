# How to Craft the Ideal AGENTS.md - Distilled
> https://www.youtube.com/watch?v=8gotGDhQKeQ&t=2s

## Core Principle: Just Enough, Not More

**agents.md is ALWAYS allocated in slot 1 of your context window.** Every token counts against you.

## The Rule: ~70 Lines Max

**Why?** More = less room for actual work = more time in "dumb zone" = context rot.

## What to Include (and ONLY This):

1. **How to run tests** - `make test` or equivalent
2. **How to build** - build commands
3. **Basic layout** - minimal project structure
4. **Critical quirks** - only stuff that repeatedly fails

## The Anti-Pattern: Being Hyper-Specific

**Bad:**
```
To check the server status:
1. Run: sudo systemctl status nginx
2. If that fails, try: journalctl -u nginx -n 50
3. Then check: ps aux | grep nginx
```

**Good:**
```
Check web server: use journalctl to diagnose
```

**Why good wins:** You're "tickling the latent space" - the model KNOWS systemctl, KNOWS nginx, KNOWS the relationship. Don't over-specify. Let it work.

## The Guitar Tuning Metaphor

**When you see bash tool failing repeatedly on the same command** → that's your signal to tune agents.md

**When you see the agent searching/discovering ("cache misses")** → add a minimal prompt to guide it

**Example from Geoff:**
- Said: "use journalctl to diagnose"
- Didn't say: systemctl
- Model went straight to `sudo systemctl status` → cache hit

## Model-Specific Problem

**GPT-4o5:** Hates firm language (uppercase, "BE THOROUGH"). Gets timid.
**Claude:** Responds well to firm language.

**One agents.md can't serve all models** - this is a real problem with standardization.

## Maintenance: The Harvester Approach

**Problem:** Teams keep adding to agents.md, it grows with "forgotten knowledge"

**Solution:** 
- Delete it completely
- Regenerate from first principles
- Don't be afraid to "mow it down"
- Can always recreate via prompts

## Signs You Need to Clean It:

1. Tool failures happening repeatedly
2. Agent seems confused/slow
3. You're hitting context limits
4. File is >70 lines
5. Stuff in there you don't remember adding

## Advanced: Skills/Lazy Loading

For things you reference OFTEN but don't need ALWAYS allocated:
- Put in separate markdown files
- Load lazily when needed
- Example: deployment info, server architecture

## The Test: Can Ralph Loop?

**If Ralph fails because bash tool keeps failing** → agents.md needs updating

**If Ralph runs smoothly in loops** → you've tuned it right

## The Mindset Shift

**Stop treating LLMs like GPT-3.** They're not dumb. They have vast latent knowledge.

Your job: **minimal cues** to trigger the right behaviors, not exhaustive instructions.

Think: **cache hits vs cache misses**
- Agent going straight to the right command = cache hit = good tuning
- Agent searching/trying multiple things = cache miss = needs tuning

---

## TL;DR - The Glanceable Version:

1. **~70 lines max** (it's always allocated)
2. **Include:** test commands, build commands, basic layout
3. **Don't:** Over-specify, write tutorials, explain everything
4. **Do:** Minimal prompts that "tickle latent space"
5. **Watch:** Repeated bash failures = needs tuning
6. **Maintain:** Delete and regenerate regularly
7. **Remember:** Less is more. Respect the latent space.

**The goal:** Just enough for Ralph to loop without intervention.