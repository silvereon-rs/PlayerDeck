import 'package:flutter/material.dart';
import 'models.dart';
import 'cloud_sync.dart';
import 'profile_store.dart';
import 'main.dart';
import 'screens/dashboard_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/game_detail_screen.dart';
import 'screens/add_edit_game_dialog.dart';
import 'services/steam_api_service.dart';
import 'services/riot_api_service.dart';

class AppShell extends StatefulWidget {
  final void Function(Color) onAccentChanged;
  final void Function(Color) onAccentSaved;
  final List<Color> recentColors;
  final bool isDarkMode;
  final void Function(bool) onToggleDarkMode;

  const AppShell({
    super.key,
    required this.onAccentChanged,
    required this.onAccentSaved,
    required this.recentColors,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  late PageController _pageController;

  List<Game> _games = [];
  List<PlatformAccount> _accounts = [];
  List<FriendActivity> _activities = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadLibraryData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<PlatformAccount> _ensureAllPlatformsExist(List<PlatformAccount> existing) {
    final Map<GamePlatform, PlatformAccount> map = {
      for (var acc in existing) acc.platform: acc,
    };
    final now = DateTime.now();
    final allPlatforms = [
      GamePlatform.steam,
      GamePlatform.riot,
      GamePlatform.gog,
      GamePlatform.epic,
      GamePlatform.psn,
      GamePlatform.xbox,
      GamePlatform.nintendo,
    ];
    for (var p in allPlatforms) {
      if (!map.containsKey(p)) {
        map[p] = PlatformAccount(
          platform: p,
          username: '',
          avatarUrl: '',
          isConnected: false,
          lastSynced: now,
          totalGamesCount: 0,
        );
      }
    }
    return allPlatforms.map((p) => map[p]!).toList();
  }

  Future<void> _loadLibraryData() async {
    final savedData = await CloudSync.loadLibraryFromLocal();
    if (savedData != null && savedData['games'] != null) {
      try {
        final gList = (savedData['games'] as List)
            .map((e) => Game.fromJson(e))
            .toList();
        final aList = (savedData['accounts'] as List)
            .map((e) => PlatformAccount.fromJson(e))
            .toList();
        final actList = (savedData['activities'] as List)
            .map((e) => FriendActivity.fromJson(e))
            .toList();
        setState(() {
          _games = gList;
          _accounts = _ensureAllPlatformsExist(aList);
          _activities = actList;
        });
        return;
      } catch (_) {}
    }

    // Start with default disconnected platform accounts
    setState(() {
      _games = [];
      _accounts = getDisconnectedDefaultAccounts();
      _activities = [];
    });
    _saveLibraryData();
  }

  Future<void> _saveLibraryData() async {
    await CloudSync.saveLibraryToLocal(_games, _accounts, _activities);
  }

  void _onGameUpdated(Game updatedGame) {
    setState(() {
      final index = _games.indexWhere((g) => g.id == updatedGame.id);
      if (index >= 0) {
        _games[index] = updatedGame;
      } else {
        _games.insert(0, updatedGame);
      }
    });
    _saveLibraryData();
  }

  void _onGameDeleted(String gameId) {
    setState(() {
      _games.removeWhere((g) => g.id == gameId);
    });
    _saveLibraryData();
  }

  void _openAddGameDialog() async {
    final newGame = await showModalBottomSheet<Game>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddEditGameDialog(),
    );
    if (newGame != null) {
      _onGameUpdated(newGame);
    }
  }

  void _openGameDetail(Game game) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameDetailScreen(
          game: game,
          onGameUpdated: _onGameUpdated,
          onGameDeleted: () => _onGameDeleted(game.id),
        ),
      ),
    );
  }

  Future<String?> _syncAllPlatforms() async {
    final syncedParts = <String>[];

    final steamIdx = _accounts.indexWhere(
      (a) => a.platform == GamePlatform.steam && a.isConnected,
    );
    if (steamIdx >= 0) {
      final steamAcc = _accounts[steamIdx];
      final targetId = steamAcc.accountId.isNotEmpty
          ? steamAcc.accountId
          : steamAcc.username;
      if (targetId.isNotEmpty) {
        final result = await SteamApiService.importSteamLibrary(
          targetId,
          apiKey: steamAcc.apiKey,
        );
        final fetchedGames = result['games'] as List<Game>;
        steamAcc.username = result['username'] as String;
        steamAcc.avatarUrl = result['avatarUrl'] as String;
        steamAcc.accountId = result['steamId64'] as String;
        steamAcc.lastSynced = DateTime.now();
        steamAcc.totalGamesCount = fetchedGames.length;
        _onPlatformLibraryImported(fetchedGames, steamAcc);
        syncedParts.add(
          'Steam (${steamAcc.username}): ${fetchedGames.length} games',
        );
      }
    }

    final riotIdx = _accounts.indexWhere(
      (a) => a.platform == GamePlatform.riot && a.isConnected,
    );
    if (riotIdx >= 0) {
      final riotAcc = _accounts[riotIdx];
      if (riotAcc.username.isNotEmpty && riotAcc.apiKey.isNotEmpty) {
        final result = await RiotApiService.importRiotLibrary(
          riotAcc.username,
          apiKey: riotAcc.apiKey,
          regionCode: riotAcc.region.isNotEmpty ? riotAcc.region : 'na1',
        );
        final fetchedGames = result['games'] as List<Game>;
        riotAcc.username = result['riotId'] as String;
        riotAcc.avatarUrl = (result['avatarUrl'] as String?) ?? '';
        riotAcc.accountId = (result['puuid'] as String?) ?? riotAcc.accountId;
        riotAcc.region = (result['region'] as String?) ?? riotAcc.region;
        riotAcc.lastSynced = DateTime.now();
        riotAcc.totalGamesCount = fetchedGames.length;
        _onPlatformLibraryImported(fetchedGames, riotAcc);
        syncedParts.add(
          'Riot Games (${riotAcc.username}): ${fetchedGames.length} games',
        );
      }
    }

    setState(() {
      final now = DateTime.now();
      for (var acc in _accounts) {
        if (acc.isConnected) {
          acc.lastSynced = now;
        }
      }
    });
    await _saveLibraryData();
    if (syncedParts.isEmpty) return null;
    return 'Synced ${syncedParts.join(' • ')}';
  }

  void _resetToDefaultData() async {
    await ProfileStore.clear();
    setState(() {
      _games = [];
      _accounts = getDisconnectedDefaultAccounts();
      _activities = [];
    });
    await _saveLibraryData();
  }

  void _onPlatformLoggedOut(GamePlatform platform) {
    setState(() {
      final accIdx = _accounts.indexWhere((a) => a.platform == platform);
      if (accIdx >= 0) {
        _accounts[accIdx].isConnected = false;
        _accounts[accIdx].username = '';
        _accounts[accIdx].avatarUrl = '';
        _accounts[accIdx].accountId = '';
        _accounts[accIdx].apiKey = '';
        _accounts[accIdx].region = '';
        _accounts[accIdx].totalGamesCount = 0;
      }
      _games.removeWhere((g) => g.platform == platform);
    });
    _saveLibraryData();
  }

  void _onPlatformLibraryImported(
    List<Game> importedGames,
    PlatformAccount account,
  ) {
    setState(() {
      final accIdx = _accounts.indexWhere(
        (a) => a.platform == account.platform,
      );
      if (accIdx >= 0) {
        _accounts[accIdx] = account;
      } else {
        _accounts.add(account);
      }

      final existingById = {for (final g in _games) g.id: g};
      if (account.platform == GamePlatform.steam) {
        _games.removeWhere(
          (g) =>
              g.platform == GamePlatform.steam && g.id.startsWith('steam_'),
        );
      } else if (account.platform == GamePlatform.riot) {
        _games.removeWhere(
          (g) => g.platform == GamePlatform.riot && g.id.startsWith('riot_'),
        );
      }

      for (final imported in importedGames.reversed) {
        final existing = existingById[imported.id];
        final merged = existing == null
            ? imported
            : Game(
                id: imported.id,
                title: imported.title,
                platform: imported.platform,
                status: (existing.status == GameStatus.backlog &&
                        existing.hoursPlayed == 0 &&
                        imported.hoursPlayed > 0)
                    ? GameStatus.playing
                    : existing.status,
                coverUrl: imported.coverUrl,
                bannerUrl: imported.bannerUrl,
                developer: existing.developer != 'Steam Developer'
                    ? existing.developer
                    : imported.developer,
                publisher: existing.publisher != 'Valve / Steam'
                    ? existing.publisher
                    : imported.publisher,
                releaseYear: existing.releaseYear,
                metacriticScore: existing.metacriticScore,
                personalRating: existing.personalRating,
                hoursPlayed: imported.hoursPlayed,
                lastPlayed: imported.lastPlayed.isAfter(existing.lastPlayed)
                    ? imported.lastPlayed
                    : existing.lastPlayed,
                summary: imported.platform == GamePlatform.riot &&
                        imported.summary.isNotEmpty
                    ? imported.summary
                    : (existing.summary.isNotEmpty
                        ? existing.summary
                        : imported.summary),
                genre: existing.genre != 'PC Gaming'
                    ? existing.genre
                    : imported.genre,
                isFavorite: existing.isFavorite,
                achievements: existing.achievements.isNotEmpty
                    ? existing.achievements
                    : imported.achievements,
                personalNotes: existing.personalNotes,
                extraData: imported.extraData.isNotEmpty
                    ? imported.extraData
                    : existing.extraData,
              );

        final existingIdx = _games.indexWhere((g) => g.id == merged.id);
        if (existingIdx >= 0) {
          _games[existingIdx] = merged;
        } else {
          _games.insert(0, merged);
        }
      }
    });
    _saveLibraryData();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AccentColorScope.of(context);
    final onAccentColor = AccentColorScope.onAccent(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark
        ? Colors.black.withOpacity(0.7)
        : Colors.white.withOpacity(0.7);
    final navBorder = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.black.withOpacity(0.1);

    final screens = [
      DashboardScreen(
        games: _games,
        accounts: _accounts,
        activities: _activities,
        onSelectGame: _openGameDetail,
        onOpenLibrary: () => _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
        onOpenAccounts: () => _pageController.animateToPage(
          2,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ),
      ),
      LibraryScreen(
        games: _games,
        onSelectGame: _openGameDetail,
        onAddGameRequested: _openAddGameDialog,
      ),
      SettingsScreen(
        onAccentChanged: widget.onAccentChanged,
        onAccentSaved: widget.onAccentSaved,
        recentColors: widget.recentColors,
        isDarkMode: widget.isDarkMode,
        onToggleDarkMode: widget.onToggleDarkMode,
        games: _games,
        accounts: _accounts,
        activities: _activities,
        onAccountsUpdated: (accs) {
          setState(() => _accounts = accs);
          _saveLibraryData();
        },
        onSteamLibraryImported: _onPlatformLibraryImported,
        onPlatformLoggedOut: _onPlatformLoggedOut,
        onSyncAllRequested: _syncAllPlatforms,
        onResetDataRequested: _resetToDefaultData,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemCount: screens.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.hasClients &&
                  _pageController.position.haveDimensions &&
                  _pageController.page != null) {
                value = _pageController.page! - index;
                value = (1 - value.abs() * 0.15).clamp(0.85, 1.0);
              }
              return Opacity(
                opacity: value,
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: screens[index],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 48,
            right: 48,
            bottom: 24,
            top: 8,
          ),
          child: Row(
            children: [
              // Main Google Photos Style Flat Floating Dock Bar (Material You Dynamic Theme)
              Expanded(
                child: Container(
                  height: 64,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHigh
                        : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Row(
                    children: [
                      _buildGooglePhotosExpressiveNavItem(
                        0,
                        Icons.sports_esports_rounded,
                        Icons.sports_esports_outlined,
                        'Deck',
                      ),
                      _buildGooglePhotosExpressiveNavItem(
                        1,
                        Icons.collections_bookmark_rounded,
                        Icons.collections_bookmark_outlined,
                        'Library',
                      ),
                      _buildGooglePhotosExpressiveNavItem(
                        2,
                        Icons.settings_rounded,
                        Icons.settings_outlined,
                        'Settings',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Flat Action Button (+) beside navbar
              GestureDetector(
                onTap: _openAddGameDialog,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Theme.of(context).colorScheme.surfaceContainerHigh
                        : Theme.of(context).colorScheme.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_rounded,
                      size: 26,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGooglePhotosExpressiveNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isActive = _currentIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillColor = const Color(0xFF7F9D9D);
    final iconColor = Colors.black;
    final activeTextColor = Colors.black;
    final inactiveIconColor = isDark ? Colors.white : const Color(0xFF1C1C1E);

    return Expanded(
      flex: isActive ? 2 : 1,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: () {
            _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.fastOutSlowIn,
            height: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: isActive ? 16 : 8),
            decoration: BoxDecoration(
              color: isActive ? pillColor : Colors.transparent,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(
              child: isActive
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(activeIcon, size: 24, color: iconColor),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: activeTextColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Icon(inactiveIcon, size: 24, color: inactiveIconColor),
            ),
          ),
        ),
      ),
    );
  }
}
