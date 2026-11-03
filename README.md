# SpikeScore

A fast, offline-first digital scoresheet for volleyball, built around the [Berkshire Volleyball Association](https://www.berkshirevolleyball.org.uk) paper scoresheet.

> **Status:** Working single-device prototype (Stage 1). It scores a full 3-set match and produces a filled-in BVA scoresheet PDF. It has not yet been validated against paper at a real match, so it is not ready for official use.

## Why

Filling in the paper scoresheet is slow and error-prone: crossing off points, tracking service rounds and rotations, recording substitutions and time-outs, and answering "who serves next?" mid-rally. This project aims to make scoring quicker than paper, remove arithmetic and rotation mistakes, and produce a PDF that matches the official sheet, so the process can become paperless.

**Design rule:** if it is ever slower than paper at the table, it has failed. Every scoring tap is applied locally and instantly. Networking never blocks the scorer.

## How it works

The match is stored as a list of **events** (first serve, sides, point scored, substitution, time-out, new set). Everything else is calculated from that list by replaying it:

- running score and set results
- service rounds (the serving team's score when their run ends) and who is serving
- rotations and next server
- substitution and time-out counts and the score at each
- the change of ends in the deciding set
- every box on the scoresheet PDF

Undo removes the last event and replays, so corrections never corrupt the sheet, including undoing the start of a new set.

## Features

### Table screen (built)

- Tap a team's side of the screen to score; the scoreboard is landscape and keeps the screen awake
- Coin toss: choose which team is on the left and who serves first (first set and deciding set only). In other sets the teams swap sides and the other team serves first automatically
- Deciding set: teams change ends at 8 points and the scoreboard flips
- Serving team and "Next server" shown for each team, with rotation handled on every side-out
- Time-outs (two per team per set)
- Substitutions: pick team, player out, player in. Six per set, each starting position may be substituted twice, and only the original starter can return (enforced by the engine)
- Undo, End Set (only once a set is actually finished), Reset Match
- Match formats: local league (3 sets, set 3 to 15) and national league (5 sets, set 5 to 15). Format is locked once the match starts
- The match is saved after every event, so closing the app loses nothing

### Scoresheet PDF (built, 3-set matches only)

"Publish scoresheet (PDF)" on the set-complete and match-complete sheets (and a debug-only button in the app bar) builds the official BVA 3-set sheet and opens the phone's share sheet. The page is the real BVA sheet with the match written on top, and anything the app doesn't know is left blank.

Filled in: team names and A/B letters, player lists and liberos, team officials, match details, starting line-ups in service order, S/R markers, substitutions with the score at each, time-outs with the score, service round scores, points (slashed, last point ringed, unused numbers struck out), the change of ends in set 3, the results table, the winner and the signatures.

Team A is the team that started set 1 on the left.

### Sign-off screen (built)

Drawn signatures for captains and coaches (before the match) and referees, scorers, line judges and captains (after the match). Opened from the pen icon in the app bar.

### Not built yet

- 30-second time-out timer
- Sanctions
- 1-1 result handling ("draw" / "TBC" options)
- Set and match start/end times and durations on the sheet
- A screen for entering teams, line-ups and match details (for now they come from the demo data file, below)
- Several saved matches
- PDF for the 5-set format

### Roles (Stage 2)

| Role                | Purpose                                                                        |
|---------------------|--------------------------------------------------------------------------------|
| **Table**           | Scores the match live: points, serve, subs, time-outs, sanctions               |
| **Coach / Captain** | Enters teamsheet and line-ups by player number; feeds the table and second ref |
| **Second ref**      | Read-only view of the receiving team's rotation                                |
| **Admin**           | Manages league data (teams, rosters, fixtures, officials)                      |

Devices join the same match using a short session code. The table role is protected by a separate PIN. Admin requires a real login.

## Demo data

Teams, players and match details come from one editable file: `app/assets/demo/demo_data.json`.

- `match`: the details printed in the sheet header (competition, venue, date, time, division, category) and which two teams are playing (`home` and `away`, by team `id`)
- `teams`: a library of teams, each with players (shirt number, name, position), the six starters in service order (`startingLineup`) and optional `officials`

Edit the file, save it, then stop the app and run it again. If a team in the file changes, the match saved on the phone is dropped automatically so it can't clash. If the file has a mistake, the app shows an orange message at the top and falls back to built-in teams. The file explains its own fields in the `_readme` section at the top.

The names in the file are made up. Do not put real rosters in it (see Data protection).

## Rules assumptions

These reflect current BVA practice and are configurable where noted.

- Rally scoring: sets to 25, win by 2; the deciding set is played to 15, win by 2
- Best of 3 sets (configurable to best of 5)
- Teams change ends at 8 points in the deciding set
- Two time-outs per team per set
- Six substitutions per team per set; each starting position may be substituted twice; only the original starter can return
- The libero is listed on the sheet but not tracked on court (assumed to replace the middle in the back row when not serving)

## Architecture

```
app/
  lib/
    match_engine.dart      Events, rules, match state and saving. No UI.
    demo_data.dart         Reads the editable teams / match details file
    models.dart            Player, TeamSheet
    screens/
      match_screen.dart    The table screen
      sign_off_screen.dart Drawn signatures
    scoresheet/
      scoresheet_data.dart       Works out what goes on the sheet from the events
      scoresheet_layout.dart     Loads the measured box positions
      scoresheet_pdf.dart        Draws everything onto the blank sheet
      scoresheet_publisher.dart  Builds the PDF and opens the share sheet
      signature_slots.dart       Ids of the signature boxes
  assets/
    demo/demo_data.json
    scoresheet/bva_3set_blank.jpg      The blank BVA sheet, as a picture
    scoresheet/bva_3set_layout.json    Measured position of every box
  test/                    Engine, scoresheet and demo data tests
```

- **Language and framework:** Dart, Flutter (Android first)
- **State:** `provider` with a single `MatchEngine`
- **Local storage:** `shared_preferences`, one JSON value saved after every event (format, events, signatures)
- **PDF:** the `pdf` package builds the page and `printing` shares it
- **Screen:** `wakelock_plus` keeps the display on during a match
- **Real-time sync, database and server (Stage 2):** not started

`bva_3set_layout.json` was measured from the original BVA PDF. If the association changes the sheet, the layout has to be measured again.

## Getting started

Prerequisites: the Flutter SDK, Git, and an Android phone with USB debugging (or an emulator).

```
git clone https://github.com/GDoesCode/SpikeScore.git
cd SpikeScore/app
flutter pub get
flutter test
flutter run
```

In a debug build the app bar also shows a PDF button that publishes the scoresheet at any time, and each finished service round prints a line like `[service] Set 1 Home I #1: 3` to the terminal.

## Roadmap

1. **Stage 1: single-device table app.** Rules engine with tests, table screen, offline, PDF output. *Built; still to do: validate against paper at a real match, time-out timer, sanctions, entering teams and match details in the app.*
2. **Stage 2: sessions.** Join codes, coach line-up screen, second ref view, PostgreSQL, CSV import for league data.
3. **Stage 3: admin and polish.** Admin screens only if CSV editing proves painful, plus reporting and league tables.

Stage 1 gate: scoring with the app must be clearly faster than paper and the PDF must match the official sheet. If not, stop and rethink before building more.

## Testing

```
cd app
flutter test
```

The engine tests cover scoring, serving and rotation, sides and first-serve order, substitutions, time-outs, service rounds and saving. The scoresheet tests cover the data builder (including the change of ends) and PDF generation. The demo data tests check the file reader and the shipped file.

Still to do: replay real completed scoresheets as fixtures. The full event list is replayed and the engine's output (service rounds, set scores, totals) is compared with what was written on paper.

## Data protection

Rosters contain personal data and may include under-18s. Store only what is needed, restrict who can see it, and delete old data. Agree with the association who is responsible for the data before going live.

Drawn signatures are personal data too. They are stored on the phone with the match and cleared by Reset Match.

Do not commit real match data, rosters, or scanned scoresheets to this repository. `assets/demo/demo_data.json` must contain made-up names only.

## BVA scoresheet

The blank sheet image and the BVA logo in `assets/scoresheet/` belong to the Berkshire Volleyball Association. Confirm with the association that they are happy for them to be kept in this repository.

## Contributing

Issues and ideas are welcome. Please open an issue before starting large changes.

## Licence

To be decided.
