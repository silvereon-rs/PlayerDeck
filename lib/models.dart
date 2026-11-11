import 'package:flutter/material.dart';

enum GamePlatform {
  steam,
  riot,
  gog,
  epic,
  psn,
  xbox,
  nintendo,
  custom;

  String get displayName {
    switch (this) {
      case GamePlatform.steam:
        return 'Steam';
      case GamePlatform.riot:
        return 'Riot Games';
      case GamePlatform.gog:
        return 'GOG Galaxy';
      case GamePlatform.epic:
        return 'Epic Games';
      case GamePlatform.psn:
        return 'PlayStation';
      case GamePlatform.xbox:
        return 'Xbox';
      case GamePlatform.nintendo:
        return 'Nintendo';
      case GamePlatform.custom:
        return 'Custom / PC';
    }
  }

  Color get color {
    switch (this) {
      case GamePlatform.steam:
        return const Color(0xFF171A21);
      case GamePlatform.riot:
        return const Color(0xFFD13639);
      case GamePlatform.gog:
        return const Color(0xFF5A177C);
      case GamePlatform.epic:
        return const Color(0xFF202020);
      case GamePlatform.psn:
        return const Color(0xFF003791);
      case GamePlatform.xbox:
        return const Color(0xFF107C41);
      case GamePlatform.nintendo:
        return const Color(0xFFE60012);
      case GamePlatform.custom:
        return const Color(0xFF007A87);
    }
  }

  Color get accentColor {
    switch (this) {
      case GamePlatform.steam:
        return const Color(0xFF7F9D9D);
      case GamePlatform.riot:
        return const Color(0xFFFF4655);
      case GamePlatform.gog:
        return const Color(0xFFD644FF);
      case GamePlatform.epic:
        return const Color(0xFF0078F2);
      case GamePlatform.psn:
        return const Color(0xFF0070D1);
      case GamePlatform.xbox:
        return const Color(0xFF107C41);
      case GamePlatform.nintendo:
        return const Color(0xFFFF3B30);
      case GamePlatform.custom:
        return const Color(0xFF00E5FF);
    }
  }

  IconData get iconData {
    switch (this) {
      case GamePlatform.steam:
        return Icons.sports_esports;
      case GamePlatform.riot:
        return Icons.local_fire_department_rounded;
      case GamePlatform.gog:
        return Icons.auto_awesome;
      case GamePlatform.epic:
        return Icons.bolt;
      case GamePlatform.psn:
        return Icons.gamepad;
      case GamePlatform.xbox:
        return Icons.videogame_asset;
      case GamePlatform.nintendo:
        return Icons.smart_toy;
      case GamePlatform.custom:
        return Icons.desktop_windows;
    }
  }
}

enum GameStatus {
  playing,
  backlog,
  completed,
  wishlist,
  abandoned;

  String get displayName {
    switch (this) {
      case GameStatus.playing:
        return 'Currently Playing';
      case GameStatus.backlog:
        return 'In Backlog';
      case GameStatus.completed:
        return 'Completed';
      case GameStatus.wishlist:
        return 'Wishlist';
      case GameStatus.abandoned:
        return 'Abandoned';
    }
  }

  Color get badgeColor {
    switch (this) {
      case GameStatus.playing:
        return const Color(0xFF9E9E9E);
      case GameStatus.backlog:
        return const Color(0xFFFFB300);
      case GameStatus.completed:
        return const Color(0xFF29B6F6);
      case GameStatus.wishlist:
        return const Color(0xFFAB47BC);
      case GameStatus.abandoned:
        return const Color(0xFFEF5350);
    }
  }

  IconData get icon {
    switch (this) {
      case GameStatus.playing:
        return Icons.play_arrow_rounded;
      case GameStatus.backlog:
        return Icons.bookmark_border_rounded;
      case GameStatus.completed:
        return Icons.check_circle_outline_rounded;
      case GameStatus.wishlist:
        return Icons.favorite_border_rounded;
      case GameStatus.abandoned:
        return Icons.cancel_outlined;
    }
  }
}

class Achievement {
  final String id;
  final String title;
  final String description;
  bool isUnlocked;
  DateTime? unlockDate;
  final double rarityPercentage;
  final String icon;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.isUnlocked = false,
    this.unlockDate,
    this.rarityPercentage = 10.0,
    this.icon = '🏆',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'isUnlocked': isUnlocked,
        'unlockDate': unlockDate?.toIso8601String(),
        'rarityPercentage': rarityPercentage,
        'icon': icon,
      };

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        isUnlocked: json['isUnlocked'] ?? false,
        unlockDate: json['unlockDate'] != null ? DateTime.tryParse(json['unlockDate']) : null,
        rarityPercentage: (json['rarityPercentage'] as num?)?.toDouble() ?? 10.0,
        icon: json['icon'] ?? '🏆',
      );
}

class Game {
  final String id;
  final String title;
  final GamePlatform platform;
  GameStatus status;
  final String coverUrl;
  final String bannerUrl;
  final String developer;
  final String publisher;
  final int releaseYear;
  final int metacriticScore;
  double personalRating; // 1.0 to 5.0
  double hoursPlayed;
  DateTime lastPlayed;
  final String summary;
  final String genre;
  bool isFavorite;
  List<Achievement> achievements;
  String? personalNotes;
  Map<String, dynamic> extraData;

  Game({
    required this.id,
    required this.title,
    required this.platform,
    required this.status,
    required this.coverUrl,
    required this.bannerUrl,
    required this.developer,
    required this.publisher,
    required this.releaseYear,
    required this.metacriticScore,
    this.personalRating = 4.0,
    this.hoursPlayed = 0.0,
    required this.lastPlayed,
    required this.summary,
    required this.genre,
    this.isFavorite = false,
    this.achievements = const [],
    this.personalNotes,
    this.extraData = const {},
  });

  int get unlockedAchievementsCount => achievements.where((a) => a.isUnlocked).length;

  double get achievementProgress =>
      achievements.isEmpty ? 0.0 : unlockedAchievementsCount / achievements.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'platform': platform.name,
        'status': status.name,
        'coverUrl': coverUrl,
        'bannerUrl': bannerUrl,
        'developer': developer,
        'publisher': publisher,
        'releaseYear': releaseYear,
        'metacriticScore': metacriticScore,
        'personalRating': personalRating,
        'hoursPlayed': hoursPlayed,
        'lastPlayed': lastPlayed.toIso8601String(),
        'summary': summary,
        'genre': genre,
        'isFavorite': isFavorite,
        'achievements': achievements.map((a) => a.toJson()).toList(),
        'personalNotes': personalNotes,
        if (extraData.isNotEmpty) 'extraData': extraData,
      };

  factory Game.fromJson(Map<String, dynamic> json) => Game(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        platform: GamePlatform.values.firstWhere(
          (e) => e.name == json['platform'],
          orElse: () => GamePlatform.custom,
        ),
        status: GameStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => GameStatus.backlog,
        ),
        coverUrl: json['coverUrl'] ?? '',
        bannerUrl: json['bannerUrl'] ?? '',
        developer: json['developer'] ?? 'Unknown',
        publisher: json['publisher'] ?? 'Unknown',
        releaseYear: json['releaseYear'] ?? 2024,
        metacriticScore: json['metacriticScore'] ?? 80,
        personalRating: (json['personalRating'] as num?)?.toDouble() ?? 4.0,
        hoursPlayed: (json['hoursPlayed'] as num?)?.toDouble() ?? 0.0,
        lastPlayed: json['lastPlayed'] != null
            ? DateTime.parse(json['lastPlayed'])
            : DateTime.now(),
        summary: json['summary'] ?? '',
        genre: json['genre'] ?? 'Action',
        isFavorite: json['isFavorite'] ?? false,
        achievements: (json['achievements'] as List?)
                ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        personalNotes: json['personalNotes'],
        extraData: json['extraData'] is Map
            ? Map<String, dynamic>.from(json['extraData'] as Map)
            : const {},
      );
}

class PlatformAccount {
  final GamePlatform platform;
  String username;
  String avatarUrl;
  bool isConnected;
  DateTime lastSynced;
  int totalGamesCount;
  String accountId;
  String apiKey;
  String region;

  PlatformAccount({
    required this.platform,
    required this.username,
    required this.avatarUrl,
    this.isConnected = true,
    required this.lastSynced,
    required this.totalGamesCount,
    this.accountId = '',
    this.apiKey = '',
    this.region = '',
  });

  Map<String, dynamic> toJson() => {
        'platform': platform.name,
        'username': username,
        'avatarUrl': avatarUrl,
        'isConnected': isConnected,
        'lastSynced': lastSynced.toIso8601String(),
        'totalGamesCount': totalGamesCount,
        'accountId': accountId,
        'apiKey': apiKey,
        'region': region,
      };

  factory PlatformAccount.fromJson(Map<String, dynamic> json) => PlatformAccount(
        platform: GamePlatform.values.firstWhere(
          (e) => e.name == json['platform'],
          orElse: () => GamePlatform.custom,
        ),
        username: json['username'] ?? '',
        avatarUrl: json['avatarUrl'] ?? '',
        isConnected: json['isConnected'] ?? false,
        lastSynced: json['lastSynced'] != null
            ? DateTime.parse(json['lastSynced'])
            : DateTime.now(),
        totalGamesCount: json['totalGamesCount'] ?? 0,
        accountId: json['accountId'] ?? '',
        apiKey: json['apiKey'] ?? '',
        region: json['region'] ?? '',
      );
}

class FriendActivity {
  final String id;
  final String friendName;
  final String friendAvatar;
  final GamePlatform platform;
  final String gameTitle;
  final String activityType; // 'playing', 'unlocked_achievement', 'completed_game'
  final String detailText;
  final DateTime timestamp;

  FriendActivity({
    required this.id,
    required this.friendName,
    required this.friendAvatar,
    required this.platform,
    required this.gameTitle,
    required this.activityType,
    required this.detailText,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'friendName': friendName,
        'friendAvatar': friendAvatar,
        'platform': platform.name,
        'gameTitle': gameTitle,
        'activityType': activityType,
        'detailText': detailText,
        'timestamp': timestamp.toIso8601String(),
      };

  factory FriendActivity.fromJson(Map<String, dynamic> json) => FriendActivity(
        id: json['id'] ?? '',
        friendName: json['friendName'] ?? '',
        friendAvatar: json['friendAvatar'] ?? '',
        platform: GamePlatform.values.firstWhere(
          (e) => e.name == json['platform'],
          orElse: () => GamePlatform.steam,
        ),
        gameTitle: json['gameTitle'] ?? '',
        activityType: json['activityType'] ?? 'playing',
        detailText: json['detailText'] ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'])
            : DateTime.now(),
      );
}

// Sample Data Generators
List<Game> getInitialDefaultGames() {
  final now = DateTime.now();
  return [
    Game(
      id: 'cp2077',
      title: 'Cyberpunk 2077: Phantom Liberty',
      platform: GamePlatform.gog,
      status: GameStatus.playing,
      coverUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?q=80&w=1200&auto=format&fit=crop',
      developer: 'CD PROJEKT RED',
      publisher: 'CD PROJEKT RED',
      releaseYear: 2023,
      metacriticScore: 89,
      personalRating: 4.8,
      hoursPlayed: 84.5,
      lastPlayed: now.subtract(const Duration(hours: 2)),
      summary: 'Cyberpunk 2077 is an open-world, action-adventure RPG set in Night City, a megalopolis obsessed with power, glamour and body modification.',
      genre: 'Action RPG',
      isFavorite: true,
      achievements: [
        Achievement(id: 'cp1', title: 'Welcome to Night City', description: 'Complete the prologue.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 30)), rarityPercentage: 88.4, icon: '🌆'),
        Achievement(id: 'cp2', title: 'The Chip of Immortality', description: 'Steal the Relic from Arasaka Tower.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 20)), rarityPercentage: 62.1, icon: '💾'),
        Achievement(id: 'cp3', title: 'King of Swords', description: 'Complete Phantom Liberty DLC story.', isUnlocked: false, rarityPercentage: 14.2, icon: '👑'),
        Achievement(id: 'cp4', title: 'Netrunner Supreme', description: 'Hacks 100 enemies with quickhacks.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 5)), rarityPercentage: 29.5, icon: '⚡'),
      ],
      personalNotes: 'Blown away by Dogtown storyline! Phantom Liberty is pure espionage thrill.',
    ),
    Game(
      id: 'eldenring',
      title: 'Elden Ring: Shadow of the Erdtree',
      platform: GamePlatform.steam,
      status: GameStatus.playing,
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=1200&auto=format&fit=crop',
      developer: 'FromSoftware',
      publisher: 'Bandai Namco',
      releaseYear: 2024,
      metacriticScore: 95,
      personalRating: 5.0,
      hoursPlayed: 142.0,
      lastPlayed: now.subtract(const Duration(days: 1)),
      summary: 'THE CRITICALLY ACCLAIMED FANTASY ACTION RPG. Rise, Tarnished, and be guided by grace to brandish the power of the Elden Ring in the Lands Between.',
      genre: 'Souls-like RPG',
      isFavorite: true,
      achievements: [
        Achievement(id: 'er1', title: 'Elden Lord', description: 'Achieve the Elden Lord ending.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 45)), rarityPercentage: 28.3, icon: '⚔️'),
        Achievement(id: 'er2', title: 'Shardbearer Malenia', description: 'Defeat Shardbearer Malenia.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 10)), rarityPercentage: 19.8, icon: '🌸'),
        Achievement(id: 'er3', title: 'Realm of Shadow', description: 'Enter the Realm of Shadow in Erdtree.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 2)), rarityPercentage: 42.0, icon: '🌳'),
      ],
    ),
    Game(
      id: 'gow_rag',
      title: 'God of War Ragnarök',
      platform: GamePlatform.psn,
      status: GameStatus.completed,
      coverUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1534447677768-be436bb09401?q=80&w=1200&auto=format&fit=crop',
      developer: 'Santa Monica Studio',
      publisher: 'PlayStation Studios',
      releaseYear: 2022,
      metacriticScore: 94,
      personalRating: 4.9,
      hoursPlayed: 56.0,
      lastPlayed: now.subtract(const Duration(days: 12)),
      summary: 'Kratos and Atreus must journey to each of the Nine Realms in search of answers as Asgardian forces prepare for a prophesied battle.',
      genre: 'Action-Adventure',
      isFavorite: true,
      achievements: [
        Achievement(id: 'gow1', title: 'The Bear and the Wolf', description: 'Collect all Trophies.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 12)), rarityPercentage: 8.9, icon: '🏆'),
        Achievement(id: 'gow2', title: 'Grave Mistake', description: 'Defeat King Hrólf Kraki.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 14)), rarityPercentage: 12.4, icon: '👑'),
      ],
    ),
    Game(
      id: 'starfield',
      title: 'Starfield',
      platform: GamePlatform.xbox,
      status: GameStatus.backlog,
      coverUrl: 'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1506703719100-a0f3a48c0f86?q=80&w=1200&auto=format&fit=crop',
      developer: 'Bethesda Game Studios',
      publisher: 'Xbox Game Studios',
      releaseYear: 2023,
      metacriticScore: 83,
      personalRating: 3.8,
      hoursPlayed: 24.0,
      lastPlayed: now.subtract(const Duration(days: 40)),
      summary: 'Starfield is the first new universe in 25 years from Bethesda Game Studios, the award-winning creators of The Elder Scrolls V: Skyrim and Fallout 4.',
      genre: 'Sci-Fi RPG',
      isFavorite: false,
      achievements: [
        Achievement(id: 'sf1', title: 'One Small Step', description: 'Join Constellation.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 40)), rarityPercentage: 79.1, icon: '🚀'),
        Achievement(id: 'sf2', title: 'Starlight', description: 'Reach Level 25.', isUnlocked: false, rarityPercentage: 35.0, icon: '⭐'),
      ],
    ),
    Game(
      id: 'zelda_totk',
      title: 'The Legend of Zelda: Tears of the Kingdom',
      platform: GamePlatform.nintendo,
      status: GameStatus.completed,
      coverUrl: 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?q=80&w=1200&auto=format&fit=crop',
      developer: 'Nintendo EPD',
      publisher: 'Nintendo',
      releaseYear: 2023,
      metacriticScore: 96,
      personalRating: 5.0,
      hoursPlayed: 110.0,
      lastPlayed: now.subtract(const Duration(days: 60)),
      summary: 'An epic adventure across the land and skies of Hyrule awaits in The Legend of Zelda: Tears of the Kingdom.',
      genre: 'Action-Adventure',
      isFavorite: true,
      achievements: [],
    ),
    Game(
      id: 'hades2',
      title: 'Hades II',
      platform: GamePlatform.epic,
      status: GameStatus.playing,
      coverUrl: 'https://images.unsplash.com/photo-1538481199705-c710c4e965fc?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1563089145-599997674d42?q=80&w=1200&auto=format&fit=crop',
      developer: 'Supergiant Games',
      publisher: 'Supergiant Games',
      releaseYear: 2024,
      metacriticScore: 92,
      personalRating: 4.9,
      hoursPlayed: 38.0,
      lastPlayed: now.subtract(const Duration(hours: 6)),
      summary: 'Battle beyond the Underworld using dark sorcery to take on the Titan of Time in this bewitching rogue-like dungeon crawler.',
      genre: 'Rogue-like Action',
      isFavorite: true,
      achievements: [
        Achievement(id: 'h2_1', title: 'Princess of the Underworld', description: 'Defeat Hecate in Erebus.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 3)), rarityPercentage: 71.0, icon: '🌙'),
      ],
    ),
    Game(
      id: 'gtav',
      title: 'Grand Theft Auto V: Enhanced Edition',
      platform: GamePlatform.custom,
      status: GameStatus.backlog,
      coverUrl: 'https://images.unsplash.com/photo-1511512578047-dfb367046420?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
      developer: 'Rockstar North',
      publisher: 'Rockstar Games',
      releaseYear: 2022,
      metacriticScore: 97,
      personalRating: 4.5,
      hoursPlayed: 215.0,
      lastPlayed: now.subtract(const Duration(days: 90)),
      summary: 'When a young street hustler, a retired bank robber and a terrifying psychopath find themselves entangled with the underworld, they must pull off heists to survive.',
      genre: 'Open World Action',
      isFavorite: false,
      achievements: [],
    ),
    Game(
      id: 'witcher3',
      title: 'The Witcher 3: Wild Hunt',
      platform: GamePlatform.gog,
      status: GameStatus.completed,
      coverUrl: 'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?q=80&w=600&auto=format&fit=crop',
      bannerUrl: 'https://images.unsplash.com/photo-1578632767115-351597cf2477?q=80&w=1200&auto=format&fit=crop',
      developer: 'CD PROJEKT RED',
      publisher: 'CD PROJEKT RED',
      releaseYear: 2015,
      metacriticScore: 93,
      personalRating: 5.0,
      hoursPlayed: 195.0,
      lastPlayed: now.subtract(const Duration(days: 180)),
      summary: 'As war rages across the Northern Realms, you take on the greatest contract of your life — tracking down the Child of Prophecy, a living weapon that can alter the shape of the world.',
      genre: 'RPG',
      isFavorite: true,
      achievements: [
        Achievement(id: 'w3_1', title: 'Lilac and Gooseberries', description: 'Find Yennefer of Vengerberg.', isUnlocked: true, unlockDate: now.subtract(const Duration(days: 300)), rarityPercentage: 91.0, icon: '🐺'),
      ],
    ),
  ];
}

List<PlatformAccount> getInitialDefaultAccounts() {
  final now = DateTime.now();
  return [
    PlatformAccount(platform: GamePlatform.steam, username: 'cyber_voyager_99', avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop', isConnected: true, lastSynced: now.subtract(const Duration(minutes: 15)), totalGamesCount: 142),
    PlatformAccount(platform: GamePlatform.riot, username: 'Silver#NA1', avatarUrl: '', isConnected: true, lastSynced: now.subtract(const Duration(minutes: 30)), totalGamesCount: 3, region: 'na1'),
    PlatformAccount(platform: GamePlatform.gog, username: 'witcher_fanatic', avatarUrl: 'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?q=80&w=200&auto=format&fit=crop', isConnected: true, lastSynced: now.subtract(const Duration(hours: 1)), totalGamesCount: 38),
    PlatformAccount(platform: GamePlatform.epic, username: 'epic_gamer_xl', avatarUrl: 'https://images.unsplash.com/photo-1527980965255-d3b416303d12?q=80&w=200&auto=format&fit=crop', isConnected: true, lastSynced: now.subtract(const Duration(hours: 4)), totalGamesCount: 65),
    PlatformAccount(platform: GamePlatform.psn, username: 'shadow_kratos_ps5', avatarUrl: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?q=80&w=200&auto=format&fit=crop', isConnected: true, lastSynced: now.subtract(const Duration(days: 1)), totalGamesCount: 89),
    PlatformAccount(platform: GamePlatform.xbox, username: 'MasterChief_xX', avatarUrl: 'https://images.unsplash.com/photo-1628157582853-a796fa650a6a?q=80&w=200&auto=format&fit=crop', isConnected: true, lastSynced: now.subtract(const Duration(days: 2)), totalGamesCount: 110),
    PlatformAccount(platform: GamePlatform.nintendo, username: 'HyruleHero2026', avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=200&auto=format&fit=crop', isConnected: true, lastSynced: now.subtract(const Duration(days: 5)), totalGamesCount: 22),
  ];
}

List<PlatformAccount> getDisconnectedDefaultAccounts() {
  final now = DateTime.now();
  return [
    PlatformAccount(platform: GamePlatform.steam, username: '', avatarUrl: '', isConnected: false, lastSynced: now, totalGamesCount: 0),
    PlatformAccount(platform: GamePlatform.riot, username: '', avatarUrl: '', isConnected: false, lastSynced: now, totalGamesCount: 0),
    PlatformAccount(platform: GamePlatform.gog, username: '', avatarUrl: '', isConnected: false, lastSynced: now, totalGamesCount: 0),
    PlatformAccount(platform: GamePlatform.epic, username: '', avatarUrl: '', isConnected: false, lastSynced: now, totalGamesCount: 0),
    PlatformAccount(platform: GamePlatform.psn, username: '', avatarUrl: '', isConnected: false, lastSynced: now, totalGamesCount: 0),
    PlatformAccount(platform: GamePlatform.xbox, username: '', avatarUrl: '', isConnected: false, lastSynced: now, totalGamesCount: 0),
    PlatformAccount(platform: GamePlatform.nintendo, username: '', avatarUrl: '', isConnected: false, lastSynced: now, totalGamesCount: 0),
  ];
}

List<FriendActivity> getInitialDefaultActivities() {
  final now = DateTime.now();
  return [
    FriendActivity(
      id: 'fa1',
      friendName: 'Alex Vance',
      friendAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?q=80&w=200&auto=format&fit=crop',
      platform: GamePlatform.steam,
      gameTitle: 'Elden Ring: Shadow of the Erdtree',
      activityType: 'unlocked_achievement',
      detailText: 'Unlocked: Realm of Shadow 🏆',
      timestamp: now.subtract(const Duration(minutes: 25)),
    ),
    FriendActivity(
      id: 'fa2',
      friendName: 'Marcus Wright',
      friendAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?q=80&w=200&auto=format&fit=crop',
      platform: GamePlatform.psn,
      gameTitle: 'God of War Ragnarök',
      activityType: 'completed_game',
      detailText: 'Earned Platinum Trophy! 🌟',
      timestamp: now.subtract(const Duration(hours: 3)),
    ),
    FriendActivity(
      id: 'fa3',
      friendName: 'Elena Rostova',
      friendAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?q=80&w=200&auto=format&fit=crop',
      platform: GamePlatform.gog,
      gameTitle: 'Cyberpunk 2077: Phantom Liberty',
      activityType: 'playing',
      detailText: 'Playing in Dogtown (24 hrs total)',
      timestamp: now.subtract(const Duration(hours: 6)),
    ),
  ];
}
