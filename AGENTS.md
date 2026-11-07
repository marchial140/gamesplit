# GameSplit — development instructions

Continue the existing SwiftUI + SwiftData iPhone app (iOS 17+), in French. Read `docs/V1_1_REQUIREMENTS.md` for current priorities; `CODEX_TASK.md` records the original V1 scope.

- Priority 1 V1.1 is local: richer profiles, photos, multiple teams/positions, position stats, four individual points per passing TD. Keep a stable UUID per player across teams. OVR stays manual, 1–99.
- Preserve existing IDs, data, functionality and JSON V1 import. Add optional/defaulted schema fields. Do not delete stores or silently replace user data to resolve migration errors. Verify actual V1 → V1.1 migration on Mac before claiming compatibility.
- Keep `FinancesView.swift` and existing finance calculations/interface unchanged. Payments are manual; no bank integration.
- Passing touchdown: one linked passer record and one receiving record, one team score award. Individual contribution rules are centralized in `ContributionRules`, separate from the official score. Quantity edits/deletions must not duplicate totals.
- Stats and activities derive from current data. Membership changes must not reassign historical match sides. A paid participant cannot be removed by the roster editor.
- No fake login, invitations or sync. Local profile selection is not authentication; captain designations are not verified permissions. See `docs/SOCIAL_BACKEND.md` for the proposed Supabase stage and access requirements.
- Resize local photos, support accessible text and empty states. Do not add paid or third-party application dependencies for the local stage.
- Run `scripts/test-ios.sh` on macOS/Xcode and report actual XCTest outcomes. On Linux, structural checks are useful but never imply Apple type checking, rendered UI, migration, or XCTest execution.
- Do not publish an app or deploy a backend without explicit authorization.
