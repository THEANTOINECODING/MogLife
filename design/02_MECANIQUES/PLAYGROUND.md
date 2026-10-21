# Strength playground - D76

Adopted by Antoine following the research proposal dated 20 October 2026.

## D77 playtest revision

Antoine reported a stuck character after boss results, awkward controls and insufficient difficulty. The game panel now occupies the right side; the left is transparent and the world camera frames the animated player. Server snapshots acknowledge the accepted input sequence, so pending gestures are replayed instead of discarded. Fast grid drags trace crossed cells. A pointer leaving the panel no longer steers the game unless a drag is held.

Training targets and precision requirements are increased. Kevin requires seven faster returns with a narrower tray; Brayan sends more frequent obstacles; Coach requires four later reversals; territory requires multiple smaller loops; the spotlight offers shorter safe windows. Jobs include limited pipe turns, an additional blocking car, timed polishing, tighter folds, bent produce chains and a maze route. See Config/Playground for exact values. Auto issues legal inputs under the new rules.

The Series movement lock is released when each boss/duel run ends, independently of the fight lock. Victory and defeat also release movement immediately; their result dialogs are informational and do not require OK to resume walking.

## Roster and preserved progression IDs

| Category | Saved ID | Game | Interaction |
|---|---|---|---|
| Training | Curl | Scrap Press | Compress and release |
| Training | PushUp | Tire Domino | Aim and launch |
| Training | BenchPress | Magnet Haul | Collect and deliver |
| Training | Squat | Swing King | Release to catch the next bar |
| Training | PullUp | Rope Rave | Strike the beat |
| Training | JumpRope | Atlas Stack | Position and drop |
| Job | OpenJar | Peel Good | Peel the seal |
| Job | PumpTire | Airway Express | Turn the pipes |
| Job | Nails | Chop Shop | Draw a cut |
| Job | PushCar | Parking Knot | Slide cars |
| Job | Piano | Piano Polish | Wipe dust |
| Job | BeachChairs | Towel Fold | Fold corners |
| Job | Groceries | Produce Parade | Connect matching neighbors |
| Job | Directions | Shortcut Chalk | Draw a route |
| Boss | Kevin | Snack Volley | Return popcorn |
| Boss | Brayan | Sunbed Slalom | Dodge cones |
| Boss | CoachTurbo | Treadmill Takeover | Reverse after the charge |
| Boss | NoLegs | Leg Day Landgrab | Close territory before a stomp |
| Boss | BlockKing | Crown Sneak | Advance and freeze |
| Duel | ArmWrestle | Read & Rip | Push, recover, punish exhaustion |
| Future boss | PumpGod | Gravity Gauntlet | Flip gravity |

## Runtime

### Audit follow-up, rules version 4 (21 October 2026)

The resumed working tree already contains the audit fixes: matching slalom collision widths, offset Atlas bases and visible drift, Coach commitment reset on both failures, and rhythm completion separated from precision. Valid Good hits complete the phrase; the phrase ends without an empty timeout tail.

Training uses configured `rewardTime` and objective completion rather than elapsed waiting time. Validated sub-actions supply combo and precision; misses lower mastery. Playground jobs pay only on objective completion and failed jobs remain retryable. The job result closes instead of restarting the previous exercise. These replace the version 3 reward behavior described below; economy tuning still needs an alpha review.

Portrait play uses more width, grids have discrete keyboard/stick navigation, budgets and error reasons are shown, and pipe/car puzzles have budgeted undo. Variants are defined in configuration. Fast release gestures now trace their final segment before ending the action, including fruit chains and route destinations.

Verification and remaining work: `PLAYGROUND_AUDIT_FOLLOWUP_2026-10-21.md`.

- Shared deterministic rules: `src/shared/Playground`. Principal tuning: `Config/Playground`.
- Server simulation at 30 steps/second; snapshots every 150 ms; local prediction.
- `PlaygroundInput` requires a run token, increasing sequence, finite coordinates and a message budget. Legacy `Rep` reports cannot score these games.
- One result per challenge. Training Mog uses configured reward time, completion and existing quality/boost multipliers. Helper completion gates payouts and cooldowns; Mom retains her first-success minimum.
- Historical records remain intact; new records use `Playground2.*`.
- Boss success uses the actual objective, keeping existing rounds, unlocks and rewards.
- Duel forces are integrated simultaneously with equal stamina rules. The real table receives the server lean.
- Mouse/touch, Space/A, arrows/WASD/ZQSD/stick. Focus loss releases the action. Free Auto issues legal inputs and cannot earn manual records.
- Responsive square scenes, sound feedback and localized instructions. Nearby observers see the station diorama and operator pose.

## Validation and remaining limits

`tests/playground.luau`: three seeds per game, a valid solution, idle failure, drawing validity and immutability after completion. Boss Auto is unavailable. Studio network tests verify rejected client grades and real helper/training rewards. A complete practice duel verifies stamina, exhaustion, rounds and participation rewards. Test profiles must always be restored.

Physical phone FPS, touch feel, a duel with a second real player and final art approval need device playtests. Current props are procedural dioramas, not custom Blender machines. Existing static city decorations remain around the stations. Gravity Gauntlet stays behind the existing future-boss lock.
