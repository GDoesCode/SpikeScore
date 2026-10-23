# SpikeScore

A fast, offline-first digital scoresheet for volleyball, built around local league and national league rules.

**Status:** Planning / Stage 1 (single-device table app). *Nothing here is ready for real matches yet.*

---

## Why

Filling in the paper scoresheet is slow and error-prone: crossing off points, tracking service rounds and rotations, recording substitutions and time-outs, and answering "who serves next?" mid-rally. This project aims to make scoring quicker than paper, remove arithmetic and rotation mistakes, and produce a digital scoresheet, so the process can become paperless.

> **Design Rule:** If it is ever slower than paper at the table, it has failed. Every scoring tap is applied locally and instantly. Networking never blocks the scorer.

---

## How It Works

The match is stored as an event log (point scored, substitution, time-out, set complete, and so on). Everything on the scoresheet is calculated dynamically from that history:

* Running score and point tracking
* Substitutions and time-out counts (with score at each call)
* FIVB-compliant substitution pairing, locking, and starter re-entry enforcement
* Automatic set and match completion detection with 2-point lead checks
* Set and match results

*Undo removes the last event, and corrections never corrupt the sheet state.*

---

## Planned Features

### Roles (Stage 2)
* **Table:** Scores the match live (points, serve, subs, time-outs).
* **Coach / Captain:** Enters teamsheet and line-ups by player number; feeds the table and second ref.
* **Second Ref:** Read-only view of the receiving team's rotation.
* **Admin:** Manages league data (teams, rosters, fixtures, officials).

*Devices join the same match using a short session code. The table role is protected by a separate PIN. Admin requires a real login.*

### Table Screen
* Native mobile-first landscape scoring interface
* Fast point logging for Home and Away teams
* **Match Format Switcher:** Local League (3 sets, set 3 to 15) vs. National League (5 sets, set 5 to 15)
* Automated deciding-set side-change alerts at 8 points
* Time-out tracking (2 per team per set) with 30-second countdown timer
* Interactive substitution modal workflows: automatic starter re-entry pairing & position exhaustion locks (max 2 subs per position per set)
* Re-entry confirmation dialogs and scoring locks upon set/match completion
* Screen wakelock to keep the display awake during active matches
* Immediate Undo support and full Match Reset options
* PDF export matching official scoresheets

---

## Rules Assumptions

These reflect current league practice and are configurable where noted:

* **Rally Scoring:** Sets to 25, win by 2 (deciding sets to 15, win by 2).
* **Match Formats:** Local League (Best of 3 sets) and National League (Best of 5 sets).
* **Deciding Set Side Change:** Automated alert when either team reaches 8 points in the final set.
* **Time-outs:** Up to two time-outs per team per set.
* **Substitutions:** Up to 6 substitutions per team per set. Each starting position may be substituted twice; only the original starter can return to that same position.
* **Libero:** The libero is not tracked on the sheet (assumed to replace the middle in the back row when not serving).

---

## Architecture

```text
lib/
├── main.dart            # App entry point and theme setup
├── match_engine.dart    # FIVB rules engine, score state, event logging, and persistence
├── models.dart          # Data models for Players, Team Sheets, and Match Events
└── screens/
    └── match_screen.dart # Mobile-optimized, landscape table scoring screen
```

* **Framework:** Flutter / Dart (cross-platform, native mobile-first execution)
* **State Management:** Provider (`ChangeNotifier`)
* **Persistence:** `shared_preferences` (Saved locally after every event)
* **Display Management:** `wakelock_plus` (Prevents screen dimming during active refereeing)

---

## Getting Started

### Prerequisites
* Flutter SDK (latest stable release)
* Dart SDK
* Git

### Running the App

```bash
git clone <repository-url>
cd SpikeScore
flutter pub get
flutter devices
flutter run -d <device-id>
```

---

## Roadmap

1. **Stage 1:** Single-device table app. Native rules engine, responsive landscape table screen, local state persistence, wakelock integration, and PDF output. Validate against paper at a real match.
2. **Stage 2:** Admin/Override Mode for handling mid-match referee corrections, session join codes, coach line-up input screen, second ref view, and league CSV imports.
3. **Stage 3:** Admin dashboards, match reporting, and league table automation.

> **Stage 1 Gate:** Scoring with the app must be clearly faster than paper and the digital output must match the official sheet. If not, stop and rethink before building more.

---

## Testing

Real completed scoresheets are used as test fixtures: the full event list is replayed and the engine's output (service rounds, set scores, totals) is compared with what was written on paper.

---

## Data Protection

* Rosters contain personal data and may include under-18s. Store only what is needed, restrict who can see it, and delete old data. Agree with the association who is responsible for the data before going live.
* **Do not commit real match data, rosters, or scanned scoresheets to this repository.**

---

## Contributing

Issues and ideas are welcome. Please open an issue before starting large changes.

---

## Licence

To be decided.
