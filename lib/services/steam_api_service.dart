import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import 'proxy_http_client.dart';

class SteamApiService {
  static const String steamApiKeyUrl = 'https://steamcommunity.com/dev/apikey';
  static const String defaultAvatarUrl =
      'https://avatars.steamstatic.com/fef49e7fa7e1997310d705b2a6158ff8dc1cdfeb_full.jpg';
  static const int _steamId64Base = 76561197960265728;

  @visibleForTesting
  static Future<http.Response> Function(
    Uri uri, {
    Map<String, String>? headers,
  }) httpGetImpl = http.get;

  @visibleForTesting
  static bool? forceWebForTesting;

  static final Map<int, String> knownCommunityIcons = {};

  @visibleForTesting
  static void resetProxyCacheForTesting() {
    ProxyHttpClient.resetProxyCache();
    knownCommunityIcons.clear();
  }

  static String _requireApiKey(String? apiKey) {
    final trimmed = apiKey?.trim() ?? '';
    if (trimmed.isEmpty) {
      throw Exception(
        'A Steam Web API Key is required to import your Steam library. '
        'Get one at $steamApiKeyUrl.',
      );
    }
    return trimmed;
  }

  static bool isSteamId64(String identifier) {
    return RegExp(r'^7656\d{13}$').hasMatch(identifier);
  }

  /// Performs HTTP GET request directly on native platforms and via CORS proxies on Web.
  static Future<http.Response> _httpGet(String targetUrl) {
    return ProxyHttpClient.get(
      targetUrl,
      nativeHeaders: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PlayerDeck/1.0',
      },
      httpGetImpl: httpGetImpl,
      forceWeb: forceWebForTesting,
      serviceName: 'Steam',
    );
  }

  /// Extracts SteamID64 or Vanity handle from raw user input, profile URLs, Steam2, or Steam3 IDs.
  static String extractSteamIdentifier(String rawInput) {
    var trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    // Steam3 format: [U:1:123456]
    final steam3Match = RegExp(
      r'^\[?U:1:(\d+)\]?$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (steam3Match != null) {
      final accountId = int.tryParse(steam3Match.group(1)!);
      if (accountId != null) {
        return (_steamId64Base + accountId).toString();
      }
    }

    // Steam2 format: STEAM_0:0:123456
    final steam2Match = RegExp(
      r'^STEAM_[0-5]:([01]):(\d+)$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (steam2Match != null) {
      final y = int.tryParse(steam2Match.group(1)!);
      final z = int.tryParse(steam2Match.group(2)!);
      if (y != null && z != null) {
        return (_steamId64Base + (z * 2) + y).toString();
      }
    }

    // Profile URLs: .../profiles/7656...(/games/...)
    final profileMatch = RegExp(
      r'profiles\/(7656\d{13})(?:[/?#]|$)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (profileMatch != null) {
      return profileMatch.group(1)!;
    }

    // Custom URLs: .../id/customname(/games/...)
    final idMatch = RegExp(
      r'id\/([^/?#\s]+)',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (idMatch != null) {
      return idMatch.group(1)!;
    }

    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.startsWith('@') && !trimmed.contains('/')) {
      trimmed = trimmed.substring(1);
    }

    return trimmed.trim();
  }

  /// Resolves vanity URL (e.g. 'erikj') to 64-bit Steam ID.
  static Future<String?> resolveSteamId(String inputId, {String? apiKey}) async {
    final cleaned = extractSteamIdentifier(inputId);
    if (cleaned.isEmpty) {
      throw Exception(
        'Please enter your SteamID64, Custom URL name, or Steam profile link.',
      );
    }

    if (isSteamId64(cleaned)) {
      return cleaned;
    }

    final key = apiKey?.trim() ?? '';
    if (key.isNotEmpty) {
      final targetUrl =
          'https://api.steampowered.com/ISteamUser/ResolveVanityURL/v0001/?key=$key&vanityurl=${Uri.encodeComponent(cleaned)}';
      final response = await _httpGet(targetUrl);

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception(
          'Steam Web API key was rejected (HTTP ${response.statusCode}). '
          'Please verify your key at $steamApiKeyUrl.',
        );
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to resolve Steam profile "$cleaned" (HTTP ${response.statusCode}).',
        );
      }

      final dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        throw Exception(
          'Unexpected non-JSON response while resolving Steam profile "$cleaned".',
        );
      }

      final resp = decoded is Map ? decoded['response'] : null;
      if (resp is Map && resp['success'] == 1 && resp['steamid'] is String) {
        return resp['steamid'] as String;
      }
    }

    // Fallback (or keyless resolution) against public Steam Community profile XML (?xml=1)
    try {
      final xmlRes = await _httpGet(
        'https://steamcommunity.com/id/${Uri.encodeComponent(cleaned)}/?xml=1',
      );
      if (xmlRes.statusCode == 200) {
        final idMatch = RegExp(
          r'<steamID64>(\d+)</steamID64>',
        ).firstMatch(xmlRes.body);
        if (idMatch != null) {
          return idMatch.group(1)!;
        }
      }
    } catch (_) {}

    throw Exception(
      'Could not find Steam profile "$cleaned". '
      'Enter your 17-digit SteamID64 (7656...) or your Custom URL slug from steamcommunity.com/id/<name> (not your display nickname).',
    );
  }

  /// Fetches player profile info (avatar, personaname, communityvisibilitystate).
  static Future<Map<String, String>?> getPlayerSummary(
    String steamId64, {
    String? apiKey,
  }) async {
    final key = apiKey?.trim() ?? '';
    if (key.isNotEmpty) {
      try {
        final targetUrl =
            'https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=$key&steamids=$steamId64';
        final response = await _httpGet(targetUrl);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final players = data['response']?['players'] as List?;
          if (players != null && players.isNotEmpty) {
            final p = players.first;
            return {
              'personaname': (p['personaname'] ?? 'Steam User').toString(),
              'avatarfull': (p['avatarfull'] ?? p['avatar'] ?? '').toString(),
              'communityvisibilitystate':
                  (p['communityvisibilitystate'] ?? '').toString(),
            };
          }
        }
      } catch (_) {}
    }

    // Fallback: public profile XML (?xml=1) still works for profile summary
    try {
      final xmlRes = await _httpGet(
        'https://steamcommunity.com/profiles/$steamId64/?xml=1',
      );
      if (xmlRes.statusCode == 200 && xmlRes.body.contains('<profile>')) {
        final nameMatch =
            RegExp(
              r'<steamID><!\[CDATA\[(.*?)\]\]></steamID>',
            ).firstMatch(xmlRes.body) ??
            RegExp(r'<steamID>(.*?)</steamID>').firstMatch(xmlRes.body);
        final avatarMatch =
            RegExp(
              r'<avatarFull><!\[CDATA\[(.*?)\]\]></avatarFull>',
            ).firstMatch(xmlRes.body) ??
            RegExp(r'<avatarFull>(.*?)</avatarFull>').firstMatch(xmlRes.body);
        if (nameMatch != null) {
          return {
            'personaname': nameMatch.group(1) ?? 'Steam User',
            'avatarfull': avatarMatch?.group(1) ?? '',
            'communityvisibilitystate': '',
          };
        }
      }
    } catch (_) {}

    return null;
  }

  /// Public Steam Community XML Sync (legacy endpoint; Steam now gates /games?xml=1 behind login).
  static Future<Map<String, dynamic>> fetchSteamLibraryPublic(
    String rawInput,
  ) async {
    final identifier = extractSteamIdentifier(rawInput);
    final bool isId64 = isSteamId64(identifier);

    final String xmlUrl = isId64
        ? 'https://steamcommunity.com/profiles/$identifier/games?xml=1'
        : 'https://steamcommunity.com/id/$identifier/games?xml=1';

    final response = await _httpGet(xmlUrl);
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw Exception(
        'Could not reach Steam Community profile (HTTP ${response.statusCode}).',
      );
    }

    final body = response.body;
    final lowerBody = body.toLowerCase();
    if (lowerBody.contains('<!doctype html') ||
        lowerBody.contains('<title>sign in</title>')) {
      throw Exception(
        'Steam Community /games?xml=1 now requires Steam Sign In. Please connect using the Steam Web API.',
      );
    }

    if (body.contains('<error>')) {
      final errorMsgMatch =
          RegExp(r'<error><!\[CDATA\[(.*?)\]\]></error>').firstMatch(body) ??
          RegExp(r'<error>(.*?)</error>').firstMatch(body);
      final errorText =
          errorMsgMatch?.group(1) ?? 'Private profile or profile not found.';
      throw Exception(errorText);
    }

    final steamId64Match = RegExp(
      r'<steamID64>(\d+)</steamID64>',
    ).firstMatch(body);
    final steamId64 = steamId64Match?.group(1) ?? identifier;

    final personaMatch =
        RegExp(r'<steamID><!\[CDATA\[(.*?)\]\]></steamID>').firstMatch(body) ??
        RegExp(r'<steamID>(.*?)</steamID>').firstMatch(body);
    final username = personaMatch?.group(1) ?? identifier;

    final List<Game> gamesList = [];
    final gameBlocks = RegExp(
      r'<game>(.*?)</game>',
      dotAll: true,
    ).allMatches(body);

    for (var match in gameBlocks) {
      final block = match.group(1)!;

      final appidMatch = RegExp(r'<appID>(\d+)</appID>').firstMatch(block);
      if (appidMatch == null) continue;
      final int appid = int.parse(appidMatch.group(1)!);

      final nameMatch =
          RegExp(r'<name><!\[CDATA\[(.*?)\]\]></name>').firstMatch(block) ??
          RegExp(r'<name>(.*?)</name>').firstMatch(block);
      final String name = nameMatch?.group(1) ?? 'Steam Game ($appid)';

      final hoursMatch =
          RegExp(r'<hoursPlayed>([\d\.\,]+)</hoursPlayed>').firstMatch(block) ??
          RegExp(
            r'<hoursOnRecord>([\d\.\,]+)</hoursOnRecord>',
          ).firstMatch(block);
      double hoursPlayed = 0.0;
      if (hoursMatch != null) {
        hoursPlayed =
            double.tryParse(hoursMatch.group(1)!.replaceAll(',', '')) ?? 0.0;
      }

      final String bannerUrl =
          'https://cdn.akamai.steamstatic.com/steam/apps/$appid/header.jpg';
      final String coverUrl =
          'https://cdn.akamai.steamstatic.com/steam/apps/$appid/header.jpg';

      gamesList.add(
        Game(
          id: 'steam_$appid',
          title: name,
          platform: GamePlatform.steam,
          status: hoursPlayed > 0 ? GameStatus.playing : GameStatus.backlog,
          coverUrl: coverUrl,
          bannerUrl: bannerUrl,
          developer: 'Steam Developer',
          publisher: 'Valve / Steam',
          releaseYear: DateTime.now().year,
          metacriticScore: 85,
          personalRating: 4.0,
          hoursPlayed: hoursPlayed,
          lastPlayed: DateTime.now(),
          summary: 'Synced from Steam Community Profile.',
          genre: 'PC Gaming',
          isFavorite: false,
          achievements: [],
        ),
      );
    }

    return {
      'steamId64': steamId64,
      'username': username,
      'avatarUrl': defaultAvatarUrl,
      'games': gamesList,
    };
  }

  static String? _formatStoreAssetUrl(
    Map<String, dynamic> assets,
    List<String> keys,
  ) {
    final format = assets['asset_url_format']?.toString() ?? '';
    if (format.isEmpty) return null;
    for (final k in keys) {
      final rel = assets[k]?.toString() ?? '';
      if (rel.isEmpty) continue;
      final path = format.replaceAll(r'${FILENAME}', rel);
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }
      return 'https://shared.fastly.steamstatic.com/store_item_assets/$path';
    }
    return null;
  }

  /// Batch-fetches official hashed Steam Store asset URLs via IStoreBrowseService/GetItems/v1.
  static Future<Map<int, ({String? coverUrl, String? bannerUrl})>>
  fetchStoreItemImageUrls(List<int> appIds) async {
    final Map<int, ({String? coverUrl, String? bannerUrl})> resolved = {};
    if (appIds.isEmpty) return resolved;

    const batchSize = 20;
    const maxConcurrent = 4;
    final batches = <List<int>>[];
    for (var i = 0; i < appIds.length; i += batchSize) {
      batches.add(appIds.skip(i).take(batchSize).toList());
    }

    Future<void> processBatch(List<int> batch) async {
      try {
        final inputJson = jsonEncode({
          'ids': batch.map((id) => {'appid': id}).toList(),
          'context': const {'language': 'english', 'country_code': 'US'},
          'data_request': const {'include_assets': true},
        });
        final url =
            'https://api.steampowered.com/IStoreBrowseService/GetItems/v1/?input_json=${Uri.encodeComponent(inputJson)}';
        final response = await _httpGet(url).timeout(const Duration(seconds: 6));
        if (response.statusCode != 200) return;

        final data = jsonDecode(response.body);
        final responseObj = data is Map ? data['response'] : null;
        final items = responseObj is Map
            ? responseObj['store_items'] as List?
            : null;
        if (items == null) return;

        for (final item in items) {
          if (item is! Map) continue;
          final appid = (item['id'] as num?)?.toInt() ?? 0;
          if (appid <= 0) continue;
          final assets = item['assets'];
          if (assets is! Map) continue;
          final assetsMap = assets.cast<String, dynamic>();

          final communityIcon = assetsMap['community_icon']?.toString() ?? '';
          if (communityIcon.isNotEmpty) {
            knownCommunityIcons[appid] = communityIcon;
          }

          final cover = _formatStoreAssetUrl(assetsMap, const [
            'header',
            'main_capsule',
            'library_capsule',
            'small_capsule',
          ]);
          final banner = _formatStoreAssetUrl(assetsMap, const [
            'library_hero',
            'header',
            'main_capsule',
          ]);
          if (cover != null || banner != null) {
            resolved[appid] = (coverUrl: cover, bannerUrl: banner ?? cover);
          }
        }
      } catch (_) {}
    }

    for (var i = 0; i < batches.length; i += maxConcurrent) {
      final wave = batches.skip(i).take(maxConcurrent);
      await Future.wait(wave.map(processBatch));
    }

    return resolved;
  }

  /// Queries Steam Store APIs as an alternate image source for a single appid.
  static Future<List<String>> fetchStoreImageCandidates(int appId) async {
    final candidates = <String>[];
    try {
      final browseMap = await fetchStoreItemImageUrls([appId]);
      final entry = browseMap[appId];
      if (entry != null) {
        if (entry.coverUrl != null) candidates.add(entry.coverUrl!);
        if (entry.bannerUrl != null && entry.bannerUrl != entry.coverUrl) {
          candidates.add(entry.bannerUrl!);
        }
      }
    } catch (_) {}

    if (candidates.isEmpty) {
      try {
        final res = await _httpGet(
          'https://store.steampowered.com/api/appdetails?appids=$appId&filters=basic',
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          final appEntry = json is Map ? json['$appId'] : null;
          final appData = appEntry is Map ? appEntry['data'] : null;
          if (appData is Map) {
            final header = appData['header_image']?.toString() ?? '';
            final capsule = appData['capsule_image']?.toString() ?? '';
            final capsuleV5 = appData['capsule_imagev5']?.toString() ?? '';
            if (header.isNotEmpty) candidates.add(header);
            if (capsule.isNotEmpty) candidates.add(capsule);
            if (capsuleV5.isNotEmpty) candidates.add(capsuleV5);
          }
        }
      } catch (_) {}
    }

    return candidates;
  }

  static Future<({List<Game> games, bool hasGameCount})>
  _fetchOwnedGamesResponse(String steamId64, {String? apiKey}) async {
    final key = _requireApiKey(apiKey);
    final List<Game> gamesList = [];

    final targetUrl =
        'https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001/?key=$key&steamid=$steamId64&include_appinfo=true&include_played_free_games=true&format=json';

    final response = await _httpGet(targetUrl);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'Steam API ${response.statusCode} Unauthorized: Invalid Steam Web API Key. '
        'Please check your key at $steamApiKeyUrl.',
      );
    }
    if (response.statusCode != 200) {
      throw Exception('Steam API HTTP ${response.statusCode}');
    }

    final dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception(
        'Steam returned an unexpected response while loading your library.',
      );
    }

    final responseObj = data is Map ? data['response'] : null;
    final bool hasGameCount =
        responseObj is Map && responseObj.containsKey('game_count');
    final gamesJson = responseObj is Map ? responseObj['games'] as List? : null;

    if (gamesJson != null) {
      final appIds = <int>[];
      for (var item in gamesJson) {
        if (item is! Map) continue;
        final int appid = (item['appid'] as num?)?.toInt() ?? 0;
        if (appid <= 0) continue;
        appIds.add(appid);
        final iconHash = item['img_icon_url']?.toString() ?? '';
        if (iconHash.isNotEmpty) {
          knownCommunityIcons[appid] = iconHash;
        }
      }

      // Resolve official hashed Steam Store asset URLs (needed for newer Steam releases)
      final storeAssets = await fetchStoreItemImageUrls(appIds);

      for (var item in gamesJson) {
        if (item is! Map) continue;
        final int appid = (item['appid'] as num?)?.toInt() ?? 0;
        if (appid <= 0) continue;

        final String name = (item['name'] ?? 'Steam Game ($appid)').toString();
        final double playtimeForeverMin =
            (item['playtime_forever'] as num?)?.toDouble() ?? 0.0;
        final double hoursPlayed = double.parse(
          (playtimeForeverMin / 60.0).toStringAsFixed(1),
        );

        final int rtimeLastPlayed =
            (item['rtime_last_played'] as num?)?.toInt() ?? 0;
        final DateTime lastPlayed = rtimeLastPlayed > 0
            ? DateTime.fromMillisecondsSinceEpoch(rtimeLastPlayed * 1000)
            : DateTime(2000);

        final resolvedAssets = storeAssets[appid];
        final String fallbackHeader =
            'https://cdn.akamai.steamstatic.com/steam/apps/$appid/header.jpg';
        final String coverUrl = resolvedAssets?.coverUrl ?? fallbackHeader;
        final String bannerUrl = resolvedAssets?.bannerUrl ?? coverUrl;

        gamesList.add(
          Game(
            id: 'steam_$appid',
            title: name,
            platform: GamePlatform.steam,
            status: hoursPlayed > 0 ? GameStatus.playing : GameStatus.backlog,
            coverUrl: coverUrl,
            bannerUrl: bannerUrl,
            developer: 'Steam Developer',
            publisher: 'Valve / Steam',
            releaseYear: DateTime.now().year,
            metacriticScore: 85,
            personalRating: 4.0,
            hoursPlayed: hoursPlayed,
            lastPlayed: lastPlayed,
            summary: 'Imported from connected Steam account.',
            genre: 'PC Gaming',
            isFavorite: false,
            achievements: [],
          ),
        );
      }
    }

    return (games: gamesList, hasGameCount: hasGameCount);
  }

  /// Official Web API Sync
  static Future<List<Game>> fetchOwnedGamesWebApi(
    String steamId64, {
    String? apiKey,
  }) async {
    final result = await _fetchOwnedGamesResponse(steamId64, apiKey: apiKey);
    return result.games;
  }

  /// Connects to Steam, validates the account, and imports the user's real Steam library.
  static Future<Map<String, dynamic>> importSteamLibrary(
    String inputId, {
    String? apiKey,
  }) async {
    final cleaned = extractSteamIdentifier(inputId);
    if (cleaned.isEmpty) {
      throw Exception(
        'Please enter your SteamID64, Custom URL name, or Steam profile link.',
      );
    }

    final key = _requireApiKey(apiKey);

    final resolvedId = await resolveSteamId(cleaned, apiKey: key);
    final String steamId64 = (resolvedId != null && resolvedId.isNotEmpty)
        ? resolvedId
        : cleaned;

    final summaryFuture = getPlayerSummary(steamId64, apiKey: key);
    final gamesFuture = _fetchOwnedGamesResponse(
      steamId64,
      apiKey: key,
    );

    final results = await Future.wait<dynamic>([summaryFuture, gamesFuture]);
    final Map<String, String>? summary = results[0] as Map<String, String>?;
    final ({List<Game> games, bool hasGameCount}) ownedResult =
        results[1] as ({List<Game> games, bool hasGameCount});

    final String username =
        (summary?['personaname']?.isNotEmpty == true)
            ? summary!['personaname']!
            : cleaned;
    final String avatarUrl =
        (summary?['avatarfull']?.isNotEmpty == true)
            ? summary!['avatarfull']!
            : defaultAvatarUrl;

    if (ownedResult.games.isNotEmpty || ownedResult.hasGameCount) {
      return {
        'steamId64': steamId64,
        'username': username,
        'avatarUrl': avatarUrl,
        'apiKey': key,
        'games': ownedResult.games,
      };
    }

    if (summary == null) {
      throw Exception(
        'Steam profile "$steamId64" could not be found. Check your SteamID64 or Custom URL.',
      );
    }

    throw Exception(
      'Found Steam account "$username", but your Game Details are private or friends-only.\n\n'
      'To import your games:\n'
      '1. Open Steam → Profile → Edit Profile → Privacy Settings\n'
      '2. Set "My profile" and "Game details" to Public\n'
      '3. Try connecting again.',
    );
  }
}
