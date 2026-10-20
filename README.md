# SpikeScore

A fast, offline-first digital scoresheet for volleyball, built around the
[Berkshire Volleyball Association](https://www.berkshirevolleyball.org.uk) paper scoresheet.

> **Status:** Planning / Stage 1 (single-device table app). Nothing here is
> ready for real matches yet.

## Why

Filling in the paper scoresheet is slow and error-prone: crossing off points,
tracking service rounds and rotations, recording substitutions and time-outs,
and answering "who serves next?" mid-rally. This project aims to make scoring
quicker than paper, remove arithmetic and rotation mistakes, and produce a
PDF that matches the official sheet, so the process can become paperless.

**Design rule:** if it is ever slower than paper at the table, it has failed.
Every scoring tap is applied locally and instantly. Networking never blocks
the scorer.

## How it works

The match is stored as a list of **events** (point scored, substitution,
time-out, sanction, and so on). Everything on the sheet is calculated from
that list:

- running score and crossed-off points
- service-round boxes (the serving team's score when their run ends)
- rotations and next server
- substitution and time-out counts and the score at each
- set and match results

Undo removes the last event, and corrections never corrupt the sheet.

## Planned features

### Roles (Stage 2)

| Role | Purpose |
|---|---|
| **Table** | Scores the match live: points, serve, subs, time-outs, sanctions |
| **Coach / Captain** | Enters teamsheet and line-ups by player number; feeds the table and second ref |
| **Second ref** | Read-only view of the receiving team's rotation |
| **Admin** | Manages league data (teams, rosters, fixtures, officials) |

Devices join the same match using a short session code. The table role is
protected by a separate PIN. Admin requires a real login.

### Table screen

- Score buttons for left and right team
- Choose which team serves first
- "Next server" box
- Time-out: pick team, then a 30-second timer
- Substitution: pick team, player out, player in (only the original starter can return)
- Undo
- PDF export matching the BVA scoresheet

## Rules assumptions

These reflect current BVA practice and are configurable where noted.

- Rally scoring: sets to 25, win by 2
- Best of 3 sets (configurable to best of 5)
- 1-1 result: defaults to a third set, with options for "draw" or "TBC" to resolve later
- Two time-outs per team per set
- Each starting position may be substituted twice; only the original starter can return
- The libero is not tracked on the sheet (assumed to replace the middle in the back row when not serving)

## Architecture

```
src/
  Volley.Core        Events, rules and match state. No UI, no network.
  Volley.Web         Blazor WebAssembly PWA (offline-capable table screen)
  Volley.Server      (Stage 2) ASP.NET Core + SignalR + PostgreSQL
tests/
  Volley.Core.Tests  xUnit tests for the rules engine
```

- **Language:** C# (.NET)
- **Front end:** Blazor WebAssembly as an installable PWA
- **Local storage:** IndexedDB, saved after every event
- **Real-time sync (Stage 2):** SignalR
- **Database (Stage 2):** PostgreSQL via EF Core (Npgsql)
- **PDF:** QuestPDF

The same `Volley.Core` library runs on the device and the server, so the
rules are identical everywhere.

## Getting started

Prerequisites: the current .NET SDK and Git.

```bash
git clone <repo-url>
cd BVA-Volleyball-Scorer
dotnet build
dotnet test
dotnet run --project src/Volley.Web
```

## Roadmap

1. **Stage 1: single-device table app.** Rules engine with tests, table screen,
   offline PWA, PDF output. Validate against paper at a real match.
2. **Stage 2: sessions.** Join codes, coach line-up screen, second ref view,
   PostgreSQL, CSV import for league data.
3. **Stage 3: admin and polish.** Admin screens only if CSV editing proves
   painful, plus reporting and league tables.

Stage 1 gate: scoring with the app must be clearly faster than paper and the
PDF must match the official sheet. If not, stop and rethink before building more.

## Testing

Real completed scoresheets are used as test fixtures: the full event list is
replayed and the engine's output (service rounds, set scores, totals) is
compared with what was written on paper.

## Data protection

Rosters contain personal data and may include under-18s. Store only what is
needed, restrict who can see it, and delete old data. Agree with the
association who is responsible for the data before going live.

Do not commit real match data, rosters, or scanned scoresheets to this repository.

## Contributing

Issues and ideas are welcome. Please open an issue before starting large changes.

## Licence

To be decided.
