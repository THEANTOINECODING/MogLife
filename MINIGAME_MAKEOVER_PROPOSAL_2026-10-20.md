# MOGLIFE — A new strength playground

> Adopted by Antoine; implementation tracked in D76 and `design/02_MECANIQUES/PLAYGROUND.md`. This document preserves the original proposal. See `PLAYGROUND_DELIVERY_2026-10-21.md` for implemented scope and validation.

Research and creative proposal · 20 October 2026 · **Pending creator review**

This document proposes a complete replacement of the playable minigame lineup: six training activities, eight town jobs, five progression bosses, and arm wrestling. A sixth boss concept is included as an optional future extension. Nothing here is an accepted design decision or an instruction to deploy.

The recommendation is to rebuild the activities around tangible toys: compress, roll, collect, swing, connect, peel, fold, and outwit. Each game should be understandable from a short demonstration, feel good on the first attempt, and leave something specific to improve.

## 1. Scope and evidence

### What was checked locally

The vision, gameplay loops, minigames, bosses, helpers, duels, art, tests, roadmap, pending ideas, and active configuration were read. The current run service, controller references, and example minigame modules were inspected for integration constraints.

- **Verified in code:** six training entries, eight helper entries, five available progression bosses, and an arm-wrestling activity; PumpGod is configured with `comingSoon = true` and references `Combo`.
- **Declared in design:** every activity must have its own game; mobile comes first; physical actions should be visible in the world; training earns Mog and helping earns Cash.
- **New specification proposed here:** all twenty core games below, new training equipment, several changed helper tasks, bespoke boss objectives, and a revised presentation.
- **Optional extension:** Gravity Gauntlet for the God of Pump. Its existing design question remains open.

The current games were used to establish coverage and constraints, not as templates for the new concepts. The new roster changes the training activities themselves. It does not assume that curls, push-ups, or the current gesture rules must survive.

External research was conducted through papers, developer interviews, developer/publisher pages, and documented game descriptions. **No hands-on comparative playtest was performed in this research pass.** Published game descriptions establish mechanics, not why every player enjoys them. The proposed appeal of each new game is a hypothesis to test.

### The creative direction

**A ridiculous gym where strength turns ordinary objects into wonderful toys.**

The player should see their avatar operate the object. The useful movement, its consequence, and its result should occupy the same focal area. A broad control surface can sit below that scene when direct touch would obscure it.

A short training session should have a beginning, a developing situation, and a finish. For example: compress three objects, discover that the last one springs back, then stamp the finished cubes into a tiny trophy.

## 2. What other games teach us

The “lesson” column contains design interpretations, not claims of experimentally proven causes of those games' success.

| Reference | Documented mechanic or design approach | Lesson for MOGLIFE |
|---|---|---|
| [Epic Minigames — Typical Games](https://www.roblox.com/games/277751860/Epic-Minigames) | A collection of distinct rounds with character rewards and a separate party mode. | Make the next activity feel different enough that discovery is a reward. Group variety by what players decide, not just by scenery. |
| [Blade Ball — Wiggity](https://www.roblox.com/games/13772394625/Blade-Ball) | A homing ball accelerates; players use a simple deflection input across devices. | A visible approaching threat can make one action exciting. Give players enough information to anticipate it. |
| [Super Golf! — Nosniy Games](https://www.roblox.com/games/4468711919/Super-Golf) | A clear destination, shot planning, and different control mappings for touch, desktop, and console. | Let players predict an outcome, commit, then enjoy watching it unfold. Equivalent control does not require identical gestures. |
| [Super Bomb Survival — Polyhex Games](https://www.roblox.com/games/164051105/Super-Bomb-Survival) | Physics survival around explosions, changing events, and ragdoll play. | Physical consequences and recoverable comic accidents can make failure entertaining. Keep danger readable. |
| [WarioWare: Move It! — Nintendo](https://www.nintendo.com/us/store/products/warioware-move-it-118742/) | Very short physical microgames built around absurd actions. | Give each scene one clear instruction and one strong visual joke. MOGLIFE should use less physical effort and more repetition tolerance. |
| [Rhythm Heaven Fever — developer interview](https://iwataasks.nintendo.com/interviews/wii/rhythmheavenfever/0/0/) | Developers discuss choosing buttons over tiring repeated motion and making movement snappy. | Simple input can support deep timing. Physical fatigue is not a useful difficulty lever. |
| [Super Mario Party Jamboree — Nintendo's examples](https://www.nintendo.com/ph/switch/a7hl/minigame/index.html) | Examples include bridge traversal, photography, shadow alignment, and dividing a shape. | A collection benefits from observation and spatial judgment alongside reflexes. |
| [Fruit Ninja — Halfbrick's guide](https://www.halfbrick.com/blog/the-ultimate-beginners-guide-to-fruit-ninja) | One swipe can slice several fruit; the guide explicitly encourages deliberate combo swipes. | A continuous gesture producing several coherent reactions can feel powerful without frantic input. |
| [PowerWash Simulator — FuturLab's design direction](https://www.futurlab.co.uk/games) | The studio emphasizes low-friction play, visible transformation, and completion. | Include calming jobs with a satisfying finished object. A whole roster of escalating reflex tests would become exhausting. |
| [WHAT THE GOLF? — Triband's press kit](https://triband.net/press/whatthegolf) | A physics parody that changes what “golf” means through surprising situations. | Escalate the absurdity of the equipment while preserving a readable local rule. Reveal surprises before asking players to master them. |

No reference supplies copied characters, levels, art, sound, or branded presentation. Broad interaction patterns are research inputs; the proposed combinations and gym situations are MOGLIFE concepts.

## 3. Psychology: what may make players want another attempt

“Addictive” covers several different things. For this proposal the practical objective is **voluntary replay because the action is enjoyable and mastery is visible**. Psychological needs, learning mechanisms, and cognitive biases are distinguished below.

| Mechanism | What the evidence says | Proposed application and limit |
|---|---|---|
| Competence, autonomy, relatedness | A [2010 research synthesis by Przybylski, Rigby, and Ryan](https://selfdeterminationtheory.org/SDT/documents/2010_PrzybylskiRigbyRyan_ROGP.pdf) connects need satisfaction with enjoyment and engagement. These are motivational needs, not biases. | Let players understand their improvement, choose an activity, and share a visible result. Do not treat a higher session length as proof of enjoyment. |
| Curiosity about achievable outcomes | A [preregistered CHI 2024 experiment, n=1,699](https://people.csail.mit.edu/dkao/pdf/3613904.3642656.pdf), found benefits from success-dependent feedback; amplification alone reduced measured motives in its tested conditions. | Make the next attempt answer a question: “Can I knock down the whole row?” Grade the physical outcome visibly. More particles are not automatically better. |
| Learning under uncertainty | [Mastering uncertainty](https://pmc.ncbi.nlm.nih.gov/articles/PMC9363017/) offers a theoretical account of why reducing uncertainty through play can be enjoyable. It is a model, not a validated MOGLIFE difficulty formula. | Vary layouts within learnable rules. Let success become predictable through practice. |
| Goal proximity | [Kivetz, Urminsky, and Zheng, 2006](https://journals.sagepub.com/doi/10.1509/jmkr.43.1.39) observed greater effort nearer rewards in consumer contexts. | Show an honest small remaining task: one more cube or one last patch. Transfer to minigame enjoyment is an inference to test. |
| Endowed progress | [Nunes and Drèze, 2006](https://academic.oup.com/jcr/article-abstract/32/4/504/1787425?login=true) found that perceived initial progress could increase persistence. | Count the tutorial's first real success toward its first job. Do not enlarge a task to manufacture a misleading head start. |
| Near-miss motivation | [Clark and colleagues, 2009](https://pubmed.ncbi.nlm.nih.gov/19217383/) found that near misses in a gambling task could increase desire to continue despite being less pleasant. | Increased persistence is not synonymous with fun. Use truthful error information and genuine skill improvement; do not engineer fake near wins. This study does not establish benefits for children's skill games. |

These findings do not establish a universal “dopamine recipe,” a guaranteed retention increase, or a visual style everyone will love. Our strongest working hypothesis is that **readable control, an interesting result, and an attainable improvement** will support replay.

## 4. Visual and motion direction

The animation vocabulary draws on [Lasseter's animation principles](https://www.cs.cmu.edu/afs/cs/academic/class/15462-f13/www/lec_slides/Lesseter.pdf) and practitioner discussions such as [Juice It or Lose It](https://gdcvault.com/play/1016789/Juice-It-or-Lose). These describe useful craft techniques; they are not population-wide preference tests.

| Sensation | Proposed visual treatment | Where it matters |
|---|---|---|
| Compression | Material bulges sideways, seams crease, then the object settles into its new shape. | Scrap Press; muscle effort. |
| Stored energy | A rope stretches and vibrates before release; the launched object follows a readable arc. | Swing King; Rope Rave. |
| Weight | Brief anticipation, quick contact, slower follow-through; secondary objects react afterward. | Tire Domino; Atlas Stack. |
| Clean separation | A strip curls continuously or a cut opens along the player's path. | Peel Good; Chop Shop. |
| Completion | The last patch clears, the finished object settles, and one short sound confirms it. | Piano Polish; Towel Fold. |
| Causality across objects | Each impact visibly causes the next; sound follows the same order. | Tire Domino; Produce Parade. |
| Recovery | A wobble visibly returns toward rest after a good correction. | Atlas Stack; arm wrestling. |
| Personality | Kevin protects his snack; Brayan checks his reflection after a crash; Turbo argues with the treadmill. | Bosses, especially their recovery and defeat. |

Working presentation rules:

- Use solid silhouettes, readable material differences, and a quiet backdrop around the interactive object.
- Prefer a stable camera and restrained local object deformation during input. Reserve larger camera moves for a completed action or a skippable finish.
- Input gets an immediate local acknowledgment. A server response should confirm a result without replaying the same impact sound.
- Good and excellent outcomes should differ in the object itself: fewer scraps, a longer chain, a straighter tower. Labels support that difference.
- A failed action gets a brief recoverable wobble, spill, or bounce. Long failure scenes would punish practice.
- Every useful sound also has a visual cue. Color differences also use shape or symbols.
- Reduced motion removes optional shake, large pulses, and decorative movement while retaining outcome information.

Input alternatives and motion settings follow the direction of Microsoft's [input accessibility guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/107) and [motion guidance](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/117).

## 5. Six entirely new training games

**Proposed mapping:** each replaces one existing unlock slot. This retains the progression structure while introducing new exercises and props. All timings, thresholds, and unlock balance remain prototype hypotheses.

| ID / game / slot | What the player does | Satisfying payoff and reason to replay | Challenge and prototype risk |
|---|---|---|---|
| T1 **Scrap Press** — leg press; replaces Curl's starting slot | Hold to push a press into a ridiculous scrap object; release when its compressed shape fits the visible packing sleeve. Three objects make a set. | A shopping basket crumples into a tidy cube; a fridge spits out an ice cube before flattening. Fine control makes a visibly cleaner result. | Different materials spring back by a clearly previewed amount. Start with no spring-back. **Risk:** becomes waiting on a meter; reject it unless object deformation communicates everything needed. |
| T2 **Tire Domino** — tire roll; replaces PushUp's slot | Set the direction and strength of one tire roll with a drag, preview the first part of its path, and release toward a field of foam gym towers. | One deliberate roll causes a large, rhythmic collapse. The replay question is which line clears more targets. | Add one bank surface or a protected object before adding more targets. **Risk:** long passive playback; keep each chain brief and allow a quick retry after resolution. |
| T3 **Magnet Haul** — cable row; replaces BenchPress's slot | Steer a giant cable-mounted magnet through scattered weight plates, then drag it into a delivery bay. Attached plates enlarge the load. | Plates jump into a rattling cluster; depositing them produces an orderly clunk cascade. Players discover efficient collection routes. | A larger load needs more space around bumpers. Take a safe small load or carry more through a tight gap. **Risk:** sloppy physics; use bounded predictable motion and generous collision shapes. |
| T4 **Swing King** — suspended grip training; replaces Squat's slot | The avatar swings from a bar. Tap to let go; a generous catch zone grabs the next bar automatically. Reach the bell in three transfers. | Smooth arcs, stretching arms, a broad catch, then a bell smash. Better release choices preserve momentum. | Change bar spacing and height; show the next landing area. **Risk:** beginners cannot predict the arc; use a short trajectory hint and a recovery net. |
| T5 **Rope Rave** — battle ropes; replaces PullUp's slot | Watch and hear a short beat phrase; repeat it with taps anywhere on a large pad. Each tap sends a wave along the ropes. | Waves arrive at oversized bells in a musical sequence. A clean phrase turns the gym into a tiny concert. | Start with two evenly spaced beats, then add a rest or an offbeat. **Risk:** audio/device latency; provide visual timing, calibration, and generous baseline windows. |
| T6 **Atlas Stack** — strongman lifting; replaces JumpRope's slot | Move a suspended odd-shaped weight over a pedestal and lower it by releasing. Pieces arrive in a fixed orientation; choose support and placement. Build a three-piece monument. | Heavy objects land, wobble, and settle. The final absurd “sculpture” is the result of the player's choices. | Introduce overhangs and unequal mass, with a preview of the next piece. **Risk:** opaque collapses; exaggerate instability cues and score stable progress before a fall. |

Training games should initially target roughly 20–35 seconds per set, including their short payoff. This is a proposed change from the longer short-loop duration in the current design.

“Easy” means the first successful action is forgiving. “Challenging” means a better result requires judgment, planning, timing, or control. It does not mean tiny buttons, faster clicking, or an invisible target.

## 6. Eight new town jobs

The residents remain recognizable. Several of their tasks change to support genuinely different kinds of interaction. Jobs target approximately 15–25 seconds, with calm completion as a valid experience.

| ID / resident / game | What the player does | Satisfying payoff and reason to replay | Challenge and prototype risk |
|---|---|---|---|
| H1 Mom — **Peel Good** | Grab the oversized seal on a pickle jar and peel it in one continuous pull. Adjust the direction as the strip rounds the lid. | The seal curls into a long ribbon; the lid opens with a pop. A single unbroken strip is an immediately understandable personal best. | Broad bend angles first; later seals have two bends. A tear leaves a new large tab. **Risk:** sticky gesture recognition; follow the pull continuously, with no narrow traced line. |
| H2 Courier — **Airway Express** | Tap oversized hose elbows to rotate them into a route from pump to bicycle. A connected route sends air through automatically. | A pressure pulse travels through the exact route the player made, and a comically flat tire rounds out. | One mistaken elbow initially; later a small board with an obvious decoy. **Risk:** puzzle takes too long; prevalidate short solutions and offer an optional hint. |
| H3 Young neighbor — **Chop Shop** | Swipe a chop across a foam construction plank to cut a piece that matches the shown building silhouette. | A clean split, two falling offcuts, and the useful piece snapping into a miniature clubhouse. | Angle and length vary; the building needs at most a few cuts. **Risk:** precision favors mice; use generous geometric tolerances and endpoint selection on keyboard/controller. |
| H4 Neighbor — **Parking Knot** | Slide tiny parked vehicles along their lanes to clear an exit. Each gesture shifts one vehicle between defined positions. | The jam unravels, then the neighbor triumphantly pushes his car out with one finger. | Begin with one obstruction; later solutions need a few ordered moves. Undo is available. **Risk:** becomes a long puzzle; cap solution complexity and use tested layouts. |
| H5 Mrs. Do-Ré — **Piano Polish** | Sweep a broad cloth over the piano to remove cartoon grime and reveal its bright finish. | Clean trails, restored reflections, and a final warm chord. This is the deliberate relaxation break in the roster. | Optional excellence comes from economical coverage; basic completion has no harsh deadline. **Risk:** hunting tiny dirty pixels; finish small remnants automatically and show remaining large patches. |
| H6 Lifeguard — **Towel Fold** | Drag oversized towel corners toward a visible silhouette, completing a few satisfying folds. | The fabric flops, edges line up, and a chunky folded towel lands neatly on the pile. | Later towels need a different fold order; an incorrect fold can be lifted back open. **Risk:** fiddly cloth simulation; use controlled fold shapes with broad snapping. |
| H7 Grocer — **Produce Parade** | Draw a continuous line through adjacent matching produce on a small tray. Release to send the selected chain into the requested crate. | Each selected item hops out in order, producing a short rising sequence of pops. Longer well-planned paths are visibly rewarding. | Meet a small order with limited tray space; fruit uses distinct shapes as well as colors. **Risk:** random board luck; generate solvable boards and compare records only on equivalent challenges. |
| H8 Tourist — **Shortcut Chalk** | Draw one route across a compact street map, joining the tourist to the landmark while avoiding visible construction. Release to send them along it. | The tourist follows the drawn route with an exaggerated happy march; a clean short route feels clever. | One obstacle first; later include an optional scenic stop. **Risk:** finger blocks the route; put the trace slightly above the contact point and allow editing before departure. |

These jobs cover peeling, connection, cutting, ordering moves, coverage, folding, path selection on a tray, and route planning. Similar input gestures do not make them the same game: their decisions, state changes, and success conditions differ.

## 7. Bosses as short playable comedy scenes

The proposal replaces the universal “six graded repetitions against a simulated score” with an objective appropriate to each opponent. Keep a best-of-three structure where it helps pacing, but show the physical contest clearly. The AI must be understandable and must not secretly change results to force a close finish.

Each core boss gets three authored difficulty steps: teach the rule, introduce one complication, then combine already-seen elements. Durations should be tested around 15–25 seconds per round, with an overall time cap and immediate retry.

| ID / opponent / game | Core interaction and proposed round objective | Why it may be memorable | Challenge and main risk |
|---|---|---|---|
| B1 Kevin — **Snack Volley** | Slide a large tray left/right to return bouncing popcorn balls toward his sofa. Return four before conceding three. | Kevin refuses to stand up; every return makes his snack pile and sofa bounce. Big contact surfaces give a quick first success. | Vary rebound angles and introduce a slow floating snack. **Risk:** first boss feels like a reflex wall; use slow opening serves and an oversized tray. |
| B2 Brayan — **Sunbed Slalom** | Steer an automatically moving sunbed through a short obstacle course. Finish ahead of Brayan; both encounter equivalent obstacles. | Luxurious gliding punctuated by absurd cushion bounces; Brayan keeps trying to admire himself while racing. | Choose a broad safe route or a shorter route through tighter gaps. **Risk:** resembles ordinary running; the lounger needs distinctive smooth steering, readable inertia, and physical cushion reactions. |
| B3 Coach Turbo — **Treadmill Takeover** | Tap to reverse a giant treadmill. Time the reversal so the charging coach slides into a padded end wall before reaching your protected station. Three pad hits win; two tags lose. | His own momentum defeats him. Each reversal stretches the belt and sends his oversized whistle trailing behind. | Show his charge direction and stopping distance; later charges have different, announced momentum. **Risk:** arbitrary timing puzzle; prototype the motion before art and require novices to explain what happened. |
| B4 Mr. Never-Leg-Day — **Leg Day Landgrab** | Drag your marker out from safe territory and back to enclose a patch of exercise floor. His telegraphed stomps can break an exposed trail. Capture enough area before three broken trails. | The floor flips to your emblem in a wave; the opponent ends on a ridiculous little island. | Choose small safe captures or bigger exposed loops. **Risk:** hardest concept to teach; use an opening guided loop and a very small arena. Drop complexity if the rule needs repeated explanation. |
| B5 King of the Block — **Crown Sneak** | Hold to advance between hiding places; release to freeze. Read his sweeping spotlight and wind-up before committing to the next gap. Reach the crown before being caught three times. | Your huge avatar disguises itself as increasingly implausible gym statues. The final theft makes the king's fan ceremonially blow his own crown toward you. | Later sections change the spotlight's visible sweep and cover spacing. **Risk:** passive waiting; make safe advances frequent and cap downtime between chances. |

### Optional future boss: B6 God of Pump — Gravity Gauntlet

One tap reverses the avatar's gravity in a compact cosmic chamber. Use the rise and fall to reach glowing temple seals while avoiding clearly telegraphed lightning. Each activated seal removes a piece of the god's enormous divine dumbbell.

The appeal is learning to redirect momentum while the world responds on a ridiculous scale. Difficulty comes from position, velocity, and known hazard patterns; inputs remain a single button. Start with a safe ceiling/floor transfer, then introduce horizontal travel and lightning one at a time.

**Main risk:** motion and inertia become difficult to read. Use a stable side view, clearly different floor/ceiling surfaces, generous first seals, and no rotating camera. This is a future concept, not a decision to enable the currently unavailable boss.

## 8. Arm wrestling: Read & Rip

The proposal keeps the social fantasy of arm wrestling and replaces the current matching/timing routine with a readable contest of commitment.

- **Hold to push:** your avatar applies force while consuming endurance.
- **Release to brace:** recover endurance, conceding ground slowly.
- Watch your opponent's arm tremble and posture tighten. Push when they overcommit, or recover before you exhaust yourself.
- Empty endurance creates a short vulnerability. Both players see a clear warning before their own exhaustion.
- Win by pinning the opposing hand. At the round time limit, arm position decides; an exactly centered arm is a draw.
- Both players have the same mechanical capacity. Mog, cosmetics, and spending do not affect force or endurance.

The satisfying sequence is strain → tactical recovery → a decisive push → a padded table impact. The interest comes from the other player's choices, not rapid clicking.

**Critical prototype risk:** “always hold,” “always brace,” or rapid toggling could dominate. Build and test this early with scripted policies and real pairs. Tune recovery, pressure, transition behavior, and exhaustion until the counterplay is demonstrable. Do not produce a full animation set before this is solved.

## 9. Controls and accessibility

Every game must work with one touch contact at a time. No multi-touch, compulsory gyroscope, or repeated high-speed tapping. Keyboard and controller players get a native control mapping, not an expectation to reproduce a finger's handwriting.

| Interaction | Touch / mouse | Keyboard / controller |
|---|---|---|
| Hold or tap: T1, T4, T5, B3, B5, B6, duel | Large pad or primary action | Space / primary face button; optional toggle where appropriate |
| Continuous horizontal steering: B1, B2 | Relative horizontal drag in a broad control area | Left/right or stick |
| Position an object or magnet: T3, T6 | Drag with an offset so the object remains visible | Directional cursor/stick; release or confirm placement |
| Aim a tire: T2 | Drag direction and power, release to roll | Adjust direction, then power, then confirm; sequential inputs |
| Select/rotate/slide: H2, H4 | Tap or drag a large piece | Directional focus, confirm, then choose movement if necessary |
| Peel/fold/cut: H1, H3, H6 | One broad drag | Select tab/corner or first endpoint, move directionally, then confirm/release |
| Coverage/tracing: H5, H7, H8, B4 | Drag with contact offset | Stick/directions trace with a toggle to start/end; adjacent focus selection for produce |

These mappings are initial designs. Continuous tracing and swing timing are the highest risks for device differences. Normalize game-space movement, snapping, and legal outcomes; measure results on real devices rather than assuming mathematical normalization guarantees equivalent feel.

Keep free Auto for training and town jobs, mapped to their existing base reward policy. Do not award manual skill records for Auto. Bosses and PvP remain manual, with clearly labeled practice and assistance options proposed for accessibility. Competitive matching must not silently put different rule sets against each other.

## 10. Rhythm, rewards, and replay

### First encounter

1. Show the object and a short verb: “Crush to fit,” “Roll the tire,” or “Peel the seal.”
2. Demonstrate one action for approximately two seconds; allow skipping.
3. Let the first attempt use a forgiving setup.
4. Add one readable variation during the set.
5. Finish with the physical result, a short performance summary, and equal access to replay or leave.

Timing values are proposals, not researched universal optima.

### Reasons to return

- Improve an observable personal result: a complete domino chain, an unbroken seal, or a stable monument.
- Discover authored variations in material, arrangement, or comic payoff.
- Choose a different sensation when bored: movement, destruction, puzzle solving, or a calm cleanup.
- Show another player the result in the world.

Training continues to produce Mog; town jobs produce Cash. The starting balancing target should be comparable reward per unit of active play, including setup and result time. A forty-object cascade must not generate forty economic rewards.

Preserve earned progress and existing first-time reward records. New records, if introduced, require versioned definitions: a score from an old timing game cannot honestly be ranked against a new physical puzzle.

No new currency, paid skill advantage, random reward purchase, or absence penalty is proposed. Surprises come primarily from situations and performances. Each completed set remains a natural place to stop.

## 11. Production implications and deviations requiring review

This makeover is substantially larger than swapping minigame modules.

| Area | Proposed change | Consequence |
|---|---|---|
| Training content | Replace all six exercise themes at their unlock slots. | New equipment, animations, names, tutorial references, and configuration migration. |
| Helper content | Keep the eight residents but change several jobs. | New props and dialogue for construction, piano restoration, towel folding, and route drawing. |
| Boss format | Replace universal graded-repetition contests with bespoke objectives. | Boss orchestration and scoring need an extension; this must not bypass progression or reward checks. |
| Run format | Support short objectives and continuous play. | Extend the existing run lifecycle once. Do not build twenty separate reward/session systems. |
| Presentation | Make the controllable scene the primary visual focus. | Budget avatar posing, object deformation, camera placement, spectator readability, and mobile performance together. |
| Auto | Preserve training/helper base progression through new scenes. | Each game needs an explicit automated completion behavior and identical cleanup guarantees. |
| Finale | Offer Gravity Gauntlet as a candidate. | PumpGod stays an open future decision until approved. |

The current server enforces cadence, distance, allowed qualities, and reward calculation, but accepts a client-sent quality string. The proposal cannot claim that this validates a domino trajectory or PvP endurance.

For implementation, the server should own the challenge definition, legal state transitions, duration, and rewards. Discrete puzzle moves can be validated directly. Timing games need bounded timing validation; physical games need a small authoritative or reproducible logical simulation with local animation. Client-side effects should be responsive, while economically meaningful outcomes remain checked.

Do not rely on unconstrained networked rigid-body chaos to decide a competitive result. Do not promise full anti-cheat merely because the server calculates Cash. Validate each game's meaningful actions.

Training and bosses should use bounded activity scenes with defined camera and play areas. Multiplayer collisions and other players' visual effects should not obscure the active task. Spectators can see a simplified replicated performance. Travel-style scenes must retain a valid server activity anchor rather than accidentally triggering distance cancellation.

Use simple meshes, controlled deformations, pooled cosmetic fragments, and a small active-object budget. Test on the project's selected reference phone against its stated 30 FPS minimum. Do not simulate hundreds of metal pieces because the art suggests hundreds.

The existing project rules still apply: English localizable game text; balancing in configuration; one responsible editor per implementation lot; no direct script edits in Studio; one playable slice at a time.

## 12. Proposed build order after approval

| Stage | Deliverable | Advance only when |
|---|---|---|
| 0 — Review this proposal | Decide on the new training themes, changed helper tasks, boss format, and prototype shortlist. Keep the finale separate. | The creator accepts the direction or identifies replacements. |
| 1 — Four feel prototypes | Scrap Press, Tire Domino, Peel Good, and Snack Volley in an isolated test setup. | Each has a comprehensible action and a satisfying visible result on phone, desktop, and controller. |
| 2 — Risk prototypes | Read & Rip, Swing King, and Leg Day Landgrab. | PvP has real counterplay; swing trajectories read clearly; territory capture teaches quickly. |
| 3 — First playable slice | Starting training → Mom's job → Kevin, with tutorial, rewards, cleanup, and Auto. | A new player can complete the loop; existing progression and saves remain correct. |
| 4 — Remaining roster, small batches | Complete the other training, helper, and boss activities with the same review gate per batch. | Each activity earns its place through distinctive play and player feedback. |
| 5 — Balance and delivery | Cross-device tests, economic simulation, multiplayer checks, performance, localization, and release review. | The evidence supports deployment. |
| Later — Optional finale | God of Pump content after a separate decision. | The future zone/boss scope is approved. |

First prototypes should include enough animation and sound to test feel; grey boxes alone cannot evaluate peeling or compression. They should avoid final asset polish until the rule works.

A credible calendar estimate requires knowing who owns art, animation, audio, and engineering and what the prototypes reveal. The main cost is producing and validating distinct physical scenes, not writing twenty tiny wrappers.

## 13. How we decide whether players actually like it

Start with a formative group of approximately 8–12 players with mixed familiarity. Include real phone, tablet, mouse, keyboard, and controller sessions; expand the sample before making platform or retention claims. Counterbalance prototype order so the first game is not always favored.

Use comparable rewards and make leaving an equally visible choice. Ask for a voluntary replay before offering extra currency. Record whether the player understood the rule, enjoyed the physical action, and knew what to improve.

Provisional prototype gates, to revise after the first tests:

| Question | Initial decision rule |
|---|---|
| Can newcomers understand it? | Aim for at least 80% to perform the intended first action within ten seconds after the demonstration, without coaching. Report the actual count in small samples. |
| Is it enjoyable without an economic incentive? | Record free-choice replay and enjoyment ratings; repeated comments that only the reward matters trigger a redesign. Do not treat one threshold as proof of fun. |
| Is failure informative? | Most players should be able to explain their last miss and name a plausible correction. |
| Is there mastery? | Across several attempts, measure improved outcome quality without increased input rate. |
| Is it genuinely different? | Ask players to describe the key decision in each game. Merge or replace concepts they experience as the same task. |
| Is it comfortable? | Record hand fatigue, visual discomfort, finger occlusion, and sound dependence. Check reduced-motion and silent play. |
| Are controls fair? | Compare within-player completion and quality across devices where practical; report differences and uncertainty. |
| Does it survive repetition? | Revisit it after the novelty has worn off. Separate fascination with a new effect from lasting interest in its rule. |
| Does PvP have choices? | Test constant-push, constant-brace, and rapid-toggle policies, then mixed-skill real pairs under varied latency. |

For engineering acceptance, run the repository's formatting/lint gates and relevant Studio tests after implementation. Verify reward bounds, Auto, cancellation, disconnects, two-player duels, first-win idempotency, save preservation, and cleanup. Restore test-player data as required by the project.

No player-preference measurements or new Studio tests have been performed for these concepts. They are proposed experiments and gates.

## 14. Recommendation for the creator

Approve or revise the **new strength-playground direction**, then authorize the four feel prototypes: **Scrap Press, Tire Domino, Peel Good, and Snack Volley**. They test compression, chain reactions, continuous material interaction, and a simple opponent.

The key review choices are whether to replace the six traditional exercise themes, accept the changed town tasks, and make bosses bespoke contests. The God of Pump remains a separate future choice.

If a prototype is only interesting when its reward number increases, it needs a better interaction before it earns a place in the full makeover.
