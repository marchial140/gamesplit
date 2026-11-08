# GameSplit — development instructions

Continue the existing SwiftUI + SwiftData iPhone app (iOS 17+), in French. Read `docs/V1_1_1_REQUIREMENTS.md` for the current visual and bug-fix iteration; `docs/V1_1_REQUIREMENTS.md` and `CODEX_TASK.md` record earlier scopes.

- Priority 1 V1.1 is local: richer profiles, photos, multiple teams/positions, position stats, four individual points per passing TD. Keep a stable UUID per player across teams. OVR stays manual, 1–99.
- Preserve existing IDs, data, functionality and JSON V1 import. Add optional/defaulted schema fields. Do not delete stores or silently replace user data to resolve migration errors. Verify actual V1 → V1.1 migration on Mac before claiming compatibility.
- Keep `FinancesView.swift` and existing finance calculations/interface unchanged. Payments are manual; no bank integration.
- Passing touchdown: one linked passer record and one receiving record, one team score award. Individual contribution rules are centralized in `ContributionRules`, separate from the official score. Quantity edits/deletions must not duplicate totals.
- Stats and activities derive from current data. Membership changes must not reassign historical match sides. A paid participant cannot be removed by the roster editor.
- No fake login, invitations or sync. Local profile selection is not authentication; captain designations are not verified permissions. See `docs/SOCIAL_BACKEND.md` for the proposed Supabase stage and access requirements.
- Resize local photos, support accessible text and empty states. Do not add paid or third-party application dependencies for the local stage.
- Run `scripts/test-ios.sh` on macOS/Xcode and report actual XCTest outcomes. On Linux, structural checks are useful but never imply Apple type checking, rendered UI, migration, or XCTest execution.
- Do not publish an app or deploy a backend without explicit authorization.

## V1.1.1 invariants

- Keep the persisted SwiftData schema and backup format unchanged. Organization initials are the header fallback; there is no stored organization logo in this schema.
- Use `SportTheme` adaptive colors, native safe areas, flexible layouts and meaningful empty states. No fictitious activity or statistical leaders without completed games.
- Official matches keep their team rosters, never auto-balance, and require valid distinct sides with at least one tracked participant each. Apply `MatchValidation` at creation, CSV import and roster edits. Do not delete or silently rebalance old incomplete records.
- Creation/roster edits validate current team membership. Finishing an already recorded match keeps its historical sides even when current team membership has changed.
- The demo mode is deferred; do not add sample records to a real store.
- Publish this iteration to its dedicated GitHub branch `gamesplit-v1.1.1`, without merging into main or publishing an environment/app/backend.
