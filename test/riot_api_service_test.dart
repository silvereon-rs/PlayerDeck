import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:playersdeck/models.dart';
import 'package:playersdeck/services/riot_api_service.dart';

void main() {
  tearDown(() {
    RiotApiService.httpGetImpl = http.get;
    RiotApiService.forceWebForTesting = null;
    RiotApiService.resetCacheForTesting();
  });

  group('RiotApiService parsing & routing', () {
    test('parseRiotId parses valid Riot ID and rejects malformed input', () {
      final parsed = RiotApiService.parseRiotId('  Faker # KR1 ');
      expect(parsed.gameName, 'Faker');
      expect(parsed.tagLine, 'KR1');

      expect(
        () => RiotApiService.parseRiotId('NoTagLine'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => RiotApiService.parseRiotId('#NA1'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => RiotApiService.parseRiotId('Faker#'),
        throwsA(isA<Exception>()),
      );
    });

    test('regionConfigFor routes SEA shards via asia for account-v1 and sea for match-v5', () {
      final sg = RiotApiService.regionConfigFor('sg2');
      expect(sg.accountRoute, 'asia');
      expect(sg.matchRoute, 'sea');

      final na = RiotApiService.regionConfigFor('na1');
      expect(na.accountRoute, 'americas');
      expect(na.matchRoute, 'americas');

      final euw = RiotApiService.regionConfigFor('euw1');
      expect(euw.accountRoute, 'europe');
      expect(euw.matchRoute, 'europe');
    });
  });

  group('RiotApiService.importRiotLibrary', () {
    test('imports LoL, TFT, LoR, and VALORANT with full extraData', () async {
      RiotApiService.httpGetImpl = (uri, {headers}) async {
        final url = uri.toString();

        // Data Dragon
        if (url == 'https://ddragon.leagueoflegends.com/api/versions.json') {
          return http.Response(jsonEncode(['16.22.1']), 200);
        }
        if (url ==
            'https://ddragon.leagueoflegends.com/cdn/16.22.1/data/en_US/champion.json') {
          return http.Response(
            jsonEncode({
              'data': {
                'Azir': {
                  'id': 'Azir',
                  'key': '268',
                  'name': 'Azir',
                  'title': 'the Emperor of the Sands',
                },
              },
            }),
            200,
          );
        }

        // Account-v1
        if (url.contains('/riot/account/v1/accounts/by-riot-id/')) {
          expect(headers?['X-Riot-Token'], 'RGAPI-TEST');
          return http.Response(
            jsonEncode({
              'puuid': 'puuid-123',
              'gameName': 'Faker',
              'tagLine': 'KR1',
            }),
            200,
          );
        }

        // Active shards
        if (url.contains('/active-shards/by-game/val/')) {
          return http.Response(
            jsonEncode({'puuid': 'puuid-123', 'game': 'val', 'activeShard': 'kr'}),
            200,
          );
        }
        if (url.contains('/active-shards/by-game/lor/')) {
          return http.Response(
            jsonEncode({'puuid': 'puuid-123', 'game': 'lor', 'activeShard': 'asia'}),
            200,
          );
        }

        // LoL Summoner, League, Mastery, Match
        if (url.contains('/lol/summoner/v4/summoners/by-puuid/')) {
          return http.Response(
            jsonEncode({
              'id': 'sum-1',
              'summonerLevel': 420,
              'profileIconId': 29,
              'revisionDate': 1700000000000,
            }),
            200,
          );
        }
        if (url.contains('/lol/league/v4/entries/by-puuid/')) {
          return http.Response(
            jsonEncode([
              {
                'queueType': 'RANKED_SOLO_5x5',
                'tier': 'CHALLENGER',
                'rank': 'I',
                'leaguePoints': 1250,
                'wins': 180,
                'losses': 110,
                'hotStreak': true,
                'veteran': false,
              },
            ]),
            200,
          );
        }
        if (url.contains('/lol/champion-mastery/v4/champion-masteries/')) {
          return http.Response(
            jsonEncode([
              {
                'championId': 268,
                'championLevel': 42,
                'championPoints': 512340,
              },
            ]),
            200,
          );
        }
        if (url.contains('/lol/champion-mastery/v4/scores/')) {
          return http.Response('312', 200);
        }
        if (url.contains('/lol/match/v5/matches/by-puuid/')) {
          return http.Response(jsonEncode(['KR_1']), 200);
        }
        if (url.endsWith('/lol/match/v5/matches/KR_1')) {
          return http.Response(
            jsonEncode({
              'metadata': {'matchId': 'KR_1'},
              'info': {
                'gameDuration': 1800,
                'gameEndTimestamp': 1700000500000,
                'queueId': 420,
                'participants': [
                  {
                    'puuid': 'puuid-123',
                    'championName': 'Azir',
                    'kills': 8,
                    'deaths': 2,
                    'assists': 11,
                    'totalMinionsKilled': 250,
                    'neutralMinionsKilled': 34,
                    'win': true,
                  },
                ],
              },
            }),
            200,
          );
        }

        // TFT Summoner, League, Match
        if (url.contains('/tft/summoner/v1/summoners/by-puuid/')) {
          return http.Response(
            jsonEncode({
              'id': 'tft-sum-1',
              'summonerLevel': 420,
              'profileIconId': 29,
              'revisionDate': 1700000000000,
            }),
            200,
          );
        }
        if (url.contains('/tft/league/v1/by-puuid/')) {
          return http.Response(
            jsonEncode([
              {
                'queueType': 'RANKED_TFT',
                'tier': 'MASTER',
                'rank': 'I',
                'leaguePoints': 140,
                'wins': 45,
                'losses': 35,
              },
            ]),
            200,
          );
        }
        if (url.contains('/tft/match/v1/matches/by-puuid/')) {
          return http.Response(jsonEncode(['KR_TFT_1']), 200);
        }
        if (url.endsWith('/tft/match/v1/matches/KR_TFT_1')) {
          return http.Response(
            jsonEncode({
              'metadata': {'match_id': 'KR_TFT_1'},
              'info': {
                'game_length': 2100.0,
                'game_datetime': 1700000600000,
                'tft_set_number': 13,
                'tft_game_type': 'standard',
                'participants': [
                  {
                    'puuid': 'puuid-123',
                    'placement': 2,
                    'level': 9,
                    'players_eliminated': 3,
                    'traits': [
                      {'name': 'Set13_Rebel', 'num_units': 7, 'style': 3},
                    ],
                  },
                ],
              },
            }),
            200,
          );
        }

        // LoR & VALORANT matches
        if (url.contains('/lor/match/v1/matches/by-puuid/')) {
          return http.Response(jsonEncode(['LOR_1']), 200);
        }
        if (url.contains('/val/match/v1/matchlists/by-puuid/')) {
          return http.Response(
            jsonEncode({
              'history': [
                {
                  'matchId': 'VAL_1',
                  'queueId': 'competitive',
                  'gameStartTimeMillis': 1700000700000,
                },
              ],
            }),
            200,
          );
        }

        return http.Response('Not found', 404);
      };

      final result = await RiotApiService.importRiotLibrary(
        'Faker#KR1',
        apiKey: 'RGAPI-TEST',
        regionCode: 'kr',
      );

      expect(result['puuid'], 'puuid-123');
      expect(result['riotId'], 'Faker#KR1');
      expect(result['region'], 'kr');

      final games = result['games'] as List<Game>;
      expect(games, hasLength(4));

      final lol = games.firstWhere((g) => g.id == 'riot_lol');
      expect(lol.platform, GamePlatform.riot);
      expect(lol.hoursPlayed, 0.5);
      expect(lol.coverUrl, contains('Azir_0.jpg'));
      expect(lol.extraData['summonerLevel'], 420);
      expect(lol.extraData['totalMasteryScore'], 312);
      expect((lol.extraData['ranked'] as List).first['displayRank'], 'CHALLENGER I');
      expect((lol.extraData['topChampions'] as List).first['name'], 'Azir');
      expect((lol.extraData['recentMatches'] as List).first['kda'], '8 / 2 / 11');

      final tft = games.firstWhere((g) => g.id == 'riot_tft');
      expect((tft.extraData['ranked'] as List).first['displayRank'], 'MASTER I');
      expect((tft.extraData['recentMatches'] as List).first['result'], '#2');

      final lor = games.firstWhere((g) => g.id == 'riot_lor');
      expect(lor.extraData['activeShard'], 'ASIA');

      final val = games.firstWhere((g) => g.id == 'riot_val');
      expect(val.extraData['activeShard'], 'KR');
      expect((val.extraData['recentMatches'] as List).first['mode'], 'competitive');
    });

    test('Web mode passes api_key query param instead of X-Riot-Token header', () async {
      RiotApiService.forceWebForTesting = true;
      RiotApiService.httpGetImpl = (uri, {headers}) async {
        expect(headers?.containsKey('X-Riot-Token') ?? false, isFalse);
        expect(headers?.containsKey('User-Agent') ?? false, isFalse);
        final url = uri.toString();
        if (url.startsWith('http://127.0.0.1:9999/proxy?url=')) {
          final target = Uri.decodeComponent(uri.queryParameters['url']!);
          expect(target, contains('api_key=RGAPI-WEB'));
          if (target.contains('/by-riot-id/')) {
            return http.Response(
              jsonEncode({'puuid': 'puuid-web', 'gameName': 'WebUser', 'tagLine': 'NA1'}),
              200,
            );
          }
          if (target.contains('/active-shards/by-game/val/')) {
            return http.Response('Forbidden', 403);
          }
        }
        return http.Response('Not found', 404);
      };

      final result = await RiotApiService.importRiotLibrary(
        'WebUser#NA1',
        apiKey: 'RGAPI-WEB',
        regionCode: 'na1',
        includeValorantOnDevKey: true,
      );

      final games = result['games'] as List<Game>;
      expect(games.single.id, 'riot_val');
      expect(games.single.extraData['notes'], contains('Development API keys'));
    });

    test('surfaces 403 expired Riot API key error', () async {
      RiotApiService.httpGetImpl = (uri, {headers}) async {
        return http.Response('Forbidden', 403);
      };

      await expectLater(
        () => RiotApiService.importRiotLibrary(
          'Faker#KR1',
          apiKey: 'RGAPI-EXPIRED',
          regionCode: 'kr',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('403'),
          ),
        ),
      );
    });
  });

  group('Game.extraData serialization', () {
    test('round-trips extraData and remains backwards compatible', () {
      final now = DateTime.utc(2026, 1, 1);
      final game = Game(
        id: 'riot_lol',
        title: 'League of Legends',
        platform: GamePlatform.riot,
        status: GameStatus.playing,
        coverUrl: 'https://example.com/cover.jpg',
        bannerUrl: 'https://example.com/banner.jpg',
        developer: 'Riot Games',
        publisher: 'Riot Games',
        releaseYear: 2009,
        metacriticScore: 89,
        lastPlayed: now,
        summary: 'Summary',
        genre: 'MOBA',
        extraData: const {
          'riotId': 'Faker#KR1',
          'summonerLevel': 420,
          'ranked': [
            {'queue': 'Ranked Solo/Duo', 'displayRank': 'CHALLENGER I', 'lp': 1250},
          ],
        },
      );

      final decoded = Game.fromJson(game.toJson());
      expect(decoded.platform, GamePlatform.riot);
      expect(decoded.extraData['riotId'], 'Faker#KR1');
      expect(decoded.extraData['summonerLevel'], 420);
      expect((decoded.extraData['ranked'] as List).first['lp'], 1250);

      final legacy = Game.fromJson({
        'id': 'steam_10',
        'title': 'Counter-Strike',
        'platform': 'steam',
        'status': 'backlog',
        'lastPlayed': now.toIso8601String(),
      });
      expect(legacy.extraData, isEmpty);
    });
  });
}

