import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import 'proxy_http_client.dart';

class RiotRegionConfig {
  final String code;
  final String label;
  final String accountRoute;
  final String matchRoute;

  const RiotRegionConfig({
    required this.code,
    required this.label,
    required this.accountRoute,
    required this.matchRoute,
  });
}

class RiotChampionInfo {
  final String id;
  final String name;
  final String title;

  const RiotChampionInfo({
    required this.id,
    required this.name,
    required this.title,
  });
}

class RiotApiService {
  static const String riotDeveloperPortalUrl = 'https://developer.riotgames.com/';

  static const List<RiotRegionConfig> regions = [
    RiotRegionConfig(
      code: 'na1',
      label: 'NA1 — North America',
      accountRoute: 'americas',
      matchRoute: 'americas',
    ),
    RiotRegionConfig(
      code: 'euw1',
      label: 'EUW1 — Europe West',
      accountRoute: 'europe',
      matchRoute: 'europe',
    ),
    RiotRegionConfig(
      code: 'eun1',
      label: 'EUN1 — Europe Nordic & East',
      accountRoute: 'europe',
      matchRoute: 'europe',
    ),
    RiotRegionConfig(
      code: 'kr',
      label: 'KR — Korea',
      accountRoute: 'asia',
      matchRoute: 'asia',
    ),
    RiotRegionConfig(
      code: 'jp1',
      label: 'JP1 — Japan',
      accountRoute: 'asia',
      matchRoute: 'asia',
    ),
    RiotRegionConfig(
      code: 'oc1',
      label: 'OC1 — Oceania',
      accountRoute: 'asia',
      matchRoute: 'sea',
    ),
    RiotRegionConfig(
      code: 'sg2',
      label: 'SG2 — Singapore',
      accountRoute: 'asia',
      matchRoute: 'sea',
    ),
    RiotRegionConfig(
      code: 'ph2',
      label: 'PH2 — Philippines',
      accountRoute: 'asia',
      matchRoute: 'sea',
    ),
    RiotRegionConfig(
      code: 'th2',
      label: 'TH2 — Thailand',
      accountRoute: 'asia',
      matchRoute: 'sea',
    ),
    RiotRegionConfig(
      code: 'tw2',
      label: 'TW2 — Taiwan',
      accountRoute: 'asia',
      matchRoute: 'sea',
    ),
    RiotRegionConfig(
      code: 'vn2',
      label: 'VN2 — Vietnam',
      accountRoute: 'asia',
      matchRoute: 'sea',
    ),
    RiotRegionConfig(
      code: 'br1',
      label: 'BR1 — Brazil',
      accountRoute: 'americas',
      matchRoute: 'americas',
    ),
    RiotRegionConfig(
      code: 'la1',
      label: 'LA1 — Latin America North',
      accountRoute: 'americas',
      matchRoute: 'americas',
    ),
    RiotRegionConfig(
      code: 'la2',
      label: 'LA2 — Latin America South',
      accountRoute: 'americas',
      matchRoute: 'americas',
    ),
    RiotRegionConfig(
      code: 'tr1',
      label: 'TR1 — Turkey',
      accountRoute: 'europe',
      matchRoute: 'europe',
    ),
    RiotRegionConfig(
      code: 'ru',
      label: 'RU — Russia',
      accountRoute: 'europe',
      matchRoute: 'europe',
    ),
    RiotRegionConfig(
      code: 'me1',
      label: 'ME1 — Middle East',
      accountRoute: 'europe',
      matchRoute: 'europe',
    ),
  ];

  @visibleForTesting
  static HttpGetCallback httpGetImpl = http.get;

  @visibleForTesting
  static bool? forceWebForTesting;

  static String? _cachedDdragonVersion;
  static Map<int, RiotChampionInfo>? _cachedChampions;

  @visibleForTesting
  static void resetCacheForTesting() {
    ProxyHttpClient.resetProxyCache();
    _cachedDdragonVersion = null;
    _cachedChampions = null;
  }

  static bool get _isWebEnvironment => forceWebForTesting ?? kIsWeb;

  static RiotRegionConfig regionConfigFor(String? code) {
    final normalized = (code ?? 'na1').trim().toLowerCase();
    return regions.firstWhere(
      (r) => r.code == normalized,
      orElse: () => regions.first,
    );
  }

  /// Parses `GameName#TagLine` into `(gameName, tagLine)`.
  static ({String gameName, String tagLine}) parseRiotId(String rawInput) {
    final trimmed = rawInput.trim();
    final hashIdx = trimmed.indexOf('#');
    if (hashIdx <= 0 || hashIdx >= trimmed.length - 1) {
      throw Exception(
        'Enter your Riot ID in GameName#TagLine format (e.g. Faker#KR1).',
      );
    }
    final gameName = trimmed.substring(0, hashIdx).trim();
    final tagLine = trimmed.substring(hashIdx + 1).trim();
    if (gameName.isEmpty || tagLine.isEmpty) {
      throw Exception(
        'Enter your Riot ID in GameName#TagLine format (e.g. Faker#KR1).',
      );
    }
    return (gameName: gameName, tagLine: tagLine);
  }

  static String _requireApiKey(String? apiKey) {
    final trimmed = apiKey?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw Exception(
        'A Riot Games API Key is required. Generate one at $riotDeveloperPortalUrl.',
      );
    }
    return trimmed;
  }

  static String _appendApiKeyQuery(String url, String apiKey) {
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}api_key=${Uri.encodeComponent(apiKey)}';
  }

  static Future<http.Response> _riotGet(String url, String apiKey) {
    return ProxyHttpClient.get(
      url,
      nativeHeaders: {'X-Riot-Token': apiKey, 'User-Agent': 'PlayerDeck/1.0'},
      webUrlTransform: (u) => _appendApiKeyQuery(u, apiKey),
      httpGetImpl: httpGetImpl,
      forceWeb: forceWebForTesting,
      serviceName: 'Riot Games API',
    );
  }

  static Future<http.Response> _publicGet(String url) {
    return httpGetImpl(
      Uri.parse(url),
      headers: _isWebEnvironment
          ? null
          : const {'User-Agent': 'PlayerDeck/1.0'},
    ).timeout(const Duration(seconds: 6));
  }

  static Future<({String version, Map<int, RiotChampionInfo> champions})>
  _loadDataDragon() async {
    if (_cachedDdragonVersion != null && _cachedChampions != null) {
      return (version: _cachedDdragonVersion!, champions: _cachedChampions!);
    }

    String version = '16.22.1';
    final Map<int, RiotChampionInfo> champions = {};

    try {
      final verRes = await _publicGet(
        'https://ddragon.leagueoflegends.com/api/versions.json',
      );
      if (verRes.statusCode == 200) {
        final list = jsonDecode(verRes.body);
        if (list is List && list.isNotEmpty) {
          version = list.first.toString();
        }
      }

      final champRes = await _publicGet(
        'https://ddragon.leagueoflegends.com/cdn/$version/data/en_US/champion.json',
      );
      if (champRes.statusCode == 200) {
        final decoded = jsonDecode(champRes.body);
        final data = decoded is Map ? decoded['data'] : null;
        if (data is Map) {
          for (final entry in data.values) {
            if (entry is! Map) continue;
            final numKey = int.tryParse(entry['key']?.toString() ?? '');
            final id = entry['id']?.toString() ?? '';
            final name = entry['name']?.toString() ?? id;
            final title = entry['title']?.toString() ?? '';
            if (numKey != null && id.isNotEmpty) {
              champions[numKey] = RiotChampionInfo(
                id: id,
                name: name,
                title: title,
              );
            }
          }
        }
      }
    } catch (_) {}

    _cachedDdragonVersion = version;
    _cachedChampions = champions;
    return (version: version, champions: champions);
  }

  static String _formatQueueName(String rawQueue) {
    switch (rawQueue) {
      case 'RANKED_SOLO_5x5':
        return 'Ranked Solo/Duo';
      case 'RANKED_FLEX_SR':
        return 'Ranked Flex 5v5';
      case 'RANKED_TFT':
        return 'Ranked TFT';
      case 'RANKED_TFT_DOUBLE_UP':
        return 'TFT Double Up';
      case 'RANKED_TFT_TURBO':
        return 'TFT Hyper Roll';
      default:
        return rawQueue.replaceAll('_', ' ');
    }
  }

  static String _formatLolQueueId(int? queueId) {
    switch (queueId) {
      case 420:
        return 'Ranked Solo/Duo';
      case 440:
        return 'Ranked Flex';
      case 450:
        return 'ARAM';
      case 400:
        return 'Normal Draft';
      case 430:
        return 'Normal Blind';
      case 490:
        return 'Quickplay';
      case 700:
        return 'Clash';
      case 1700:
      case 1710:
        return 'Arena';
      case 900:
      case 1900:
        return 'URF';
      default:
        return queueId != null ? 'Queue $queueId' : 'Match';
    }
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '--';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  static List<Map<String, dynamic>> _parseLeagueEntries(dynamic decoded) {
    if (decoded is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final queueRaw = (item['queueType'] ?? '').toString();
      final tier = (item['tier'] ?? '').toString();
      final rank = (item['rank'] ?? '').toString();
      final ratedTier = (item['ratedTier'] ?? '').toString();
      final int lp =
          (item['leaguePoints'] as num?)?.toInt() ??
          (item['ratedRating'] as num?)?.toInt() ??
          0;
      final int wins = (item['wins'] as num?)?.toInt() ?? 0;
      final int losses = (item['losses'] as num?)?.toInt() ?? 0;
      final int total = wins + losses;
      final String winRate = total > 0
          ? '${((wins / total) * 100).round()}%'
          : '--';

      final String displayTier = tier.isNotEmpty
          ? (rank.isNotEmpty ? '$tier $rank' : tier)
          : (ratedTier.isNotEmpty ? ratedTier : 'Unranked');

      out.add({
        'queue': _formatQueueName(queueRaw),
        'tier': tier.isNotEmpty ? tier : ratedTier,
        'rank': rank,
        'displayRank': displayTier,
        'lp': lp,
        'wins': wins,
        'losses': losses,
        'winRate': winRate,
        'hotStreak': item['hotStreak'] == true,
        'veteran': item['veteran'] == true,
      });
    }
    return out;
  }

  static Future<Game?> _fetchLeagueOfLegends({
    required String puuid,
    required String riotId,
    required RiotRegionConfig region,
    required String apiKey,
    required String ddVersion,
    required Map<int, RiotChampionInfo> champions,
  }) async {
    final summonerRes = await _riotGet(
      'https://${region.code}.api.riotgames.com/lol/summoner/v4/summoners/by-puuid/$puuid',
      apiKey,
    );
    if (summonerRes.statusCode != 200) return null;

    final summoner = jsonDecode(summonerRes.body);
    if (summoner is! Map) return null;

    final int level = (summoner['summonerLevel'] as num?)?.toInt() ?? 1;
    final int profileIconId = (summoner['profileIconId'] as num?)?.toInt() ?? 29;
    final int revisionDate = (summoner['revisionDate'] as num?)?.toInt() ?? 0;
    final String summonerId = (summoner['id'] ?? '').toString();
    final String profileIconUrl =
        'https://ddragon.leagueoflegends.com/cdn/$ddVersion/img/profileicon/$profileIconId.png';

    // Fetch ranked entries, top masteries, mastery score, and recent match IDs in parallel
    final rankedFuture = () async {
      final byPuuid = await _riotGet(
        'https://${region.code}.api.riotgames.com/lol/league/v4/entries/by-puuid/$puuid',
        apiKey,
      );
      if (byPuuid.statusCode == 200) {
        return _parseLeagueEntries(jsonDecode(byPuuid.body));
      }
      if (summonerId.isNotEmpty) {
        final bySum = await _riotGet(
          'https://${region.code}.api.riotgames.com/lol/league/v4/entries/by-summoner/$summonerId',
          apiKey,
        );
        if (bySum.statusCode == 200) {
          return _parseLeagueEntries(jsonDecode(bySum.body));
        }
      }
      return <Map<String, dynamic>>[];
    }();

    final masteryFuture = _riotGet(
      'https://${region.code}.api.riotgames.com/lol/champion-mastery/v4/champion-masteries/by-puuid/$puuid/top?count=5',
      apiKey,
    );
    final scoreFuture = _riotGet(
      'https://${region.code}.api.riotgames.com/lol/champion-mastery/v4/scores/by-puuid/$puuid',
      apiKey,
    );
    final matchIdsFuture = _riotGet(
      'https://${region.matchRoute}.api.riotgames.com/lol/match/v5/matches/by-puuid/$puuid/ids?start=0&count=5',
      apiKey,
    );

    final parallel = await Future.wait<dynamic>([
      rankedFuture,
      masteryFuture,
      scoreFuture,
      matchIdsFuture,
    ]);

    final rankedEntries = parallel[0] as List<Map<String, dynamic>>;
    final masteryRes = parallel[1] as http.Response;
    final scoreRes = parallel[2] as http.Response;
    final matchIdsRes = parallel[3] as http.Response;

    int totalMasteryScore = 0;
    if (scoreRes.statusCode == 200) {
      totalMasteryScore = int.tryParse(scoreRes.body.trim()) ?? 0;
    }

    final topChampions = <Map<String, dynamic>>[];
    String? topChampId;
    if (masteryRes.statusCode == 200) {
      final rawList = jsonDecode(masteryRes.body);
      if (rawList is List) {
        for (final entry in rawList) {
          if (entry is! Map) continue;
          final int champKey = (entry['championId'] as num?)?.toInt() ?? 0;
          final int champLevel = (entry['championLevel'] as num?)?.toInt() ?? 0;
          final int champPoints = (entry['championPoints'] as num?)?.toInt() ?? 0;
          final info = champions[champKey];
          final String champId = info?.id ?? '';
          final String champName = info?.name ?? 'Champion #$champKey';
          topChampId ??= champId.isNotEmpty ? champId : null;
          topChampions.add({
            'championId': champKey,
            'id': champId,
            'name': champName,
            'level': champLevel,
            'points': champPoints,
            if (champId.isNotEmpty)
              'iconUrl':
                  'https://ddragon.leagueoflegends.com/cdn/$ddVersion/img/champion/$champId.png',
          });
        }
      }
    }

    final recentMatches = <Map<String, dynamic>>[];
    int totalSampledSeconds = 0;
    DateTime latestPlayed = revisionDate > 0
        ? DateTime.fromMillisecondsSinceEpoch(revisionDate)
        : DateTime.now();

    if (matchIdsRes.statusCode == 200) {
      final idsRaw = jsonDecode(matchIdsRes.body);
      if (idsRaw is List && idsRaw.isNotEmpty) {
        final matchResponses = await Future.wait(
          idsRaw.take(5).map((id) async {
            try {
              return await _riotGet(
                'https://${region.matchRoute}.api.riotgames.com/lol/match/v5/matches/$id',
                apiKey,
              );
            } catch (_) {
              return null;
            }
          }),
        );

        for (final res in matchResponses) {
          if (res == null || res.statusCode != 200) continue;
          try {
            final matchJson = jsonDecode(res.body);
            final info = matchJson is Map ? matchJson['info'] : null;
            if (info is! Map) continue;
            final participants = info['participants'] as List?;
            if (participants == null) continue;

            Map? me;
            for (final p in participants) {
              if (p is Map && p['puuid'] == puuid) {
                me = p;
                break;
              }
            }
            if (me == null) continue;

            final int durationSec = (info['gameDuration'] as num?)?.toInt() ?? 0;
            totalSampledSeconds += durationSec;
            final int endTs =
                (info['gameEndTimestamp'] as num?)?.toInt() ??
                (info['gameCreation'] as num?)?.toInt() ??
                0;
            final DateTime? matchTime = endTs > 0
                ? DateTime.fromMillisecondsSinceEpoch(endTs)
                : null;
            if (matchTime != null && matchTime.isAfter(latestPlayed)) {
              latestPlayed = matchTime;
            }

            final int kills = (me['kills'] as num?)?.toInt() ?? 0;
            final int deaths = (me['deaths'] as num?)?.toInt() ?? 0;
            final int assists = (me['assists'] as num?)?.toInt() ?? 0;
            final int cs =
                ((me['totalMinionsKilled'] as num?)?.toInt() ?? 0) +
                ((me['neutralMinionsKilled'] as num?)?.toInt() ?? 0);
            final bool win = me['win'] == true;
            final String mode = _formatLolQueueId(
              (info['queueId'] as num?)?.toInt(),
            );
            final String championName =
                (me['championName'] ?? 'Unknown').toString();

            recentMatches.add({
              'matchId': matchJson['metadata']?['matchId']?.toString() ?? '',
              'champion': championName,
              'mode': mode,
              'result': win ? 'Victory' : 'Defeat',
              'win': win,
              'kda': '$kills / $deaths / $assists',
              'cs': cs,
              'duration': _formatDuration(durationSec),
              if (matchTime != null) 'playedAt': matchTime.toIso8601String(),
            });
          } catch (_) {}
        }
      }
    }

    final splashId = topChampId ?? 'Lux';
    final splashUrl =
        'https://ddragon.leagueoflegends.com/cdn/img/champion/splash/${splashId}_0.jpg';
    final sampledHours = double.parse(
      (totalSampledSeconds / 3600.0).toStringAsFixed(1),
    );

    final primaryRank = rankedEntries.isNotEmpty
        ? '${rankedEntries.first['displayRank']} (${rankedEntries.first['lp']} LP)'
        : 'Unranked';

    final extraData = <String, dynamic>{
      'riotId': riotId,
      'puuid': puuid,
      'region': '${region.code.toUpperCase()} (${region.matchRoute.toUpperCase()})',
      'summonerLevel': level,
      'profileIconUrl': profileIconUrl,
      'totalMasteryScore': totalMasteryScore,
      'stats': {
        'Riot ID': riotId,
        'Server': region.code.toUpperCase(),
        'Summoner Level': '$level',
        'Primary Rank': primaryRank,
        'Total Mastery Score': '$totalMasteryScore',
        'Recent Sampled Hours': '${sampledHours.toStringAsFixed(1)} hrs (${recentMatches.length} matches)',
      },
      'ranked': rankedEntries,
      'topChampions': topChampions,
      'recentMatches': recentMatches,
    };

    return Game(
      id: 'riot_lol',
      title: 'League of Legends',
      platform: GamePlatform.riot,
      status: GameStatus.playing,
      coverUrl: splashUrl,
      bannerUrl: splashUrl,
      developer: 'Riot Games',
      publisher: 'Riot Games',
      releaseYear: 2009,
      metacriticScore: 89,
      personalRating: 4.5,
      hoursPlayed: sampledHours,
      lastPlayed: latestPlayed,
      summary:
          'Synced for $riotId on ${region.code.toUpperCase()} • Level $level • $primaryRank • Mastery Score $totalMasteryScore.',
      genre: 'MOBA',
      isFavorite: false,
      extraData: extraData,
    );
  }

  static Future<Game?> _fetchTft({
    required String puuid,
    required String riotId,
    required RiotRegionConfig region,
    required String apiKey,
    required String ddVersion,
  }) async {
    final summonerRes = await _riotGet(
      'https://${region.code}.api.riotgames.com/tft/summoner/v1/summoners/by-puuid/$puuid',
      apiKey,
    );
    if (summonerRes.statusCode != 200) return null;

    final summoner = jsonDecode(summonerRes.body);
    if (summoner is! Map) return null;

    final int level = (summoner['summonerLevel'] as num?)?.toInt() ?? 1;
    final int profileIconId = (summoner['profileIconId'] as num?)?.toInt() ?? 29;
    final int revisionDate = (summoner['revisionDate'] as num?)?.toInt() ?? 0;
    final String tftSummonerId = (summoner['id'] ?? '').toString();
    final String profileIconUrl =
        'https://ddragon.leagueoflegends.com/cdn/$ddVersion/img/profileicon/$profileIconId.png';

    final rankedFuture = () async {
      final byPuuid = await _riotGet(
        'https://${region.code}.api.riotgames.com/tft/league/v1/by-puuid/$puuid',
        apiKey,
      );
      if (byPuuid.statusCode == 200) {
        return _parseLeagueEntries(jsonDecode(byPuuid.body));
      }
      if (tftSummonerId.isNotEmpty) {
        final bySum = await _riotGet(
          'https://${region.code}.api.riotgames.com/tft/league/v1/entries/by-summoner/$tftSummonerId',
          apiKey,
        );
        if (bySum.statusCode == 200) {
          return _parseLeagueEntries(jsonDecode(bySum.body));
        }
      }
      return <Map<String, dynamic>>[];
    }();

    final matchIdsFuture = _riotGet(
      'https://${region.matchRoute}.api.riotgames.com/tft/match/v1/matches/by-puuid/$puuid/ids?start=0&count=5',
      apiKey,
    );

    final results = await Future.wait<dynamic>([rankedFuture, matchIdsFuture]);
    final rankedEntries = results[0] as List<Map<String, dynamic>>;
    final matchIdsRes = results[1] as http.Response;

    final recentMatches = <Map<String, dynamic>>[];
    int totalSampledSeconds = 0;
    DateTime latestPlayed = revisionDate > 0
        ? DateTime.fromMillisecondsSinceEpoch(revisionDate)
        : DateTime.now();

    if (matchIdsRes.statusCode == 200) {
      final idsRaw = jsonDecode(matchIdsRes.body);
      if (idsRaw is List && idsRaw.isNotEmpty) {
        final matchResponses = await Future.wait(
          idsRaw.take(5).map((id) async {
            try {
              return await _riotGet(
                'https://${region.matchRoute}.api.riotgames.com/tft/match/v1/matches/$id',
                apiKey,
              );
            } catch (_) {
              return null;
            }
          }),
        );

        for (final res in matchResponses) {
          if (res == null || res.statusCode != 200) continue;
          try {
            final matchJson = jsonDecode(res.body);
            final info = matchJson is Map ? matchJson['info'] : null;
            if (info is! Map) continue;
            final participants = info['participants'] as List?;
            if (participants == null) continue;

            Map? me;
            for (final p in participants) {
              if (p is Map && p['puuid'] == puuid) {
                me = p;
                break;
              }
            }
            if (me == null) continue;

            final int placement = (me['placement'] as num?)?.toInt() ?? 0;
            final int tacticianLevel = (me['level'] as num?)?.toInt() ?? 0;
            final int eliminated =
                (me['players_eliminated'] as num?)?.toInt() ?? 0;
            final int durationSec =
                ((info['game_length'] as num?)?.toDouble() ?? 0).round();
            totalSampledSeconds += durationSec;

            final int ts = (info['game_datetime'] as num?)?.toInt() ?? 0;
            final DateTime? matchTime = ts > 0
                ? DateTime.fromMillisecondsSinceEpoch(ts)
                : null;
            if (matchTime != null && matchTime.isAfter(latestPlayed)) {
              latestPlayed = matchTime;
            }

            final traitsList = (me['traits'] as List? ?? [])
                .whereType<Map>()
                .where((t) => ((t['style'] as num?)?.toInt() ?? 0) > 0)
                .map((t) => '${t['name']?.toString().split('_').last ?? ''} (${t['num_units']})')
                .take(3)
                .join(', ');

            recentMatches.add({
              'matchId': matchJson['metadata']?['match_id']?.toString() ?? '',
              'champion': traitsList.isNotEmpty
                  ? traitsList
                  : 'TFT Set ${info['tft_set_number'] ?? ''}',
              'mode': (info['tft_game_type'] ?? 'TFT').toString().toUpperCase(),
              'result': '#$placement',
              'win': placement > 0 && placement <= 4,
              'kda': 'Lv.$tacticianLevel • $eliminated KOs',
              'duration': _formatDuration(durationSec),
              if (matchTime != null) 'playedAt': matchTime.toIso8601String(),
            });
          } catch (_) {}
        }
      }
    }

    // Only include TFT if the player has TFT ranked history or recent TFT matches
    if (rankedEntries.isEmpty && recentMatches.isEmpty) {
      return null;
    }

    const coverUrl =
        'https://ddragon.leagueoflegends.com/cdn/img/champion/splash/Tristana_0.jpg';
    final sampledHours = double.parse(
      (totalSampledSeconds / 3600.0).toStringAsFixed(1),
    );
    final primaryRank = rankedEntries.isNotEmpty
        ? '${rankedEntries.first['displayRank']} (${rankedEntries.first['lp']} LP)'
        : 'Unranked';

    return Game(
      id: 'riot_tft',
      title: 'Teamfight Tactics',
      platform: GamePlatform.riot,
      status: GameStatus.playing,
      coverUrl: coverUrl,
      bannerUrl: coverUrl,
      developer: 'Riot Games',
      publisher: 'Riot Games',
      releaseYear: 2019,
      metacriticScore: 84,
      personalRating: 4.3,
      hoursPlayed: sampledHours,
      lastPlayed: latestPlayed,
      summary:
          'Synced for $riotId on ${region.code.toUpperCase()} • $primaryRank • ${recentMatches.length} recent TFT matches.',
      genre: 'Auto Battler',
      isFavorite: false,
      extraData: {
        'riotId': riotId,
        'puuid': puuid,
        'region': '${region.code.toUpperCase()} (${region.matchRoute.toUpperCase()})',
        'summonerLevel': level,
        'profileIconUrl': profileIconUrl,
        'stats': {
          'Riot ID': riotId,
          'Server': region.code.toUpperCase(),
          'Primary Rank': primaryRank,
          'Recent Sampled Hours': '${sampledHours.toStringAsFixed(1)} hrs (${recentMatches.length} matches)',
        },
        'ranked': rankedEntries,
        'recentMatches': recentMatches,
      },
    );
  }

  static Future<Game?> _fetchLegendsOfRuneterra({
    required String puuid,
    required String riotId,
    required RiotRegionConfig region,
    required String apiKey,
  }) async {
    String? activeShard;
    try {
      final shardRes = await _riotGet(
        'https://${region.accountRoute}.api.riotgames.com/riot/account/v1/active-shards/by-game/lor/by-puuid/$puuid',
        apiKey,
      );
      if (shardRes.statusCode == 200) {
        final decoded = jsonDecode(shardRes.body);
        if (decoded is Map && decoded['activeShard'] != null) {
          activeShard = decoded['activeShard'].toString();
        }
      }
    } catch (_) {}

    final lorRoute = activeShard ?? region.accountRoute;
    List<String> matchIds = [];
    try {
      final matchRes = await _riotGet(
        'https://$lorRoute.api.riotgames.com/lor/match/v1/matches/by-puuid/$puuid/ids',
        apiKey,
      );
      if (matchRes.statusCode == 200) {
        final decoded = jsonDecode(matchRes.body);
        if (decoded is List) {
          matchIds = decoded.take(5).map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}

    if (activeShard == null && matchIds.isEmpty) {
      return null;
    }

    const coverUrl =
        'https://ddragon.leagueoflegends.com/cdn/img/champion/splash/Garen_0.jpg';

    return Game(
      id: 'riot_lor',
      title: 'Legends of Runeterra',
      platform: GamePlatform.riot,
      status: GameStatus.playing,
      coverUrl: coverUrl,
      bannerUrl: coverUrl,
      developer: 'Riot Games',
      publisher: 'Riot Games',
      releaseYear: 2020,
      metacriticScore: 87,
      personalRating: 4.4,
      hoursPlayed: 0.0,
      lastPlayed: DateTime.now(),
      summary:
          'Synced for $riotId • Active Shard: ${(activeShard ?? lorRoute).toUpperCase()} • ${matchIds.length} recent matches.',
      genre: 'Digital Card Game',
      isFavorite: false,
      extraData: {
        'riotId': riotId,
        'puuid': puuid,
        'activeShard': (activeShard ?? lorRoute).toUpperCase(),
        'stats': {
          'Riot ID': riotId,
          'Active Shard': (activeShard ?? lorRoute).toUpperCase(),
          'Recent Match Count': '${matchIds.length}',
        },
        if (matchIds.isNotEmpty)
          'recentMatches': matchIds
              .map(
                (id) => {
                  'matchId': id,
                  'champion': 'Runeterra Match',
                  'mode': 'Standard / PvP',
                  'result': 'Recorded',
                  'kda': id,
                  'duration': '--',
                },
              )
              .toList(),
      },
    );
  }

  static Future<Game?> _fetchValorant({
    required String puuid,
    required String riotId,
    required RiotRegionConfig region,
    required String apiKey,
    required bool includeOnDevKey,
  }) async {
    final shardRes = await _riotGet(
      'https://${region.accountRoute}.api.riotgames.com/riot/account/v1/active-shards/by-game/val/by-puuid/$puuid',
      apiKey,
    );

    String? activeShard;
    bool restrictedByDevKey = false;

    if (shardRes.statusCode == 200) {
      final decoded = jsonDecode(shardRes.body);
      if (decoded is Map && decoded['activeShard'] != null) {
        activeShard = decoded['activeShard'].toString();
      }
    } else if (shardRes.statusCode == 403) {
      restrictedByDevKey = true;
      if (!includeOnDevKey) return null;
    } else {
      return null;
    }

    final recentMatches = <Map<String, dynamic>>[];
    if (activeShard != null) {
      try {
        final mlRes = await _riotGet(
          'https://$activeShard.api.riotgames.com/val/match/v1/matchlists/by-puuid/$puuid',
          apiKey,
        );
        if (mlRes.statusCode == 200) {
          final mlJson = jsonDecode(mlRes.body);
          final history = mlJson is Map ? mlJson['history'] as List? : null;
          if (history != null) {
            for (final item in history.take(5)) {
              if (item is! Map) continue;
              final ts = (item['gameStartTimeMillis'] as num?)?.toInt() ?? 0;
              recentMatches.add({
                'matchId': item['matchId']?.toString() ?? '',
                'champion': 'VALORANT Match',
                'mode': (item['queueId'] ?? 'Matchmaking').toString(),
                'result': 'Played',
                'kda': 'Shard ${activeShard.toUpperCase()}',
                'duration': '--',
                if (ts > 0)
                  'playedAt': DateTime.fromMillisecondsSinceEpoch(
                    ts,
                  ).toIso8601String(),
              });
            }
          }
        }
      } catch (_) {}
    }

    const coverUrl =
        'https://media.valorant-api.com/maps/7eaecc1b-4337-bbf6-6ab9-04b8f06b3319/splash.png';

    return Game(
      id: 'riot_val',
      title: 'VALORANT',
      platform: GamePlatform.riot,
      status: GameStatus.playing,
      coverUrl: coverUrl,
      bannerUrl: coverUrl,
      developer: 'Riot Games',
      publisher: 'Riot Games',
      releaseYear: 2020,
      metacriticScore: 80,
      personalRating: 4.5,
      hoursPlayed: 0.0,
      lastPlayed: DateTime.now(),
      summary: activeShard != null
          ? 'Synced for $riotId • Active Shard: ${activeShard.toUpperCase()}.'
          : 'Linked to verified Riot ID $riotId (${region.code.toUpperCase()}).',
      genre: 'Tactical Shooter',
      isFavorite: false,
      extraData: {
        'riotId': riotId,
        'puuid': puuid,
        'region': '${region.code.toUpperCase()} (${region.accountRoute.toUpperCase()})',
        if (activeShard != null) 'activeShard': activeShard.toUpperCase(),
        'stats': {
          'Riot ID': riotId,
          if (activeShard != null) 'Active Shard': activeShard.toUpperCase(),
          'Regional Cluster': region.accountRoute.toUpperCase(),
          'Match History Access': restrictedByDevKey
              ? 'Requires Riot Production Key'
              : (recentMatches.isNotEmpty
                  ? '${recentMatches.length} recent matches'
                  : 'Verified Shard'),
        },
        if (recentMatches.isNotEmpty) 'recentMatches': recentMatches,
        if (restrictedByDevKey)
          'notes':
              'Riot restricts VALORANT active-shards and match-v1 endpoints on personal Development API keys (HTTP 403). Your Riot ID was verified via Account-v1; use an approved Production key to fetch VALORANT match/rank details.',
      },
    );
  }

  /// Resolves a Riot ID (`GameName#TagLine`) and fetches all accessible Riot Games
  /// titles plus detailed ranked, mastery, and match metadata.
  static Future<Map<String, dynamic>> importRiotLibrary(
    String rawRiotId, {
    required String apiKey,
    String regionCode = 'na1',
    bool includeValorantOnDevKey = true,
  }) async {
    final parsed = parseRiotId(rawRiotId);
    final key = _requireApiKey(apiKey);
    final region = regionConfigFor(regionCode);

    // 1. Resolve Riot ID -> Global PUUID via Account-v1
    final accountUrl =
        'https://${region.accountRoute}.api.riotgames.com/riot/account/v1/accounts/by-riot-id/'
        '${Uri.encodeComponent(parsed.gameName)}/${Uri.encodeComponent(parsed.tagLine)}';
    final accountRes = await _riotGet(accountUrl, key);

    if (accountRes.statusCode == 401 || accountRes.statusCode == 403) {
      throw Exception(
        'Riot API Key was rejected (HTTP ${accountRes.statusCode}). '
        'Personal development keys expire every 24 hours; generate a fresh key at $riotDeveloperPortalUrl.',
      );
    }
    if (accountRes.statusCode == 404) {
      throw Exception(
        'Riot account "${parsed.gameName}#${parsed.tagLine}" was not found on ${region.accountRoute.toUpperCase()}. '
        'Verify your Riot ID and selected server.',
      );
    }
    if (accountRes.statusCode == 429) {
      throw Exception(
        'Riot API rate limit exceeded (HTTP 429). Please wait a moment and try again.',
      );
    }
    if (accountRes.statusCode != 200) {
      throw Exception('Riot Account API error (HTTP ${accountRes.statusCode}).');
    }

    final dynamic accountJson;
    try {
      accountJson = jsonDecode(accountRes.body);
    } catch (_) {
      throw Exception('Unexpected non-JSON response from Riot Account API.');
    }

    final String puuid = (accountJson is Map ? accountJson['puuid'] : null)
            ?.toString() ??
        '';
    if (puuid.isEmpty) {
      throw Exception('Riot Account API did not return a PUUID.');
    }

    final String canonicalName =
        (accountJson['gameName'] ?? parsed.gameName).toString();
    final String canonicalTag =
        (accountJson['tagLine'] ?? parsed.tagLine).toString();
    final String canonicalRiotId = '$canonicalName#$canonicalTag';

    // 2. Load Data Dragon metadata (version & champion lookup)
    final ddragon = await _loadDataDragon();

    // 3. Fetch League of Legends, TFT, LoR, and VALORANT data in parallel
    final fetched = await Future.wait<Game?>([
      _fetchLeagueOfLegends(
        puuid: puuid,
        riotId: canonicalRiotId,
        region: region,
        apiKey: key,
        ddVersion: ddragon.version,
        champions: ddragon.champions,
      ),
      _fetchTft(
        puuid: puuid,
        riotId: canonicalRiotId,
        region: region,
        apiKey: key,
        ddVersion: ddragon.version,
      ),
      _fetchLegendsOfRuneterra(
        puuid: puuid,
        riotId: canonicalRiotId,
        region: region,
        apiKey: key,
      ),
      _fetchValorant(
        puuid: puuid,
        riotId: canonicalRiotId,
        region: region,
        apiKey: key,
        includeOnDevKey: includeValorantOnDevKey,
      ),
    ]);

    final games = fetched.whereType<Game>().toList();
    if (games.isEmpty) {
      throw Exception(
        'Verified Riot ID "$canonicalRiotId", but no active game data was found on server ${region.code.toUpperCase()}. '
        'Try selecting the server region where your League/TFT/VALORANT account is hosted.',
      );
    }

    String avatarUrl = '';
    for (final g in games) {
      final icon = g.extraData['profileIconUrl']?.toString() ?? '';
      if (icon.isNotEmpty) {
        avatarUrl = icon;
        break;
      }
    }

    return {
      'puuid': puuid,
      'riotId': canonicalRiotId,
      'region': region.code,
      'avatarUrl': avatarUrl,
      'apiKey': key,
      'games': games,
    };
  }
}

