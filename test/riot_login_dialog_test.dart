import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:playersdeck/models.dart';
import 'package:playersdeck/screens/riot_login_dialog.dart';
import 'package:playersdeck/services/riot_api_service.dart';

void main() {
  tearDown(() {
    RiotApiService.httpGetImpl = http.get;
    RiotApiService.forceWebForTesting = null;
    RiotApiService.resetCacheForTesting();
  });

  testWidgets('showRiotLoginDialog validates Riot ID & API key, handles 403 error dialog, and returns imported Riot games', (tester) async {
    Map<String, dynamic>? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showRiotLoginDialog(context);
              },
              child: const Text('Open Riot'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Riot'));
    await tester.pumpAndSettle();

    expect(find.text('Riot Games Login'), findsOneWidget);

    // 1. Validate Riot ID format & missing API key
    await tester.enterText(find.byType(TextField).at(0), 'MissingTag');
    await tester.tap(find.text('Connect & Import'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter your Riot ID in GameName#TagLine format (e.g. Faker#KR1).'),
      findsOneWidget,
    );
    expect(find.text('Please enter your Riot Games API Key.'), findsOneWidget);

    // 2. API error keeps login dialog open after pressing OK
    RiotApiService.httpGetImpl = (uri, {headers}) async {
      return http.Response('Forbidden', 403);
    };
    await tester.enterText(find.byType(TextField).at(0), 'Faker#KR1');
    await tester.enterText(find.byType(TextField).at(1), 'RGAPI-TEST');
    await tester.tap(find.text('Connect & Import'));
    await tester.pumpAndSettle();

    expect(find.text('Riot Connection Failed'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Riot Connection Failed'), findsNothing);
    expect(find.text('Riot Games Login'), findsOneWidget);

    // 3. Success returns Riot games payload
    RiotApiService.httpGetImpl = (uri, {headers}) async {
      final url = uri.toString();
      if (url.contains('/by-riot-id/')) {
        return http.Response(
          jsonEncode({'puuid': 'puuid-1', 'gameName': 'Faker', 'tagLine': 'KR1'}),
          200,
        );
      }
      if (url.contains('/active-shards/by-game/val/')) {
        return http.Response('Forbidden', 403);
      }
      return http.Response('Not found', 404);
    };

    await tester.tap(find.text('Connect & Import'));
    await tester.pumpAndSettle();

    expect(find.text('Riot Games Login'), findsNothing);
    expect(dialogResult, isNotNull);
    expect(dialogResult!['riotId'], 'Faker#KR1');
    expect(dialogResult!['apiKey'], 'RGAPI-TEST');
    expect((dialogResult!['games'] as List<Game>).single.title, 'VALORANT');
  });
}

