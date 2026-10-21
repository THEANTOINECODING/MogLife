# MogLife minigame tester review — 21 October 2026

Verdict: the Strength Playground has genuinely different interactions and a sound server-owned rules foundation. It is not yet consistently challenging, fair across controls, or rewarding to master. Fix bypasses, objective clarity, input fairness and progression feedback before adding games or tightening timers.

This is an audit, not an approved redesign. Recommendations below are proposals; no gameplay or design configuration was changed.

## Scope and evidence

- Read CLAUDE.md, the vision and current D76/D77 Playground specification. Reviewed all 21 currently configured games: six training games, eight jobs, five available bosses, Read & Rip, and the locked future Gravity Gauntlet boss.
- Connected to the MogLife Studio instance, place 103855142580510. Its Playground configuration reports version 3 and the current roster. The existing Rojo server responds on localhost:34872 as MogLife, Rojo 7.7.1. A new Rojo connection was unnecessary; no source edits were pushed.
- There are 61 modules in `src/client/Minigames`; 40 are older implementations outside the current roster. Findings below concern current configured gameplay, not every dormant historical implementation.
- Executed `tests/playground.luau` against Studio's actual shared modules: all 20 single-player games passed three scripted solutions, idle failure, valid draw-node checks and post-completion immutability. Boss autoplay restrictions passed. Read & Rip uses a separate server simulation and is excluded from that suite.
- Entered Studio Play mode and constructed/destroyed all 21 current client interfaces with local-only states. All mounted successfully. This is a UI smoke test, not 21 human playthroughs.
- Ran targeted rule simulations reproducing stationary Brayan victories, no-aim Atlas victories, Rope Rave's all-Good failure, Coach's stale commitment, and time-scaled payouts.
- Measured and visually inspected an Airway Express preview inside a 390×844 GUI container. This is a layout probe, not physical-phone emulation or a full activity screen test.
- Console contained Roblox FoundationProvider warnings and asset-type failures for `rbxassetid://203785492`; attribution to a specific minigame was not established. No minigame mounting exception occurred.
- Removed temporary preview objects and stopped Play mode. No reward remotes, profile edits, unlocks or currency changes were used for testing. Ordinary game startup still loaded the existing profile.

## Fix first

### P1 — Brayan can be beaten without dodging

`src/shared/Playground/Bosses.luau:50`

Sunbed Slalom puts cones at x=0.23, 0.50 and 0.77, but the collision threshold is only 0.12 from each lane center. Parking at x=0.365 is outside both adjacent collision zones.

**Studio reproduction:** move once to x=0.365 and send no further input. All six tested seeds won in 18.033 seconds, with zero misses. The default centered idle test misses this exploit.

Fix collision geometry to match the visible lounger and cones, or deliberately constrain movement to lanes. Verify that every stationary position eventually encounters a hazard, while keeping at least one reachable safe route. Do not simply make random unavoidable obstacles.

### P1 — Atlas Stack removes its own aiming challenge

`src/shared/Playground/Training.luau:288`

The cursor starts at x=0.5, the platform is centered, all pieces become narrower, and there is no drift. Staying at the initial x and repeatedly pressing/releasing guarantees centered drops.

**Studio reproduction:** no horizontal movement; repeated down/up at x=0.5. Won in 5 seconds, score 5/5, zero misses.

For a late unlock, this is weaker than the first training game. Introduce a clearly readable moving piece or varying landing position, preserving generous first drops and a meaningful precision bonus. Add an anti-degenerate test for winning with the untouched cursor.

### P1 — Coach retains a valid charge after a failed attempt

`src/shared/Playground/Bosses.luau:94`

`s.committed` is cleared when Coach exits left but not when he passes the player on the right. Commitment from a failed charge can carry into the next attempt.

**Studio reproduction:** reverse after the commit mark, reverse again after cooldown, allow the right-side failure, then reverse early on the next attempt. Commitment remained true at coach x=0.156; the early reversal earned a point with one miss recorded.

Reset commitment on every attempt reset. Regression-test both left and right failures.

### P1 — Rope Rave says Good but can still fail the whole objective

`src/shared/Playground/Training.luau:239`

Each Good hit scores 0.7, while victory needs 13.5 from 15 beats. Fifteen Goods give only 10.5. With every beat hit, at least ten Perfects are required to win; the hint never communicates that requirement.

**Studio reproduction:** hit all 15 notes about 0.11 seconds late, inside the Good window. Zero misses, score 10.5, final quality Good, but `won=false` at the 26-second timeout.

Separate completing the phrase from its accuracy grade. Make all valid hits sufficient for a basic completion, reserving perfection for medals/rewards. Also resolve after the phrase when no scoring opportunities remain; the final configured beat is at 17.16 seconds, leaving almost nine seconds of empty timeout for a non-winning run.

### P1 — Mobile and keyboard do not have equivalent tasks

`src/client/PlaygroundClient.luau:113`, `:137`, `:219`

At a 390-pixel portrait width the square stage measures 233 pixels. A six-column board has approximately 29.5 pixels between cell centers. Precision drag routes and territory loops therefore ask for small finger movements while a large portion of the width remains reserved for the world.

Pointer coordinates jump directly to their requested location; keyboard/stick coordinates advance at 0.8 normalized units/second. Individual games cap some object movement, but cuts, folds, pipe selection and grid tracing do not share that protection. Mouse/touch can complete endpoint gestures far faster than a keyboard cursor. Timed loop closure makes this a fairness issue, not just a preference.

Use more portrait width for the interaction, offer game-specific discrete navigation for grids, and balance against actual completion times by device. Do not globally slow the pointer: it could damage the satisfying feel of direct manipulation.

Pending inputs are also replayed at the snapshot time without original timestamps. This is a code-level latency risk for rhythm and hold duration, not a reproduced network failure. Test latency and jitter before claiming equivalent timing fairness.

## Shared progression and feedback problems

1. **Combo bonuses are unreachable in active single-player runs.** `MinigameService.luau:129` forces one result per run and initializes streak to zero; `Balance.luau:100` begins bonuses at five successes. A run can only reach streak one. Helper Perfect chains also start fresh and receive one result. Connect streaks to meaningful validated sub-actions or deliberately replace the obsolete system. Do not advertise bonuses that cannot happen.
2. **Completion percentage is presented as accuracy.** `Playground.Score` uses only score/goal. In retryable tasks such as Scrap Press and Chop Shop, a player can miss, retry, eventually hit all perfect targets, and still display 100%. Quality separately notices misses. Label completion and precision separately, and use errors/time for mastery records where appropriate.
3. **Training rewards increase when the player waits to finish.** `MinigameService.luau:406` scales reward by elapsed game time; `ExerciseService.luau:77` applies it. A scripted Scrap Press solution scored 94/Perfect both times: fast finish 6.967s, scale 0.268; deliberately delayed finish 24.4s, scale 0.938. That is about 3.5× the per-run payout for the same work. This is time-normalized income, not an unlimited currency exploit, but it discourages fast completion and amortizes restart overhead in favor of waiting. Preserve economy targets while adding an explicit reason to finish efficiently.
4. **Feedback does not explain why an attempt failed.** `PlaygroundClient.luau:263` emits Good or Miss on any pulse. Picking up an item or reversing a belt can trigger Good without scoring. Perfect sub-actions get the same cue as ordinary progress. Distinguish action acknowledgement, success, near miss, completion and precision. Give reasons such as Too early, Need a longer chain, or Close the loop before the stomp.
5. **Important budgets are hidden.** Shared status shows time and percentage, not remaining shots, pipe turns, car moves, lives or trail length. These constraints should be visible before the player loses. A one-line hint is not enough to teach an unfamiliar puzzle under a running timer.
6. **Job Continue targets the previous exercise.** `MinigameController.luau:666` always sends `StartSeries(lastExerciseId)` from the shared result screen. After a job it can attempt an unrelated exercise, or simply close if none was selected. Make the result action context-aware; respect job cooldowns.
7. **Partial job payouts and cooldowns disagree.** `HelpService.luau:76` can pay accrued Good credit when an objective was not won, while the cooldown is set only for completed objectives. This is a code-confirmed consistency gap; its farming value was not measured. Decide explicitly whether partial work pays, and apply the corresponding cooldown rule.
8. **Most layouts have little meaningful variation.** Parking, routes, folds, scrap targets, tire towers and swing geometry are fixed. Produce changes colors without changing its chain structure; pipes have only three seed-dependent rotations of a fixed topology. Random seeds alone do not create replay depth.

## Review of every current game

The observations below are code-reviewed design judgments unless explicitly reproduced above. Proposed mechanics are suggestions, not claims that the current game is broken.

| Game / role | What currently limits it | Improvement that fits MogLife |
|---|---|---|
| **Scrap Press — training** | Good introductory hold/release, but four fixed targets and no rebound become a memorized routine. Waiting improves the per-run payout. | Preserve the simple first lesson; vary recognizable scrap materials and target profiles. Make crushed cubes and precision feel visibly different. |
| **Tire Domino — training** | Fixed three-column board, three shots, deterministic toppling. Once learned, it is a repeated three-shot solution. | Add a small set of solvable arrangements, readable bank shots and distinct chain reactions. Display shots remaining and reward efficient clears. |
| **Magnet Haul — training** | One of the better risk/reward foundations: load slows the magnet and collision spills plates. Fixed plate/bumper placement encourages one memorized route. | Keep the load-versus-safety decision; vary pickup clusters and show the load/slowdown clearly. Make spilled plates visibly drop rather than silently reappear at their initial positions. |
| **Swing King — training** | The same launch and target are repeated four times; the athlete returns to the first bar after every catch. Success does not feel like travelling. | Advance the camera/course on each catch; vary the next gap within readable limits. Keep the trajectory preview for learning. |
| **Rope Rave — training** | All-Good failure and dead time after the phrase; one fixed rhythm pattern. The visual rhythm is stronger than the generic success sounds. | Separate completion and precision, end with the phrase, and build a small library of readable rhythms with synchronized audio/visual beats. |
| **Atlas Stack — training** | Reproduced no-aim perfect clear; late-game placement does not match its difficulty. | Require active alignment with controlled movement, and celebrate an increasingly absurd tower. |
| **Peel Good — job** | Pleasant first-job gesture, but always the same three-segment path. Moving directly to a segment endpoint and waiting also progresses the peel. | Keep it forgiving for onboarding; improve visible tension/progress, then offer different seal shapes. Avoid making the tutorial's first Cash frustrating. |
| **Airway Express — job** | A real logic puzzle, but fixed topology, only three starting rotation patterns, hidden turn budget and no preview of where air currently reaches. | Use a curated set of guaranteed-solvable boards, show flow and turns left, and offer an undo that has a clear move-cost rule. |
| **Chop Shop — job** | Only the line between press and release endpoints matters, not the drawn cut. Five fixed target x positions offer little replay depth. | Either clearly present a straight-line aiming task, or actually validate tracing. Vary plank shapes/required cuts without demanding tiny touch precision. |
| **Parking Knot — job** | A fixed four-car puzzle has a reusable four-move solution. Hidden move allowance adds confusion more than depth. | Supply a graded puzzle collection, show moves, allow readable undo/reset, and celebrate the freed car moving into the world. |
| **Piano Polish — job** | Wiping all 36 patches is mainly a chore. No meaningful choice or error exists once understood; the final tiny dirty area can dominate the finish. | Make the piano reveal satisfying, highlight remaining grime and vary dirt patterns. Keep it as a relaxing contrast rather than forcing every job into a harsh skill test. |
| **Towel Fold — job** | Three fixed endpoint drags; little connection between the drag and believable cloth folding. | Animate the fold throughout the gesture, provide a clear alignment ghost, and vary simple fold patterns. Judge alignment, not pointer travel speed. |
| **Produce Parade — job** | Fixed snake-shaped groups, recolored by seed. No refill/cascade; each intended match is essentially predetermined. Fruit identity relies heavily on color. | Create solvable boards with multiple chain choices and recognizably different fruit shapes. Let longer chains produce an obvious packing payoff. |
| **Shortcut Chalk — job** | One fixed maze and destination; mastery becomes memorizing the route. The tourist walk adds waiting after solving. | Rotate curated maps with a clear shortest-path challenge; allow a quick finish animation. Distinguish route correctness from efficiency. |
| **Snack Volley — Kevin** | Good first-boss reflex concept, but return angles do not meaningfully attack a moving opponent: reaching the upper line scores. Lives are not clearly displayed. | Keep Kevin forgiving; make his reaction and popcorn return readable, show lives and count seven returns. Later rounds can vary serves with advance warning. |
| **Sunbed Slalom — Brayan** | Reproduced stationary safe corridor defeats the dodging premise. | Fix geometry first; then create readable obstacle sequences that require deliberate changes of position. |
| **Treadmill Takeover — Coach** | Reproduced stale commitment; otherwise a promising momentum/timing interaction. Success feedback does not explain the commit threshold versus braking distance. | Reset attempt state, teach one safe reversal, and make momentum and danger readable before increasing speed. |
| **Leg Day Landgrab — No-Legs** | Strong potential for risk/reward, but the eight-cell trail cap is hidden and stops extension without explaining why. Four-second stomps plus tiny cells favor fast pointer input. | Show trail budget and stomp countdown, teach a small valid loop, support fair grid controls, and vary stomp pressure only after the rule is understood. |
| **Crown Sneak — BlockKing** | Freezing anywhere prevents detection, so cover is mostly optional; the spotlight repeats on a fixed schedule. This is a fairly simple late boss. | Decide whether this is red-light/green-light or a cover game and teach that rule consistently. Add clearly telegraphed variation across rounds, not surprise punishment. |
| **Read & Rip — duel** | Good push/recover foundation. Exhaustion state is sent by the server but not used for an explicit client cue; both fighters share very simple silhouettes. Identical strategies can stay symmetrical. | Clearly show pushing, bracing, exhaustion and recovery; make the opponent's vulnerable moment legible. Test actual two-player strategy diversity and ties before adding another input. |
| **Gravity Gauntlet — future boss, locked** | Alternating top/bottom seals, clamped boundaries and no additional hazards make a future finale less rich than its theme suggests. | Keep locked until it has a staged, readable finale that uses the gravity skill in several ways. Preserve the unresolved final-boss design decision for the creator. |

## Fit with MogLife and replayability

The variety is a strength: compression, aiming, hauling, launching, rhythm, stacking, tracing, puzzles and territory capture are distinct. Do not flatten them into another timing-bar system.

The missing connection is between the interaction, the absurd strength fantasy and the player's growing body. A clear press animation, a flying tire, a ridiculous caught weight or a reacting boss should make success feel like something the avatar did. The shared diorama system supports this, but generic athlete/rival figures and repeated geometry weaken character identity. Match station prompts and names to what the player actually sees; saved exercise IDs can stay compatible.

For sustainable replay, aim for: understand the rule quickly, make a meaningful action, see an understandable consequence, earn a visible improvement, and want another attempt. Current fixed puzzles and completion-only records often stop that loop after the first solution. Conversely, hidden limits and inconsistent grades make failure feel arbitrary.

Recommended order:

1. Fix the reproduced bypasses and reset bug; make Rope Rave's completion rule coherent.
2. Show goals, resources and failure reasons; correct job Continue and reward/cooldown semantics.
3. Restore a reachable mastery/streak loop, with completion and precision scored separately.
4. Validate mobile, keyboard and controller fairness before tuning difficulty upward.
5. Add a small, tested variant library to the most repetitive games and stronger activity/boss-specific payoff animations.

## Next playtest gate

Run new-player and repeat-player sessions on real phone portrait/landscape, keyboard-only, mouse and controller. Capture time to first understood action, completion/precision, early quits, retry rate, input mode and reason for failure. Test the same seeds under latency/jitter, low FPS, focus loss, Auto transitions and stopping during a held gesture. Verify real service rewards and movement restoration with restorable test profiles. Run Read & Rip with two actual players.

Expand the automated suite beyond one known solver and an untouched cursor: stationary safe positions, repeated one-button strategies, all-Good solutions, budget boundaries, unsuccessful-attempt resets and delayed completion. Passing the existing solver suite proves that solutions exist; it does not establish that the games are fair, difficult, enjoyable or worth replaying.
