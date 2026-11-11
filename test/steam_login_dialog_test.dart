import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:playersdeck/models.dart';
import 'package:playersdeck/screens/steam_login_dialog.dart';
import 'package:playersdeck/services/steam_api_service.dart';

void main() {
  tearDown(() {
    SteamApiService.httpGetImpl = http.get;
    SteamApiService.forceWebForTesting = null;
    SteamApiService.resetProxyCacheForTesting();
  });

  testWidgets('showSteamLoginDialog starts without a hardcoded API key, validates inputs, keeps login dialog open after error OK, and returns imported data on success', (tester) async {
    Map<String, dynamic>? dialogResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await showSteamLoginDialog(context);
              },
              child: const Text('Open Steam'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Steam'));
    await tester.pumpAndSettle();

    expect(find.text('Steam Account Login'), findsOneWidget);

    // Ensure no hardcoded API key is pre-filled
    final apiKeyField = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(apiKeyField.controller?.text, isEmpty);

    // 1. Empty submit shows inline validation errors for both Steam ID and API key
    await tester.tap(find.text('Connect & Import'));
    await tester.pumpAndSettle();
    expect(
      find.text('Please enter your SteamID64, Custom URL, or profile link.'),
      findsOneWidget,
    );
    expect(find.text('Please enter your Steam Web API Key.'), findsOneWidget);

    // 2. API failure shows error dialog and pressing OK keeps login dialog open
    SteamApiService.httpGetImpl = (uri, {headers}) async {
      return http.Response('Forbidden', 403);
    };
    await tester.enterText(find.byType(TextField).at(0), '76561197960265731');
    await tester.enterText(find.byType(TextField).at(1), 'USER_PROVIDED_KEY');
    await tester.tap(find.text('Connect & Import'));
    await tester.pumpAndSettle();

    expect(find.text('Steam Connection Failed'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('Steam Connection Failed'), findsNothing);
    expect(find.text('Steam Account Login'), findsOneWidget);

    // 3. Success returns imported Steam payload including user's API key and closes dialog
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
                  'appid': 440,
                  'name': 'Team Fortress 2',
                  'playtime_forever': 90,
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

    await tester.tap(find.text('Connect & Import'));
    await tester.pumpAndSettle();

    expect(find.text('Steam Account Login'), findsNothing);
    expect(dialogResult, isNotNull);
    expect(dialogResult!['username'], 'EJ');
    expect(dialogResult!['steamId64'], '76561197960265731');
    expect(dialogResult!['apiKey'], 'USER_PROVIDED_KEY');
    expect((dialogResult!['games'] as List<Game>).single.title, 'Team Fortress 2');
  });
}
