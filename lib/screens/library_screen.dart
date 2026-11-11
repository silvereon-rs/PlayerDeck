import 'package:flutter/material.dart';
import '../models.dart';
import '../main.dart';
import '../services/image_proxy.dart';

const String kSteamSvgString = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 248 248" width="248" height="248"><path fill="#FFFFFF" d="M124.004 0C55.518 0 0 55.518 0 124.004c0 56.974 38.371 104.843 91.082 119.145l26.356-38.175c-5.814-2.71-10.463-7.362-13.175-13.176l-24.417-10.082C72.062 185.65 64 175.962 64 164.726c0-16.035 13.02-29.055 29.055-29.055h1.162l30.62-44.185c-.387-1.937-.775-4.263-.775-6.2 0-25.71 20.817-46.527 46.527-46.527s46.527 20.817 46.527 46.527-20.817 46.527-46.527 46.527c-1.938 0-3.876-.388-6.201-.775L118.19 177.135v1.162c0 16.035-13.02 29.055-29.055 29.055-7.364 0-13.953-2.713-18.992-7.364l-37.595-15.504C50.001 222.477 84.11 248.008 124.004 248.008c68.486 0 124.004-55.518 124.004-124.004S192.49 0 124.004 0zm44.573 62.012c17.131 0 31.007 13.876 31.007 31.007s-13.876 31.007-31.007 31.007-31.007-13.876-31.007-31.007 13.876-31.007 31.007-31.007zm0 15.503c-8.566 0-15.503 6.938-15.503 15.504s6.937 15.504 15.503 15.504 15.504-6.938 15.504-15.504-6.938-15.504-15.504-15.504z"/></svg>''';

class LibraryScreen extends StatefulWidget {
  final List<Game> games;
  final Function(Game game) onSelectGame;
  final VoidCallback onAddGameRequested;

  const LibraryScreen({
    super.key,
    required this.games,
    required this.onSelectGame,
    required this.onAddGameRequested,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _searchQuery = '';
  GamePlatform? _selectedPlatform;
  GameStatus? _selectedStatus;
  bool _onlyFavorites = false;
  bool _isGridView = true;
  String _sortBy = 'lastPlayed'; // 'lastPlayed', 'title', 'hours', 'metacritic'

  @override
  Widget build(BuildContext context) {
    final accentColor = AccentColorScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStatusVal = _onlyFavorites ? 'fav' : (_selectedStatus?.name ?? 'all');

    // Filter Logic
    List<Game> filteredGames = widget.games.where((game) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final titleMatch = game.title.toLowerCase().contains(query);
        final genreMatch = game.genre.toLowerCase().contains(query);
        final devMatch = game.developer.toLowerCase().contains(query);
        if (!titleMatch && !genreMatch && !devMatch) return false;
      }

      if (_selectedPlatform != null && game.platform != _selectedPlatform) {
        return false;
      }

      if (_selectedStatus != null && game.status != _selectedStatus) {
        return false;
      }

      if (_onlyFavorites && !game.isFavorite) {
        return false;
      }

      return true;
    }).toList();

    // Sort Logic
    filteredGames.sort((a, b) {
      if (_sortBy == 'title') {
        return a.title.compareTo(b.title);
      } else if (_sortBy == 'hours') {
        return b.hoursPlayed.compareTo(a.hoursPlayed);
      } else if (_sortBy == 'metacritic') {
        return b.metacriticScore.compareTo(a.metacriticScore);
      } else {
        return b.lastPlayed.compareTo(a.lastPlayed);
      }
    });

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              // Dropdown 1: Status / Games Filter
              Expanded(
                child: _PillDropdown<String>(
                  label: _onlyFavorites ? '⭐ Favorites' : (_selectedStatus?.displayName ?? 'All Games'),
                  value: currentStatusVal,
                  items: [
                    const PillDropdownItem(value: 'all', label: 'All Games'),
                    const PillDropdownItem(value: 'fav', label: '⭐ Favorites'),
                    ...GameStatus.values.map((s) => PillDropdownItem(value: s.name, label: s.displayName)),
                  ],
                  onChanged: (val) {
                    setState(() {
                      if (val == 'all') {
                        _selectedStatus = null;
                        _onlyFavorites = false;
                      } else if (val == 'fav') {
                        _selectedStatus = null;
                        _onlyFavorites = true;
                      } else {
                        _onlyFavorites = false;
                        _selectedStatus = GameStatus.values.firstWhere((s) => s.name == val);
                      }
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Dropdown 2: Platform Filter
              Expanded(
                child: _PillDropdown<GamePlatform?>(
                  label: _selectedPlatform?.displayName ?? 'All Platforms',
                  value: _selectedPlatform,
                  items: [
                    const PillDropdownItem<GamePlatform?>(value: null, label: 'All Platforms'),
                    ...GamePlatform.values.map((p) => PillDropdownItem<GamePlatform?>(value: p, label: p.displayName)),
                  ],
                  onChanged: (val) => setState(() => _selectedPlatform = val),
                ),
              ),
              const SizedBox(width: 8),

              // Action 1: Grid/List View Toggle Button
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF252A2B),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  tooltip: 'Toggle View',
                  icon: Icon(
                    _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => setState(() => _isGridView = !_isGridView),
                ),
              ),
              const SizedBox(width: 8),

              // Action 2: Sort Options Button
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF252A2B),
                  shape: BoxShape.circle,
                ),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  tooltip: 'Sort Options',
                  icon: const Icon(Icons.sort_rounded, color: Colors.white),
                  onSelected: (val) => setState(() => _sortBy = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'lastPlayed', child: Text('Sort by: Recently Played')),
                    const PopupMenuItem(value: 'title', child: Text('Sort by: Title A-Z')),
                    const PopupMenuItem(value: 'hours', child: Text('Sort by: Most Hours Played')),
                    const PopupMenuItem(value: 'metacritic', child: Text('Sort by: Metacritic Rating')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Control (Pill-shaped #252A2B Container)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF252A2B),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                hintText: 'Search title, genre, or developer...',
                hintStyle: const TextStyle(color: Colors.white54, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.white70),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Color(0xFF7F9D9D), width: 1.5),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 8),

          // Main Game Collection Display
          Expanded(
            child: filteredGames.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videogame_asset_off_outlined, size: 64, color: isDark ? Colors.white30 : Colors.black26),
                        const SizedBox(height: 16),
                        const Text('No games found matching filters.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: widget.onAddGameRequested,
                          icon: const Icon(Icons.add),
                          label: const Text('Add New Game'),
                        ),
                      ],
                    ),
                  )
                : _isGridView
                    ? GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.50,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: filteredGames.length,
                        itemBuilder: (context, index) {
                          final game = filteredGames[index];
                          return _buildGameGridCard(context, game, accentColor, isDark);
                        },
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredGames.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final game = filteredGames[index];
                          return _buildGameListTile(context, game, accentColor, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGridCard(BuildContext context, Game game, Color accentColor, bool isDark) {
    return GestureDetector(
      onTap: () => widget.onSelectGame(game),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 460 / 215, // Steam official header thumbnail ratio
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedGameImage(
                    imageUrl: game.coverUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: game.platform.color,
                      child: Icon(game.platform.iconData, color: Colors.white, size: 36),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(game.status.icon, size: 11, color: game.status.badgeColor),
                          const SizedBox(width: 4),
                          Text(
                            game.status.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: game.platform == GamePlatform.steam
                        ? Image.asset(
                            'assets/small_steam_icon_logo.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.sports_esports,
                              size: 20,
                              color: Colors.white,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: game.platform.color.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              game.platform.displayName,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            game.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        if (game.isFavorite)
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${game.hoursPlayed.toStringAsFixed(1)} hrs',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameListTile(BuildContext context, Game game, Color accentColor, bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => widget.onSelectGame(game),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 64,
            child: CachedGameImage(
              imageUrl: game.coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 64,
                color: game.platform.color,
                child: Icon(game.platform.iconData, color: Colors.white),
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(game.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (game.isFavorite) const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
          ],
        ),
        subtitle: Row(
          children: [
            if (game.platform == GamePlatform.steam)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Image.asset(
                  'assets/small_steam_icon_logo.png',
                  width: 14,
                  height: 14,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(game.platform.iconData, size: 14, color: game.platform.color),
                ),
              )
            else
              Text(
                '${game.platform.displayName} • ',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
              ),
            Text(
              '${game.status.displayName} • ${game.hoursPlayed.toStringAsFixed(1)} hrs',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class PillDropdownItem<T> {
  final T value;
  final String label;
  const PillDropdownItem({required this.value, required this.label});
}

class _PillDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<PillDropdownItem<T>> items;
  final ValueChanged<T> onChanged;

  const _PillDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Theme(
          data: Theme.of(context).copyWith(
            popupMenuTheme: PopupMenuThemeData(
              color: const Color(0xFF252A2B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              menuPadding: const EdgeInsets.all(4),
            ),
          ),
          child: PopupMenuButton<T>(
            tooltip: '',
            offset: const Offset(0, 48),
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              maxWidth: constraints.maxWidth,
            ),
            onSelected: onChanged,
            itemBuilder: (context) {
              return items.map((item) {
                final isSelected = item.value == value;
                return PopupMenuItem<T>(
                  value: item.value,
                  height: 38,
                  padding: EdgeInsets.zero,
                  child: Container(
                    width: double.infinity,
                    height: 36,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF7F9D9D) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                );
              }).toList();
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF252A2B),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
