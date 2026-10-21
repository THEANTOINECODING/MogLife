# D77 - player feedback revision

## Changes

- Fixed the leaked Series movement lock at the end of boss and duel rounds.
- Victory/defeat now release movement immediately, independently of the informational OK dialog.
- Right-side game panel, transparent left side, aspect-aware world camera and automatic reframing on viewport changes.
- The actual character responds to compression, aiming, swinging, rope beats, drawing and impacts. Local gestures drive its pose immediately.
- Server snapshots acknowledge input sequence numbers. Pending local gestures are replayed; short prediction catches up without discarding unacknowledged presses/releases.
- Release uses the final pointer position. Leaving the board does not steer it unless dragging. Fast grid drags interpolate crossed cells.
- Brief hit/miss feedback and sound. Parking clicks that do not move a car no longer waste a move.
- Harder configuration across the roster: more press/chop/stack targets, tighter precision, moving magnet bumper, longer rhythm phrases, randomized pipe rotations with a turn budget, a fourth blocking car, polishing dwell, tighter folds, bent produce groups, maze routing.
- Bosses: seven accelerated snack returns with a narrower tray; faster/more frequent cones; four later belt reversals; 24 territory cells requiring smaller loops; shorter spotlight-safe phases; tighter gravity catches.
- Auto remains free for exercises/jobs and completes them through legal gestures.

## Verification

- All 20 non-duel games solved for three seeds with the revised rules, including idle failure, drawing validity and terminal-state checks. Fast route-drag regression added.
- All 21 UI modules constructed/destroyed, and right-side bounds checked at 390x844, 844x390 and 1366x768.
- Real harder Kevin fight: two objective wins and Victory; result dismissed with the mouse and walking restored (16), jump restored (50), camera Custom, AutoRotate true.
- Real intentional Kevin defeat: two losses and Defeat.
- Final client-event regression: speed 0 during the round, then speed 16 and jump 50 immediately after Defeat while the result panel is still visible. Victory also restores movement with terminal events delivered before the run-ended event.
- Screenshot reviewed with the game on the right and the animated world character visible on the left. Camera offset and meter position were refined afterward.
- Later Studio rendering became unavailable (viewport 1x1); mouse and screenshot requests stalled and were cancelled. The final timed manual press and final camera screenshot could not be completed in that condition. No physical-device feel or FPS claim is made.
- Fixed an invalid rig.root.RightVector access found in the final console pass; all 20 activity animations then passed on the actual character for held/released states. Regression saved in tests/playground_poses.luau.
- Final formatting, Selene and Rojo build checks passed. Test profile restored. No public publishing or Git commit.

Main files: MinigameController, BossController, ActivityController, DuelController, CameraFraming, PlaygroundClient, Activities/Playground, shared Playground rules, Config/Playground, Texts and MinigameService. Tests: tests/playground.luau. Tuning remains subject to player feedback.
