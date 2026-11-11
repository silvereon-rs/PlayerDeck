import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:playersdeck/models.dart';
import 'package:playersdeck/screens/game_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('GameDetailScreen displays all Riot extraData sections when opening a Riot game page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final game = Game(
      id: 'riot_lol',
      title: 'League of Legends',
      platform: GamePlatform.riot,
      status: GameStatus.playing,
      coverUrl: '',
      bannerUrl: '',
      developer: 'Riot Games',
      publisher: 'Riot Games',
      releaseYear: 2009,
      metacriticScore: 89,
      hoursPlayed: 3.5,
      lastPlayed: DateTime(2026, 11, 10),
      summary: 'Synced for Faker#KR1 on KR.',
      genre: 'MOBA',
      extraData: const {
        'riotId': 'Faker#KR1',
        'puuid': 'puuid-abc-123',
        'region': 'KR (ASIA)',
        'summonerLevel': 420,
        'totalMasteryScore': 312,
        'stats': {
          'Server': 'KR',
          'Primary Rank': 'CHALLENGER I (1250 LP)',
        },
        'ranked': [
          {
            'queue': 'Ranked Solo/Duo',
            'displayRank': 'CHALLENGER I',
            'lp': 1250,
            'wins': 180,
            'losses': 110,
            'winRate': '62%',
            'hotStreak': true,
            'veteran': false,
          },
        ],
        'topChampions': [
          {
            'name': 'Azir',
            'level': 42,
            'points': 512340,
          },
        ],
        'recentMatches': [
          {
            'matchId': 'KR_1',
            'champion': 'Azir',
            'mode': 'Ranked Solo/Duo',
            'result': 'Victory',
            'win': true,
            'kda': '8 / 2 / 11',
            'cs': 284,
            'duration': '30m 00s',
            'playedAt': '2026-11-10T12:00:00.000Z',
          },
        ],
        'notes': 'All fetched Riot account stats visible here.',
        'customExtraField': 'Extra Value Check',
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: GameDetailScreen(
          game: game,
          onGameUpdated: (_) {},
          onGameDeleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('RIOT GAMES ACCOUNT & GAME DATA'), findsOneWidget);
    expect(find.text('Faker#KR1'), findsOneWidget);
    expect(find.text('PUUID: puuid-abc-123'), findsOneWidget);
    expect(find.text('CHALLENGER I (1250 LP)'), findsOneWidget);
    expect(find.text('RANKED STANDINGS'), findsOneWidget);
    expect(find.text('CHALLENGER I'), findsOneWidget);
    expect(find.text('1250 LP'), findsOneWidget);
    expect(find.text('180W 110L (62% win rate)'), findsOneWidget);
    expect(find.text('Hot Streak'), findsOneWidget);
    expect(find.text('TOP CHAMPION MASTERY'), findsOneWidget);
    expect(find.text('Lv.42'), findsOneWidget);
    expect(find.text('512,340 pts'), findsOneWidget);
    expect(find.text('RECENT MATCHES'), findsOneWidget);
    expect(find.text('Victory'), findsOneWidget);
    expect(find.textContaining('8 / 2 / 11'), findsOneWidget);
    expect(find.text('All fetched Riot account stats visible here.'), findsOneWidget);
    expect(find.text('Extra Value Check'), findsOneWidget);
  });
}

