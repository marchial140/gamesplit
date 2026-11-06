# Codex instructions — GameSplit V1

## Product
Build and refine a native iPhone MVP for *flag/touch football* organizers. The app is **French first**, supports **iOS 17+**, uses **SwiftUI + SwiftData**, and is fully offline in V1. The data schema includes `Club.sport` so future sports can be added without a rewrite.

## Nonnegotiable
- Do not add authentication, cloud sync, third-party APIs, paid dependencies, or bank integrations to V1.
- All player, match, season, stat and payment data must persist locally.
- Do not invent payment confirmations. Only manual paid/unpaid toggles.
- Touchdown by pass = one `pass_td` stat for QB and one `receiving_td` for receiver; count as **one** team touchdown, not two.
- Team point awards configurable/editable. Actual score is not a sum of “GameSplit contribution points.”
- Keep interactive components accessible, with usable font sizes and empty states.
- Avoid destructive migrations and do not lose user data.
- Keep code modular and include automated tests for scoring, ID encoding, team balancing and zero-participant cost.

## First Codex task
Read `CODEX_TASK.md` and the entire project. Build for iOS simulator on macOS/Xcode where available; fix compile errors and failing tests. If Xcode is unavailable, perform a static review and report the absence of executable verification. Complete the V1 acceptance criteria before polishing visuals.

## Completed starter work
The source files contain first-pass implementation of: welcome/create group, players/OVR, games/teams, match results, event stats, local seasons, standings, cost splitting, and sharing text. It is a source prototype, **not verified with Xcode**.
