import 'package:flutter/material.dart';
import '../models.dart';
import '../main.dart';
import 'add_edit_game_dialog.dart';
import '../services/image_proxy.dart';

class GameDetailScreen extends StatefulWidget {
  final Game game;
  final Function(Game updatedGame) onGameUpdated;
  final VoidCallback onGameDeleted;

  const GameDetailScreen({
    super.key,
    required this.game,
    required this.onGameUpdated,
    required this.onGameDeleted,
  });

  @override
  State<GameDetailScreen> createState() => _GameDetailScreenState();
}

class _GameDetailScreenState extends State<GameDetailScreen> {
  late Game _game;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _game = widget.game;
    _notesController.text = _game.personalNotes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _updateGame(VoidCallback action) {
    setState(() {
      action();
      _game.lastPlayed = DateTime.now();
    });
    widget.onGameUpdated(_game);
  }

  void _addPlaytime(double hours) {
    _updateGame(() {
      _game.hoursPlayed += hours;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${hours > 0 ? "+$hours" : hours} hours of playtime!')),
    );
  }

  void _toggleAchievement(Achievement achievement) {
    _updateGame(() {
      achievement.isUnlocked = !achievement.isUnlocked;
      achievement.unlockDate = achievement.isUnlocked ? DateTime.now() : null;
    });
  }

  void _editGame() async {
    final updated = await showModalBottomSheet<Game>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditGameDialog(gameToEdit: _game),
    );
    if (updated != null) {
      setState(() {
        _game = updated;
      });
      widget.onGameUpdated(updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AccentColorScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Sliver Hero Header with Banner and Title
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedGameImage(
                    imageUrl: _game.bannerUrl.isNotEmpty
                        ? _game.bannerUrl
                        : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: _game.platform.color),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
                          Colors.black.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 80,
                            height: 110,
                            child: CachedGameImage(
                              imageUrl: _game.coverUrl.isNotEmpty
                                  ? _game.coverUrl
                                  : 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=600&auto=format&fit=crop',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 80,
                                height: 110,
                                color: _game.platform.color,
                                child: Icon(_game.platform.iconData, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _game.platform == GamePlatform.steam
                                  ? Image.asset(
                                      'assets/small_steam_icon_logo.png',
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _game.platform.color,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _game.platform.displayName.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _game.platform.color,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _game.platform.displayName.toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 6),
                              Text(
                                _game.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_game.developer} • ${_game.genre} (${_game.releaseYear})',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(
                  _game.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: _game.isFavorite ? Colors.amber : Colors.white,
                ),
                onPressed: () {
                  _updateGame(() {
                    _game.isFavorite = !_game.isFavorite;
                  });
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Colors.white),
                onPressed: _editGame,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (val) {
                  if (val == 'delete') {
                    widget.onGameDeleted();
                    Navigator.pop(context);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        SizedBox(width: 8),
                        Text('Remove from Library', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: 'Playtime',
                          value: '${_game.hoursPlayed.toStringAsFixed(1)} hrs',
                          icon: Icons.timer_outlined,
                          accent: accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: 'Metacritic',
                          value: '${_game.metacriticScore}',
                          icon: Icons.stars_rounded,
                          accent: Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          context,
                          title: 'Genre',
                          value: _game.genre.isNotEmpty ? _game.genre : 'Action',
                          icon: Icons.category_rounded,
                          accent: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Status Dropdown & Favorite
                  Text(
                    'PLAYING STATUS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: GameStatus.values.map((status) {
                      final isSelected = _game.status == status;
                      return ChoiceChip(
                        label: Text(status.displayName),
                        selected: isSelected,
                        selectedColor: status.badgeColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected ? status.badgeColor : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected ? status.badgeColor : (isDark ? Colors.white12 : Colors.black12),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            _updateGame(() => _game.status = status);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Log Playtime Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LOG PLAYTIME SESSION',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildQuickPlayButton('+ 0.5h', () => _addPlaytime(0.5)),
                      const SizedBox(width: 8),
                      _buildQuickPlayButton('+ 1.0h', () => _addPlaytime(1.0)),
                      const SizedBox(width: 8),
                      _buildQuickPlayButton('+ 2.0h', () => _addPlaytime(2.0)),
                      const SizedBox(width: 8),
                      _buildQuickPlayButton('+ 5.0h', () => _addPlaytime(5.0)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Game Overview / Summary
                  Text(
                    'OVERVIEW',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _game.summary.isNotEmpty ? _game.summary : 'No overview available.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Extra Platform Data (e.g. Riot ranked, mastery, matches, stats)
                  if (_game.extraData.isNotEmpty) ...[
                    ..._buildExtraDataSections(context, accentColor, isDark),
                    const SizedBox(height: 24),
                  ],

                  // Achievements Section
                  if (_game.achievements.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ACHIEVEMENTS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                        Text(
                          '${_game.unlockedAchievementsCount} / ${_game.achievements.length} (${(_game.achievementProgress * 100).toInt()}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _game.achievementProgress,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white12 : Colors.black12,
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _game.achievements.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _game.achievements[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            leading: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: item.isUnlocked ? accentColor.withOpacity(0.2) : (isDark ? Colors.white12 : Colors.black12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(item.icon, style: const TextStyle(fontSize: 22)),
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: item.isUnlocked ? TextDecoration.none : TextDecoration.none,
                              ),
                            ),
                            subtitle: Text(
                              '${item.description} • ${item.rarityPercentage}% players',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Checkbox(
                              value: item.isUnlocked,
                              activeColor: accentColor,
                              onChanged: (_) => _toggleAchievement(item),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Personal Notes
                  Text(
                    'PERSONAL NOTES & MEMORIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add thoughts, favorite build, or completion milestones...',
                    ),
                    onChanged: (val) {
                      _updateGame(() => _game.personalNotes = val);
                    },
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String title, required String value, required IconData icon, required Color accent}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2332) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExtraDataSections(
    BuildContext context,
    Color accentColor,
    bool isDark,
  ) {
    final extra = _game.extraData;
    final widgets = <Widget>[];
    final cardColor = isDark ? const Color(0xFF1F2332) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;
    final mutedColor = isDark ? Colors.white60 : Colors.black54;

    widgets.add(
      Text(
        '${_game.platform.displayName.toUpperCase()} ACCOUNT & GAME DATA',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: mutedColor,
        ),
      ),
    );
    widgets.add(const SizedBox(height: 10));

    // 1. Account Profile Card + Key-Value Stats
    final profileIconUrl = extra['profileIconUrl']?.toString() ?? '';
    final riotId = extra['riotId']?.toString() ?? '';
    final region = extra['region']?.toString() ?? '';
    final activeShard = extra['activeShard']?.toString() ?? '';
    final puuid = extra['puuid']?.toString() ?? '';
    final summonerLevel = extra['summonerLevel'];
    final totalMasteryScore = extra['totalMasteryScore'];
    final statsMap = extra['stats'] is Map ? extra['stats'] as Map : null;

    if (riotId.isNotEmpty ||
        profileIconUrl.isNotEmpty ||
        puuid.isNotEmpty ||
        (statsMap != null && statsMap.isNotEmpty)) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (riotId.isNotEmpty || profileIconUrl.isNotEmpty) ...[
                Row(
                  children: [
                    if (profileIconUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 44,
                          height: 44,
                          child: CachedGameImage(
                            imageUrl: profileIconUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(
                              color: _game.platform.color,
                              child: Icon(
                                _game.platform.iconData,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (profileIconUrl.isNotEmpty) const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (riotId.isNotEmpty)
                            Text(
                              riotId,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          if (region.isNotEmpty || activeShard.isNotEmpty)
                            Text(
                              [
                                if (region.isNotEmpty) region,
                                if (activeShard.isNotEmpty) 'Shard: $activeShard',
                                if (summonerLevel != null) 'Lv.$summonerLevel',
                                if (totalMasteryScore != null)
                                  'Mastery $totalMasteryScore',
                              ].join(' • '),
                              style: TextStyle(fontSize: 12, color: mutedColor),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (statsMap != null && statsMap.isNotEmpty) ...[
                if (riotId.isNotEmpty || profileIconUrl.isNotEmpty)
                  const Divider(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: statsMap.entries.map((e) {
                    return SizedBox(
                      width: 150,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key.toString(),
                            style: TextStyle(fontSize: 11, color: mutedColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            e.value?.toString() ?? '--',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (puuid.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'PUUID: $puuid',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: mutedColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
      widgets.add(const SizedBox(height: 14));
    }

    // 2. Ranked Standings
    if (extra.containsKey('ranked') && extra['ranked'] is List) {
      final rankedList = (extra['ranked'] as List).whereType<Map>().toList();
      widgets.add(
        Text(
          'RANKED STANDINGS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: mutedColor,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      if (rankedList.isEmpty) {
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              'Unranked in current split',
              style: TextStyle(fontSize: 13, color: mutedColor),
            ),
          ),
        );
      } else {
        for (final entry in rankedList) {
          final queue = (entry['queue'] ?? 'Ranked').toString();
          final displayRank = (entry['displayRank'] ?? 'Unranked').toString();
          final lp = entry['lp'] ?? 0;
          final wins = entry['wins'] ?? 0;
          final losses = entry['losses'] ?? 0;
          final winRate = (entry['winRate'] ?? '--').toString();
          final hotStreak = entry['hotStreak'] == true;
          final veteran = entry['veteran'] == true;

          widgets.add(
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          queue,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${wins}W ${losses}L ($winRate win rate)',
                          style: TextStyle(fontSize: 12, color: mutedColor),
                        ),
                        if (hotStreak || veteran) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (hotStreak)
                                _buildTagChip('Hot Streak', Colors.orangeAccent),
                              if (veteran)
                                _buildTagChip('Veteran', accentColor),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _game.platform.accentColor.withValues(
                            alpha: 0.16,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          displayRank,
                          style: TextStyle(
                            color: _game.platform.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$lp LP',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }
      }
      widgets.add(const SizedBox(height: 10));
    }

    // 3. Top Mastered Champions
    if (extra['topChampions'] is List &&
        (extra['topChampions'] as List).isNotEmpty) {
      final champs = (extra['topChampions'] as List).whereType<Map>().toList();
      widgets.add(
        Text(
          'TOP CHAMPION MASTERY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: mutedColor,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      for (final c in champs) {
        final name = (c['name'] ?? 'Champion').toString();
        final level = c['level'] ?? 0;
        final points = (c['points'] as num?)?.toInt() ?? 0;
        final iconUrl = (c['iconUrl'] ?? '').toString();
        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                if (iconUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CachedGameImage(
                        imageUrl: iconUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.shield_rounded, size: 22),
                      ),
                    ),
                  )
                else
                  const Icon(Icons.shield_rounded, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                _buildTagChip('Lv.$level', accentColor),
                const SizedBox(width: 8),
                Text(
                  '${_formatPoints(points)} pts',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 10));
    }

    // 4. Recent Matches
    if (extra['recentMatches'] is List &&
        (extra['recentMatches'] as List).isNotEmpty) {
      final matches = (extra['recentMatches'] as List).whereType<Map>().toList();
      widgets.add(
        Text(
          'RECENT MATCHES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: mutedColor,
          ),
        ),
      );
      widgets.add(const SizedBox(height: 8));
      for (final m in matches) {
        final result = (m['result'] ?? '').toString();
        final bool? isWin = m['win'] is bool ? m['win'] as bool : null;
        final Color resultColor = isWin == true
            ? Colors.greenAccent
            : (isWin == false ? Colors.redAccent : accentColor);
        final champion = (m['champion'] ?? '').toString();
        final mode = (m['mode'] ?? '').toString();
        final kda = (m['kda'] ?? '').toString();
        final duration = (m['duration'] ?? '').toString();
        final cs = m['cs'];
        final playedAtRaw = m['playedAt']?.toString() ?? '';
        final playedAt = DateTime.tryParse(playedAtRaw);
        final dateLabel = playedAt != null
            ? '${playedAt.year}-${playedAt.month.toString().padLeft(2, '0')}-${playedAt.day.toString().padLeft(2, '0')}'
            : '';

        final detailParts = <String>[
          if (mode.isNotEmpty) mode,
          if (kda.isNotEmpty) kda,
          if (cs != null) '$cs CS',
          if (duration.isNotEmpty && duration != '--') duration,
          if (dateLabel.isNotEmpty) dateLabel,
        ];

        widgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.isNotEmpty ? result : 'Match',
                    style: TextStyle(
                      color: resultColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (champion.isNotEmpty)
                        Text(
                          champion,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                          ),
                        ),
                      if (detailParts.isNotEmpty)
                        Text(
                          detailParts.join(' • '),
                          style: TextStyle(fontSize: 11.5, color: mutedColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
      widgets.add(const SizedBox(height: 10));
    }

    // 5. Fallback renderer for any additional keys in extraData so all fetched data is visible
    const handledKeys = {
      'riotId',
      'puuid',
      'region',
      'activeShard',
      'summonerLevel',
      'profileIconUrl',
      'totalMasteryScore',
      'stats',
      'ranked',
      'topChampions',
      'recentMatches',
    };
    final remainingEntries = extra.entries
        .where((e) => !handledKeys.contains(e.key) && e.value != null)
        .toList();

    if (remainingEntries.isNotEmpty) {
      widgets.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: remainingEntries.map((entry) {
              final label = entry.key == 'notes'
                  ? 'API Note'
                  : entry.key;
              final valueText = entry.value is Map || entry.value is List
                  ? entry.value.toString()
                  : entry.value.toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      valueText,
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildTagChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatPoints(int points) {
    final s = points.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final revIndex = s.length - i;
      if (i > 0 && revIndex % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  Widget _buildQuickPlayButton(String label, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
