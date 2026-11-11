import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:playersdeck/models.dart';
import 'package:playersdeck/services/steam_api_service.dart';

void main() {
  tearDown(() {
    SteamApiService.httpGetImpl = http.get;
    SteamApiService.forceWebForTesting = null;
    SteamApiService.resetProxyCacheForTesting();
  });

  group('SteamApiService.extractSteamIdentifier', () {
    test('extracts SteamID64 from profile URL with trailing path', () {
      expect(
        SteamApiService.extractSteamIdentifier(
          'https://steamcommunity.com/profiles/76561197960434622/games/?tab=all',
        ),
        '76561197960434622',
      );
    });

    test('extracts vanity handle from custom URL', () {
      expect(
        SteamApiService.extractSteamIdentifier(
          'https://steamcommunity.com/id/robinwalker/',
        ),
        'robinwalker',
      );
    });

    test('preserves raw vanity name or SteamID64', () {
      expect(
        SteamApiService.extractSteamIdentifier('76561197960434622'),
        '76561197960434622',
      );
      expect(
        SteamApiService.extractSteamIdentifier('  robinwalker  '),
        'robinwalker',
      );
    });

    test('converts Steam2 and Steam3 IDs to SteamID64', () {
      expect(
        SteamApiService.extractSteamIdentifier('STEAM_0:0:11101'),
        '76561197960287930',
      );
      expect(
        SteamApiService.extractSteamIdentifier('[U:1:22202]'),
        '76561197960287930',
      );
    });
  });

  group('SteamApiService.importSteamLibrary', () {
    test('resolves vanity URL, fetches profile summary and owned games', () async {
      SteamApiService.httpGetImpl = (uri, {headers}) async {
        final url = uri.toString();
        if (url.contains('ResolveVanityURL')) {
          return http.Response(
            jsonEncode({
              'response': {'steamid': '76561197960435530', 'success': 1},
            }),
            200,
          );
        }
        if (url.contains('GetPlayerSummaries')) {
          return http.Response(
            jsonEncode({
              'response': {
                'players': [
                  {
                    'steamid': '76561197960435530',
                    'personaname': 'Robin',
                    'avatarfull': 'https://avatars.steamstatic.com/robin_full.jpg',
                    'communityvisibilitystate': 3,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (url.contains('GetOwnedGames')) {
          return http.Response(
            jsonEncode({
              'response': {
                'game_count': 2,
                'games': [
                  {
                    'appid': 440,
                    'name': 'Team Fortress 2',
                    'playtime_forever': 1200,
                    'rtime_last_played': 1700000000,
                  },
                  {
                    'appid': 620,
                    'name': 'Portal 2',
                    'playtime_forever': 0,
                    'rtime_last_played': 0,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      };

      final result = await SteamApiService.importSteamLibrary(
        'https://steamcommunity.com/id/robinwalker/',
        apiKey: 'TEST_KEY',
      );

      expect(result['steamId64'], '76561197960435530');
      expect(result['username'], 'Robin');
      expect(result['avatarUrl'], 'https://avatars.steamstatic.com/robin_full.jpg');

      final games = result['games'] as List<Game>;
      expect(games, hasLength(2));
      expect(games[0].id, 'steam_440');
      expect(games[0].title, 'Team Fortress 2');
      expect(games[0].hoursPlayed, 20.0);
      expect(games[0].status, GameStatus.playing);
      expect(games[1].status, GameStatus.backlog);
    });

    test('throws informative error when Game Details are private instead of fake games', () async {
      SteamApiService.httpGetImpl = (uri, {headers}) async {
        final url = uri.toString();
        if (url.contains('GetPlayerSummaries')) {
          return http.Response(
            jsonEncode({
              'response': {
                'players': [
                  {
                    'steamid': '76561197960287930',
                    'personaname': 'Rabscuttle',
                    'avatarfull': 'https://avatars.steamstatic.com/gabe_full.jpg',
                    'communityvisibilitystate': 2,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (url.contains('GetOwnedGames')) {
          return http.Response(jsonEncode({'response': {}}), 200);
        }
        if (url.contains('games?xml=1')) {
          return http.Response('<!DOCTYPE html><title>Sign In</title>', 200);
        }
        return http.Response('Not found', 404);
      };

      await expectLater(
        () => SteamApiService.importSteamLibrary('76561197960287930', apiKey: 'TEST_KEY'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Game Details are private'),
          ),
        ),
      );
    });

    test('allows public Steam account with genuinely zero games', () async {
      SteamApiService.httpGetImpl = (uri, {headers}) async {
        final url = uri.toString();
        if (url.contains('GetPlayerSummaries')) {
          return http.Response(
            jsonEncode({
              'response': {
                'players': [
                  {
                    'steamid': '76561198000000001',
                    'personaname': 'EmptyLibraryUser',
                    'avatarfull': 'https://avatars.steamstatic.com/empty_full.jpg',
                    'communityvisibilitystate': 3,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (url.contains('GetOwnedGames')) {
          return http.Response(
            jsonEncode({
              'response': {'game_count': 0},
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      };

      final result = await SteamApiService.importSteamLibrary('76561198000000001', apiKey: 'TEST_KEY');
      expect(result['username'], 'EmptyLibraryUser');
      expect(result['games'], isEmpty);
    });

    test('requires user Steam Web API key instead of using a hardcoded fallback', () async {
      await expectLater(
        () => SteamApiService.importSteamLibrary('76561197960265731'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Steam Web API Key is required'),
          ),
        ),
      );
    });

    test('resolves vanity URL and summary via ?xml=1 when no API key is passed', () async {
      SteamApiService.httpGetImpl = (uri, {headers}) async {
        final url = uri.toString();
        if (url == 'https://steamcommunity.com/id/erikj/?xml=1') {
          return http.Response(
            '<profile><steamID64>76561197960265731</steamID64><steamID><![CDATA[EJ]]></steamID></profile>',
            200,
          );
        }
        if (url == 'https://steamcommunity.com/profiles/76561197960265731/?xml=1') {
          return http.Response(
            '<profile><steamID64>76561197960265731</steamID64><steamID><![CDATA[EJ]]></steamID><avatarFull><![CDATA[https://avatars.steamstatic.com/ej_full.jpg]]></avatarFull></profile>',
            200,
          );
        }
        return http.Response('Not found', 404);
      };

      final id64 = await SteamApiService.resolveSteamId('erikj');
      expect(id64, '76561197960265731');
      final summary = await SteamApiService.getPlayerSummary('76561197960265731');
      expect(summary?['personaname'], 'EJ');
      expect(summary?['avatarfull'], 'https://avatars.steamstatic.com/ej_full.jpg');
    });

    test('surfaces 403 API key error', () async {
      SteamApiService.httpGetImpl = (uri, {headers}) async {
        return http.Response('Forbidden', 403);
      };

      await expectLater(
        () => SteamApiService.importSteamLibrary('robinwalker', apiKey: 'BAD_KEY'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('403'),
          ),
        ),
      );
    });

    test('throws descriptive error for unresolved vanity URL', () async {
      SteamApiService.httpGetImpl = (uri, {headers}) async {
        final url = uri.toString();
        if (url.contains('ResolveVanityURL')) {
          return http.Response(
            jsonEncode({'response': {'success': 42, 'message': 'No match'}}),
            200,
          );
        }
        return http.Response('Not found', 404);
      };

      await expectLater(
        () => SteamApiService.importSteamLibrary('unknown_vanity_xyz', apiKey: 'TEST_KEY'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Could not find Steam profile'),
          ),
        ),
      );
    });

    test('Web mode uses local proxy when available without User-Agent header', () async {
      SteamApiService.forceWebForTesting = true;
      final requestedUrls = <String>[];

      SteamApiService.httpGetImpl = (uri, {headers}) async {
        expect(headers?.containsKey('User-Agent') ?? false, isFalse);
        final url = uri.toString();
        requestedUrls.add(url);
        expect(url, startsWith('http://127.0.0.1:9999/proxy?url='));
        final target = Uri.decodeComponent(uri.queryParameters['url']!);
        if (target.contains('GetPlayerSummaries')) {
          return http.Response(
            jsonEncode({
              'response': {
                'players': [
                  {
                    'steamid': '76561197960265731',
                    'personaname': 'EJ',
                    'avatarfull': 'https://avatars.steamstatic.com/ej.jpg',
                    'communityvisibilitystate': 3,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (target.contains('GetOwnedGames')) {
          return http.Response(
            jsonEncode({
              'response': {
                'game_count': 1,
                'games': [
                  {
                    'appid': 10,
                    'name': 'Counter-Strike',
                    'playtime_forever': 60,
                    'rtime_last_played': 1700000000,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      };

      final result = await SteamApiService.importSteamLibrary('76561197960265731', apiKey: 'TEST_KEY');
      expect(result['username'], 'EJ');
      expect((result['games'] as List<Game>).single.title, 'Counter-Strike');
      expect(requestedUrls, hasLength(3));
      expect(requestedUrls.any((u) => u.contains('IStoreBrowseService')), isTrue);
    });

    test('Web mode falls back to corsfix when local proxy fails and caches local unavailability', () async {
      SteamApiService.forceWebForTesting = true;
      int localCalls = 0;

      SteamApiService.httpGetImpl = (uri, {headers}) async {
        expect(headers?.containsKey('User-Agent') ?? false, isFalse);
        final url = uri.toString();
        if (url.startsWith('http://127.0.0.1:9999/')) {
          localCalls++;
          throw Exception('Connection refused');
        }
        expect(url, startsWith('https://proxy.corsfix.com/?'));
        if (url.contains('GetPlayerSummaries')) {
          return http.Response(
            jsonEncode({
              'response': {
                'players': [
                  {
                    'steamid': '76561197960265731',
                    'personaname': 'EJ',
                    'avatarfull': 'https://avatars.steamstatic.com/ej.jpg',
                    'communityvisibilitystate': 3,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (url.contains('GetOwnedGames')) {
          return http.Response(
            jsonEncode({
              'response': {
                'game_count': 1,
                'games': [
                  {
                    'appid': 20,
                    'name': 'Team Fortress Classic',
                    'playtime_forever': 120,
                    'rtime_last_played': 1700000000,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      };

      final result = await SteamApiService.importSteamLibrary('76561197960265731', apiKey: 'TEST_KEY');
      expect(result['username'], 'EJ');
      expect((result['games'] as List<Game>).single.title, 'Team Fortress Classic');
      expect(localCalls, 1);
    });

    test('enriches newer games with hashed asset URLs from IStoreBrowseService and records icon hashes', () async {
      SteamApiService.httpGetImpl = (uri, {headers}) async {
        final url = uri.toString();
        if (url.contains('GetPlayerSummaries')) {
          return http.Response(
            jsonEncode({
              'response': {
                'players': [
                  {
                    'steamid': '76561197960265731',
                    'personaname': 'EJ',
                    'avatarfull': 'https://avatars.steamstatic.com/ej.jpg',
                  },
                ],
              },
            }),
            200,
          );
        }
        if (url.contains('GetOwnedGames')) {
          return http.Response(
            jsonEncode({
              'response': {
                'game_count': 2,
                'games': [
                  {
                    'appid': 4218360,
                    'name': 'Wall World Strategy',
                    'playtime_forever': 30,
                    'img_icon_url': 'e9a65990bae2fbb64b70509810daffad65b4a29d',
                  },
                  {
                    'appid': 367540,
                    'name': 'Starbound - Unstable',
                    'playtime_forever': 0,
                    'img_icon_url': '9420b506fe5b00fd02d9005f1f5555358e3f71f7',
                  },
                ],
              },
            }),
            200,
          );
        }
        if (url.contains('IStoreBrowseService/GetItems')) {
          return http.Response(
            jsonEncode({
              'response': {
                'store_items': [
                  {
                    'id': 4218360,
                    'assets': {
                      'asset_url_format':
                          'steam/apps/4218360/\${FILENAME}?t=1794400714',
                      'header': 'affb6b94/header.jpg',
                      'library_hero': '33c687ee/library_hero.jpg',
                    },
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      };

      final result = await SteamApiService.importSteamLibrary('76561197960265731', apiKey: 'TEST_KEY');
      final games = result['games'] as List<Game>;
      expect(games, hasLength(2));
      expect(
        games[0].coverUrl,
        'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/4218360/affb6b94/header.jpg?t=1794400714',
      );
      expect(
        games[0].bannerUrl,
        'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/4218360/33c687ee/library_hero.jpg?t=1794400714',
      );
      expect(
        SteamApiService.knownCommunityIcons[367540],
        '9420b506fe5b00fd02d9005f1f5555358e3f71f7',
      );
    });
  });

  group('PlatformAccount serialization', () {
    test('preserves accountId and apiKey and stays backwards compatible', () {
      final now = DateTime.utc(2026, 1, 1);
      final account = PlatformAccount(
        platform: GamePlatform.steam,
        username: 'EJ',
        avatarUrl: 'https://avatars.steamstatic.com/ej.jpg',
        isConnected: true,
        lastSynced: now,
        totalGamesCount: 375,
        accountId: '76561197960265731',
        apiKey: 'CUSTOM_KEY',
      );

      final roundTrip = PlatformAccount.fromJson(account.toJson());
      expect(roundTrip.accountId, '76561197960265731');
      expect(roundTrip.apiKey, 'CUSTOM_KEY');

      final legacy = PlatformAccount.fromJson({
        'platform': 'steam',
        'username': 'LegacyUser',
        'avatarUrl': '',
        'isConnected': true,
        'lastSynced': now.toIso8601String(),
        'totalGamesCount': 12,
      });
      expect(legacy.accountId, '');
      expect(legacy.apiKey, '');
      expect(legacy.username, 'LegacyUser');
    });
  });
}
