# Grapevine — App Flow, Screens & Navigation

> How the app is wired: the end-to-end flow, the navigation model, the bottom tab bar, every screen we need (including Settings and the mandatory invite gate, which don't exist yet), and the custom component library each screen is built from. Companion to `PRODUCT.md` §9 (the product-level "key surfaces") and `SCAFFOLD.md`/`STRUCTURE.md` (the MVVM/file layout).
>
> **Status legend:** ✅ built · 🟡 exists but inline / not yet a reusable piece · ⬜ planned / missing.

---

## 1. Top-level flow

```
 Launch
   │
   ▼
 [0 · Splash]  ──── already signed in? ───────────────────────────►  [ Main tab shell ]
   │  new / signed out
   ▼
 [ Onboarding ]
   1 · Intro carousel (5 value-prop slides, swipeable)
   2 · Age gate (18+)
   3 · Notifications ask
   4 · Sign in  (email · Apple · Google)   ← end of onboarding
   │
   ▼  (auth flips → "needs profile")
 [ Profile setup ]   display name · bio · spice comfort level
   │
   ▼  (MANDATORY gate — can't enter the app until met)
 [ Invite friends ]   add / invite ≥ 5 people · import from contacts · search · invite link
   │
   ▼
 ┌────────────────────────  Main tab shell (4 tabs)  ────────────────────────┐
 │   Today            People              Activity              You          │
 │   (daily loop)     (connections)       (event feed)          (your gists) │
 └────────────────────────────────────────────────────────────────────────────┘
```

**The daily loop (inside Today):** prompt drops → you answer about your people (Answer sheet) → set your own post's spice level → replies accumulate blind → your post graduates → **Activity** + push notification → open **You → Post detail** to read the gist → curate (hide / reveal) → share card.

---

## 2. Navigation model

- **Splash gate** — `RootView` shows `SplashView` first on every launch (~2s), then routes.
- **Auth-state routing** — driven by `SessionStore.phase`:
  | phase | shows |
  |---|---|
  | `.loading` | branded spinner (gradient) |
  | `.signedOut` | `OnboardingView` (the 4-step flow) |
  | `.needsProfile` | `ProfileSetupView` → **`InviteFriendsView`** (gate) |
  | `.signedIn` | `MainTabView` |
- **The invite gate sits between profile setup and the app.** A new `.needsFriends`-style check (≥ MIN invited) blocks `MainTabView` until satisfied — so onboarding isn't "done" until the social graph can actually graduate a post.
- **Signed-in shell** — a **bottom tab bar** (`MainTabView`); each tab owns its own `NavigationStack` for push-detail screens.
- **Convention — push vs sheet:**
  - **Sheets (modal, focused tasks):** Answer, Share card, Add connection, Invite (contacts), Spice picker.
  - **Pushes (drill-in, part of a hierarchy):** Post detail, Someone's profile, Gist evolution, Settings + its sub-screens.

---

## 3. Bottom navbar (tab bar) — 4 tabs

| Tab | Icon (SF Symbol) | What it is | Root screen | Status |
|---|---|---|---|---|
| **Today** | `sparkles` | the daily prompt + who you can answer about | `TodayView` | ✅ |
| **People** | `person.2` | your connections (viewer/replier), add/revoke/block, + invite | `ConnectionsView` | ✅ |
| **Activity** | `bell.badge` | event feed: gist ready, made-a-replier, reveals, nudges | `ActivityView` | ⬜ |
| **You** | `person.crop.circle` | your crowd-authored profile + gear → Settings | `ProfileView` (self) | ✅ |

**Settings is *not* a tab** — gear in the **You** tab's nav bar. **Compose/answer** launches from **Today**. (Order is adjustable; Today home-left, You profile-right is the convention.)

---

## 4. Screen inventory

### 4.1 Onboarding & first-run (pre-app)
| # | Screen | Purpose | Reached via | Key components | Status |
|---|---|---|---|---|---|
| 0 | **Splash** | brand moment while auth resolves | launch | BrandBackground, wordmark | ✅ `SplashView` |
| 1 | **Intro carousel** | 5 value-prop slides (the pitch) | after splash | OnboardingSlide, PageDots, BrandCTAButton | ✅ `IntroPagerView` |
| 2 | **Age gate** | 18+ DOB entry, hard block | after carousel | DOBPicker, PrimaryButton | ✅ `AgeGateView` |
| 3 | **Notifications ask** | contextual permission prompt | after age gate | BrandBackground, BrandCTAButton | ✅ `NotificationsPromptView` |
| 4 | **Sign in** | email · Apple · Google (end of onboarding) | after notifications | AuthField, AppleButton, GoogleButton | ✅ `EmailAuthView` |
| 5 | **Profile setup** | name · bio · spice comfort | auth flips → `.needsProfile` | TextField, SpicePicker | ✅ `ProfileSetupView` (🟡 spice = stock Picker) |
| 6 | **Invite friends** ⭐ | **mandatory gate — add/invite ≥ 5** before entering | after profile setup | ContactRow, InviteCounter, SearchField, BrandCTAButton | ⬜ (see §6) |

### 4.2 Today (tab)
| Screen | Purpose | Reached via | Key components | Status |
|---|---|---|---|---|
| **Today** | today's prompt + people you can answer about; your own post's spice control | tab | PromptCard, SpicePicker, TargetRow, EmptyState | ✅ `TodayView` (🟡 controls inline) |
| **Answer** | compose a reply (public/private, char cap) | tap a person → sheet | TextEditor, PublicPrivateToggle, CharCounter, PrimaryButton | ✅ `AnswerView` |

### 4.3 People / Connections (tab)
| Screen | Purpose | Reached via | Key components | Status |
|---|---|---|---|---|
| **Connections** | your people + viewer/replier role + swipe revoke/block | tab | ConnectionRow (role chip), EmptyState | ✅ `ConnectionsView` |
| **Add connection** | search by name → add as viewer/replier | "+" → sheet | SearchField, PersonRow | ✅ `AddConnectionView` |
| **Invite (contacts)** | re-open the contacts/invite flow anytime | "+" / "Invite" → sheet | ContactRow, InviteCounter | ⬜ (shares §6) |

### 4.4 Activity (tab)
| Screen | Purpose | Reached via | Key components | Status |
|---|---|---|---|---|
| **Activity** | reverse-chron event feed: "your gist is ready", "X made you a replier", reveals, directed nudges ("3 friends waiting on you"), graduations | tab | ActivityRow, EmptyState, Avatar | ⬜ `ActivityView` |

### 4.5 You / Profile (tab)
| Screen | Purpose | Reached via | Key components | Status |
|---|---|---|---|---|
| **My Profile** | hero current gist + archive by prompt + pre-grad counters + gear→Settings | tab | GistCard, PostRow, CounterBadge, SectionHeader | ✅ `ProfileView` |
| **Post detail** | the gist + see-more (attributed) + private markers + curate (owner hide / author reveal) + share | tap a graduated post | GistCard, ReplyRow, PrivateMarkerRow, ToneTag, StaleBadge | ✅ `PostDetailView` |
| **Gist evolution** | "then vs now" version timeline | from Post detail | TimelineRow, GistCard | ✅ `GistEvolutionView` |
| **Share card** | screenshot-ready gist card + ShareLink | share button → sheet | GistShareCard, ShareLink | ✅ `GistShareView` |
| **Someone's profile** | another person's graduated gists + reciprocity hook | from People / Activity / deep link | GistCard, PostRow | ✅ `ProfileView(ownerId:)` |
| **Settings** (+ sub-screens) | account, defaults, notifications, privacy, about, danger zone | gear in nav bar | grouped list, see §5 | ⬜ |

---

## 5. Settings screen (spec)

Reached from a **gear icon** in the **You** tab. Grouped list; destructive rows confirm before acting.

- **Account** — Edit profile (name, photo, bio, IG handle); verification (email shown, phone status + "Verify phone" when phone OTP lands).
- **Your defaults** — **Default spice level** (the comfort ceiling: wholesome ▸ playful ▸ social ▸ spicy; mirrors `users.default_spice_level`).
- **Notifications** — master toggle + per-category (gist ready, gist evolved, made-a-replier, nudges); "Open iOS Settings" if system permission is off.
- **Privacy & safety** — **Blocked users** (list, unblock); who can add you (later); report history (later).
- **About** — How Grapevine works · Community guidelines (modest, plain moderation copy, README #5) · Terms · Privacy policy · version.
- **Danger zone** — **Sign out** (confirm) · **Delete account** (confirm; explains data removal).

**Sub-screens:** Edit Profile ⬜ · Notification Preferences ⬜ · Default Spice ⬜ · Blocked Users ⬜ · About/Legal ⬜.

---

## 6. Invite friends — mandatory activation gate (spec) ⭐

The most important onboarding moment (PRODUCT.md §6.1): the app can't graduate a post without enough repliers, so **first-run does not complete until you've added/invited a minimum.**

**Gate rule**
- **Minimum = 5** added-or-invited people (tunable 3–5). Rationale: graduation threshold is `clamp(ceil(0.5 × repliers), 3, 10)` — at 5 repliers it's 3, so 3 of 5 answering graduates your first post. The **"Continue"** CTA stays disabled until the counter hits the minimum; there is **no skip**.
- Counts toward the minimum: **existing Grapevine users you add** (become repliers immediately) **+ invites sent** to non-users (pending until they join). A progress chip shows e.g. "3 / 5".

**Three ways to add, on one screen**
1. **Import from contacts** — the primary path. Request the system **Contacts permission**; match contacts already on Grapevine (show "on Grapevine" rows to add) and list the rest to **invite via SMS/share link**.
2. **Search by name** — find people on Grapevine directly (reuses `AddConnectionView` logic).
3. **Invite link** — share a deep link via the system share sheet (counts as a pending invite).

**Privacy (non-negotiable — this is what got comparable apps delisted; see `docs/research/market-research.md`)**
- Contacts are accessed **only after an explicit, in-context permission prompt** that says why ("to help you find and invite friends").
- **Do not silently upload the whole address book.** Match locally or hash-match minimally; don't store contacts without consent. (Sarahah was pulled from both app stores for silently slurping contacts.)
- Inviting is opt-in per person; no bulk auto-invite.

**Components:** `ContactRow` (avatar, name, "on Grapevine" badge or "Invite"), `InviteCounter` (progress to minimum), `SearchField`, `PersonRow`, `BrandCTAButton`. Lives at `Features/Onboarding/InviteFriendsView.swift` (reusable from the People tab too).

---

## 7. Custom component library

Build screens from these, not stock controls, for a consistent Grapevine look. Several already exist inline and should be **extracted** into reusable pieces (🟡).

**Foundations**
| Component | Role | Status |
|---|---|---|
| `Theme` | brand palette, gradient, corner radius | ✅ |
| `BrandBackground` | purple→pink gradient surface (splash, onboarding, hero, share) | 🟡 (via `Theme.brandGradient`) |

**Buttons** — `BrandCTAButton` ✅ · `PrimaryButton` ✅ · `SecondaryButton` / `DestructiveButton` ⬜

**Cards & rows**
| `GistCard` | hero portrait (verdict + body) — profile, post detail, evolution | 🟡 |
| `GistShareCard` | the screenshot/story artifact | ✅ |
| `PromptCard` | today's prompt display | 🟡 |
| `PostRow` | archive entry (prompt + status/counter) | ✅ `PostRowView` |
| `ReplyRow` | attributed reply, owner-hide swipe | ✅ `ReplyRowView` |
| `PrivateMarkerRow` | "🔒 Sarah left a private reply" | 🟡 |
| `ConnectionRow` | person + role chip + swipe revoke/block | 🟡 |
| `TargetRow` | a person you can answer about (Today) | 🟡 |
| `ContactRow` | contact: avatar, name, "on Grapevine" badge / Invite | ⬜ |
| `ActivityRow` | one event in the Activity feed | ⬜ |
| `PersonRow` | generic person row (search, blocked list) | ⬜ |

**Inputs** — `SpicePicker` ⬜ · `PublicPrivateToggle` 🟡 · `DOBPicker` 🟡 · `SearchField` 🟡 · `AuthField` 🟡

**Indicators & misc**
| `CounterBadge` / `GraduationProgress` | "8 / 10 · needs 2 more" | 🟡 |
| `InviteCounter` | progress to the invite minimum ("3 / 5") | ⬜ |
| `ToneTag` / `SpiceBadge` | a post's spice level | ⬜ |
| `StaleBadge` | "based on fewer voices now" | ⬜ |
| `Avatar` | initials/photo circle | ⬜ |
| `PageDots` | onboarding carousel dots | 🟡 |
| `SectionHeader` | grouped-list headers | ⬜ |
| `EmptyState` | friendly empty placeholders | ⬜ |

---

## 8. Open decisions

1. **Invite minimum** — locked at **5** (tunable 3–5). Confirm the number; and whether **pending invites** (non-users) count toward it or only on-platform adds.
2. **Contacts matching** — how to detect which contacts are already on Grapevine (needs a phone/email → user lookup, privacy-guarded). Server endpoint + hashing approach TBD.
3. **Activity feed source** — backed by the notifications table (Milestone C); until that exists, Activity can start as a thin derived view (your posts' status changes + new repliers).
4. **Component extraction pass** — lift the inline pieces (🟡) into `DesignSystem/` before building Settings / Activity / Invite so they compose consistently.

---

*Surface map only — `PRODUCT.md` owns behavior, `GIST.md` the gist, `ROADMAP.md` the build order. New screens land under `WhoAmI/WhoAmI/Features/<Area>/`, new components under `WhoAmI/WhoAmI/DesignSystem/` (see `STRUCTURE.md`).*
