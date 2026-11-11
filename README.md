# PlayerDeck

A cross-platform Flutter game library aggregator and tracker for organizing your collection across PC and console platforms in one unified deck.

## Features

- **Unified Dashboard (`Deck`)** — View total playtime, completed game count, recently played titles, currently playing & backlog counts, a 6-month gaming activity heatmap, platform distribution bar, and friend activity feed.
- **Library Management (`Library`)** — Browse your games in Grid or List view, search by title/genre/developer, filter by status, favorites, or platform, and sort by recently played, title, hours played, or Metacritic score.
- **Game Details & Tracking** — Track hours played, completion status (`Currently Playing`, `In Backlog`, `Completed`, `Wishlist`, `Abandoned`), personal ratings, notes, achievements, and HowLongToBeat estimates.
- **Steam Account Connect & Sync** — Import your real Steam library and playtime using your SteamID64, Custom URL, profile link, Steam2/Steam3 ID, and your personal Steam Web API Key. Supports **Sync All** while preserving local status, ratings, notes, and favorites.
- **Multi-Source Cover & Icon Resolution** — Automatically resolves classic and hashed Steam Store assets, community logos, and icons across Steam CDNs, SteamCMD/PICS metadata (`api.steamcmd.net`), Steam `IStoreBrowseService`, and Store `appdetails`.
- **Epic Games & Custom Platforms** — Connect Epic Games via OAuth authorization code exchange or track GOG Galaxy, PlayStation, Xbox, Nintendo, and custom PC games.
- **Local Persistence & JSON Backup** — Saves library, profile, and account settings locally via `SharedPreferences` and supports JSON library export/import.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.12.0`)

### Installation

```bash
flutter pub get
```

### Running on Desktop / Mobile

```bash
flutter run -d windows
```

### Running on Flutter Web (with Local CORS Proxy)

Browsers block direct cross-origin requests to Steam's Web API (`api.steampowered.com` / `steamcommunity.com`). PlayerDeck includes a lightweight local CORS proxy in `tool/cors_proxy.dart` for local Web development:

1. Start the local CORS proxy in one terminal:
   ```bash
   dart run tool/cors_proxy.dart
   ```
   This starts the proxy at `http://127.0.0.1:9999` (and `http://localhost:9999`).

2. Run the Flutter Web app in another terminal:
   ```bash
   flutter run -d chrome
   ```

## Connecting Steam

1. Open the **Settings** tab in PlayerDeck and toggle **Steam** on.
2. Enter your **SteamID64** (e.g. `7656119...`), **Custom URL** name, or full Steam Community profile URL.
3. Enter your personal **Steam Web API Key** (you can generate one at [steamcommunity.com/dev/apikey](https://steamcommunity.com/dev/apikey)).
4. Make sure your Steam **Profile** and **Game details** privacy settings are set to **Public**, then click **Connect & Import**.

## Testing

Run the unit and widget test suite:

```bash
flutter test
```

## Project Structure

```text
lib/
├── main.dart                     # App entry point, theming, and initialization
├── app_shell.dart                # Floating bottom navigation bar, page view, sync/import state
├── models.dart                   # Game, PlatformAccount, Achievement, FriendActivity models
├── cloud_sync.dart               # Local persistence & JSON backup export
├── profile_store.dart            # Gamer profile & avatar storage
├── screens/
│   ├── dashboard_screen.dart     # Deck analytics, recent games, activity calendar
│   ├── library_screen.dart       # Searchable/filterable Grid & List library view
│   ├── game_detail_screen.dart   # Game metadata, playtime controls, notes, HLTB info
│   ├── settings_screen.dart      # Profile, connected platforms, backups, sign out
│   ├── platforms_screen.dart     # Platform account management screen
│   ├── steam_login_dialog.dart   # Steam ID + Web API key connection dialog
│   └── add_edit_game_dialog.dart # Manual add/edit game modal
└── services/
    ├── steam_api_service.dart    # Steam Web API, identifier parsing, Web CORS proxy routing
    ├── image_proxy.dart          # Image caching & multi-source Steam artwork fallbacks
    ├── epic_api_service.dart     # Epic Games OAuth & entitlements import
    └── hltb_service.dart         # HowLongToBeat lookup service
tool/
└── cors_proxy.dart               # Local development CORS proxy for Flutter Web
test/
├── steam_api_service_test.dart
├── steam_login_dialog_test.dart
├── image_proxy_test.dart
├── nav_bar_test.dart
└── widget_test.dart
```
