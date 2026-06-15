# Who Am I — STRUCTURE.md (Project Structure & File Organization)

> Companion to `SCAFFOLD.md`. Defines **where every file lives** and the rules for adding new ones. Guiding principle: **docs, the iOS app, and the backend each live in their own top-level folder — nothing important sits loose in the root.**

---

## 1. Top-level layout

```
who-am-i/
├── README.md            # entry point — orientation, stack, hard constraints
├── docs/                # ALL specs & design docs (every .md lives here)
│   ├── PRODUCT.md       #   the PRD
│   ├── GIST.md          #   AI generation spec
│   ├── SCAFFOLD.md      #   build setup: stack, MVVM, Supabase, Xcode
│   └── STRUCTURE.md     #   this file
├── WhoAmI/              # the iOS app — Xcode project + all Swift code
└── supabase/            # the backend — DB migrations + Edge Functions
```

**Why `README.md` stays at root:** it's the universal front door — tooling, editors, and GitHub all expect it there, and it's the index that points into `docs/`, not a spec itself. Every *other* markdown lives in `docs/`. (If you'd rather a completely bare root, README can move into `docs/` too — it's a one-line change to this section.)

---

## 2. `docs/` — the specs

All markdown, **one concern per file**, cross-referenced by filename. Add new design/spec docs here, **never** scattered into code folders. Keep code folders free of stray `.md` (a per-folder README is acceptable only when it's genuinely build-essential).

---

## 3. `WhoAmI/` — the iOS app

```
WhoAmI/
├── WhoAmI.xcodeproj
├── WhoAmI/                     # app sources (Xcode group mirrors disk)
│   ├── App/                    # @main App, root router, AppContainer (DI), tab scaffold
│   ├── Core/                   # cross-feature infrastructure (no UI)
│   │   ├── Supabase/           #   SupabaseClient + provider
│   │   ├── Auth/               #   AuthService, session / auth-state, age-gate logic
│   │   ├── Services/           #   domain services: Connections, Prompts, Posts, Replies, Gist, Profile
│   │   ├── Config/             #   env config read from Info.plist / xcconfig
│   │   ├── Errors/             #   typed AppError
│   │   └── Extensions/         #   small shared helpers
│   ├── Models/                 # Codable domain models (User, Connection, Prompt, Post, Reply, Gist, GistVersion)
│   ├── Features/               # one folder per feature = View(s) + ViewModel + local subviews
│   │   ├── Onboarding/         #   AgeGate, Verify, ProfileSetup, AddFriends
│   │   ├── Today/              #   daily prompt + answer flow (incl. public/private toggle)
│   │   ├── Profile/            #   My Profile + Someone's Profile, archive, counters, locked private items
│   │   ├── Gist/               #   gist detail, see-more, evolution timeline
│   │   ├── Curate/             #   owner privatize controls (post-graduation)
│   │   ├── Connections/        #   manage people, viewer/replier role, revoke, block
│   │   └── Share/              #   share-card generator
│   ├── DesignSystem/           # colors, typography, reusable components, view modifiers
│   ├── Resources/              # Assets.xcassets, fonts, Localizable.strings
│   └── Supporting/             # Info.plist, *.entitlements, Config/*.xcconfig
├── WhoAmITests/                # unit tests (ViewModels with mocked services)
└── WhoAmIUITests/              # UI tests (onboarding gate, core loop)
```

**Rules:**
- A **View never imports Supabase.** All data access is `Core/Services/` only (`SCAFFOLD.md` §2).
- Each **Feature** folder is self-contained: `XView.swift`, `XViewModel.swift`, plus any private subviews. Shared UI → `DesignSystem/`; shared data types → `Models/`.
- **Disk folders == Xcode groups** (use folder references so they never drift).
- Infrastructure with no UI (clients, services, config, errors) → `Core/`, not a Feature.

---

## 4. `supabase/` — the backend

```
supabase/
├── config.toml         # Supabase CLI config
├── migrations/         # SQL: schema + RLS policies — author these FIRST (they ARE the privacy guarantee)
├── functions/          # Edge Functions (Deno/TypeScript)
│   ├── publish-daily-prompt/
│   ├── generate-gist/        #   calls Anthropic per GIST.md; runs the §15 safety check
│   └── regenerate-gists/     #   batched accretion regeneration
└── seed/               # prompt-deck seed (~30–50 prompts with tone tags) for Phase 2
```

- The **Anthropic key** and the **service_role key** live in Edge Function env (`supabase secrets`), **never** in the repo or the app.
- **Migrations are the single source of truth** for schema + RLS; the Swift `Models/` mirror them.

---

## 5. "Where does X go?" — decision table

| You're adding… | It goes in… |
|---|---|
| A new screen / feature | `WhoAmI/WhoAmI/Features/<Feature>/` (View + ViewModel) |
| A data type from the DB | `WhoAmI/WhoAmI/Models/` |
| A network / data call | a Service in `WhoAmI/WhoAmI/Core/Services/` |
| A reusable button / style / color | `WhoAmI/WhoAmI/DesignSystem/` |
| A DB table / column / RLS change | `supabase/migrations/` (new migration) **and** update `Models/` |
| Gist / AI logic | `supabase/functions/` — **not** the app |
| A design / spec doc | `docs/` |
| A secret / API key | Edge Function env — **never** the repo |

---

## 6. Naming conventions

- **Swift:** one public type per file; filename = type name. Suffixes `…View`, `…ViewModel`, `…Service`; models are plain nouns. Types `UpperCamel`, members `lowerCamel`.
- **Folders:** `UpperCamel` for Swift groups (to match Xcode); lowercase-hyphen for backend (`supabase/functions/generate-gist`).
- **Docs:** `UPPERCASE.md` for the top-level specs (`PRODUCT`, `GIST`, `SCAFFOLD`, `STRUCTURE`).
- **DB:** `snake_case` tables/columns (`PRODUCT.md` §8); Models map via `CodingKeys` / key-decoding strategy.

---

## 7. Root hygiene

- The root holds **only** `README.md`, the three folders (`docs/`, `WhoAmI/`, `supabase/`), and tooling dotfiles (`.gitignore`, `.swiftformat`, etc.).
- **No source, no specs, no secrets loose in the root.**
- `.gitignore` should cover: `build/`, `DerivedData/`, `*.xcuserstate`, real `*.xcconfig`, `.env`, `.DS_Store`, `supabase/.temp/`.
