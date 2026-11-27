# SpikeScore Lite

A free version of the app for people to try, built from the same code.

## Building it

Add `--dart-define=SPIKESCORE_LITE=true` to any build or run command:

```
flutter run --dart-define=SPIKESCORE_LITE=true
flutter build appbundle --dart-define=SPIKESCORE_LITE=true
```

Without the flag you get the full app, exactly as before.

On Android, Lite's app ID is `com.JustG.spikescore.lite` and its name is
"SpikeScore Lite", so it installs next to the full version and keeps its own
saved match.

## What is different

| | Full | Lite |
|---|---|---|
| Teams | Team sheets, names, coaches, officials, CSV/demo data | "Home" and "Away", shirt numbers 1 to 14, starters 1 to 6 |
| Signatures, locking, referee override | Yes | No |
| Output | Official BVA / FIVB scoresheet PDF | Match summary: set scores, set and match times, time-outs, subs, biggest lead, score chart, "copy as text". Marked "Not an official scoresheet" |
| Format | Chosen by the scoresheet | 3 or 5 sets |
| Extras | | Practice match (a finished example match), Full version screen, Send feedback |

Both keep one match at a time: a new match (or the practice match) replaces it.

## Contact address

Feedback and "Contact us" open the email app with a message to
`Edition.contactEmail` in `lib/edition.dart` (spikescore.app@gmail.com). If
the phone has no email app, or the address is blank, they copy the message to
the clipboard instead.
