# Health Tracker

Personal health tracker: logs meals, workouts, sleep, weight and steps to a local
SQLite database, then asks Google Gemini (free tier) what to eat next based on the
day's data and a fixed muscle/weight-gain goal.

## Setup

```bash
cd health_tracker
flutter create .          # generates android/ ios/ etc. for this package
flutter pub get
```

Add an `INTERNET` permission is already default on Android. On macOS/iOS enable
outbound network in the entitlements if you target those.

## Run

Pass your API key at build time (never commit it):

```bash
flutter run --dart-define=GEMINI_API_KEY=your_key_here
```

Get a free Gemini key at https://aistudio.google.com/app/apikey

## Structure

```
lib/
  models/models.dart              data classes + DailySummary
  database/database_helper.dart   sqflite open + schema (v1)
  database/health_repository.dart CRUD for every table
  services/health_goal.dart       hardcoded goal
  services/gemini_service.dart    REST call to Gemini (no fallback)
  providers/health_provider.dart  Provider state
  screens/                        Home, LogEntry, History, Suggestion
  widgets/summary_widgets.dart    reusable summary card/tiles
```

## Notes

- No auth, no backend — fully local plus a direct API call.
- Sleep/weight/steps keep one row per day (re-saving replaces it); meals and
  workouts allow multiple per day.
- AI failures surface as "couldn't get suggestion, try again" with a retry button.
- Every suggestion is saved to `suggestion_history`.
# Health-tracker
