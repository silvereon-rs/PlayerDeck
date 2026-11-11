import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:playersdeck/services/image_proxy.dart';
import 'package:playersdeck/services/steam_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final fakeJpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ImageCacheService.clearCacheForTesting();
    SteamApiService.resetProxyCacheForTesting();
  });

  tearDown(() {
    ImageCacheService.httpGetImpl = http.get;
    ImageCacheService.forceWebForTesting = null;
    SteamApiService.httpGetImpl = http.get;
    SteamApiService.forceWebForTesting = null;
    ImageCacheService.clearCacheForTesting();
    SteamApiService.resetProxyCacheForTesting();
  });

  test('omits User-Agent header on Web and caches direct image hit', () async {
    ImageCacheService.forceWebForTesting = true;
    ImageCacheService.httpGetImpl = (uri, {headers}) async {
      expect(headers?.containsKey('User-Agent') ?? false, isFalse);
      return http.Response.bytes(
        fakeJpegBytes,
        200,
        headers: {'content-type': 'image/jpeg'},
      );
    };

    final result = await ImageCacheService.fetchAndCacheImage(
      'https://cdn.akamai.steamstatic.com/steam/apps/730/header.jpg',
    );
    expect(result, startsWith('data:image/jpeg;base64,'));
  });

  test('resolves hashed Steam Store header via api.steamcmd.net when unhashed header 404s', () async {
    ImageCacheService.forceWebForTesting = true;
    ImageCacheService.httpGetImpl = (uri, {headers}) async {
      final url = uri.toString();
      if (url == 'https://api.steamcmd.net/v1/info/4218360') {
        return http.Response(
          jsonEncode({
            'data': {
              '4218360': {
                'common': {
                  'header_image': {
                    'english': 'affb6b94/header.jpg',
                  },
                },
              },
            },
          }),
          200,
        );
      }
      if (url ==
          'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/4218360/affb6b94/header.jpg') {
        return http.Response.bytes(
          fakeJpegBytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('Not found', 404);
    };

    final result = await ImageCacheService.fetchAndCacheImage(
      'https://cdn.akamai.steamstatic.com/steam/apps/4218360/header.jpg',
    );
    expect(result, startsWith('data:image/jpeg;base64,'));
  });

  test('resolves community logo from api.steamcmd.net for test/delisted apps lacking store header', () async {
    ImageCacheService.forceWebForTesting = true;
    ImageCacheService.httpGetImpl = (uri, {headers}) async {
      final url = uri.toString();
      if (url == 'https://api.steamcmd.net/v1/info/367540') {
        return http.Response(
          jsonEncode({
            'data': {
              '367540': {
                'common': {
                  'logo': '53eb828591fb86c72358b7939dde633ba3e5c6c7',
                  'icon': '9420b506fe5b00fd02d9005f1f5555358e3f71f7',
                },
              },
            },
          }),
          200,
        );
      }
      if (url ==
          'https://shared.fastly.steamstatic.com/community_assets/images/apps/367540/53eb828591fb86c72358b7939dde633ba3e5c6c7.jpg') {
        return http.Response.bytes(
          fakeJpegBytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('Not found', 404);
    };

    final result = await ImageCacheService.fetchAndCacheImage(
      'https://cdn.akamai.steamstatic.com/steam/apps/367540/header.jpg',
    );
    expect(result, startsWith('data:image/jpeg;base64,'));
  });

  test('falls back to Steam Store appdetails when steamcmd fails', () async {
    ImageCacheService.httpGetImpl = (uri, {headers}) async {
      final url = uri.toString();
      if (url ==
          'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2991650/69bf1c73/header.jpg') {
        return http.Response.bytes(
          fakeJpegBytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('Not found', 404);
    };

    SteamApiService.httpGetImpl = (uri, {headers}) async {
      final url = uri.toString();
      if (url.contains('store.steampowered.com/api/appdetails')) {
        return http.Response(
          jsonEncode({
            '2991650': {
              'success': true,
              'data': {
                'header_image':
                    'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/2991650/69bf1c73/header.jpg',
              },
            },
          }),
          200,
        );
      }
      return http.Response('Not found', 404);
    };

    final result = await ImageCacheService.fetchAndCacheImage(
      'https://cdn.akamai.steamstatic.com/steam/apps/2991650/header.jpg',
    );
    expect(result, startsWith('data:image/jpeg;base64,'));
  });

  test('falls back to knownCommunityIcons when steamcmd and store fail', () async {
    SteamApiService.knownCommunityIcons[524440] =
        '93be9eec9ea09ee3cbc0f04de58f1c87a24b18f5';

    ImageCacheService.httpGetImpl = (uri, {headers}) async {
      final url = uri.toString();
      if (url ==
          'https://shared.fastly.steamstatic.com/community_assets/images/apps/524440/93be9eec9ea09ee3cbc0f04de58f1c87a24b18f5.jpg') {
        return http.Response.bytes(
          fakeJpegBytes,
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      }
      return http.Response('Not found', 404);
    };

    SteamApiService.httpGetImpl = (uri, {headers}) async {
      return http.Response('Not found', 404);
    };

    final result = await ImageCacheService.fetchAndCacheImage(
      'https://cdn.akamai.steamstatic.com/steam/apps/524440/header.jpg',
    );
    expect(result, startsWith('data:image/jpeg;base64,'));
  });

  test('caches misses so unresolvable app images are not re-fetched repeatedly', () async {
    int fetchCount = 0;
    ImageCacheService.httpGetImpl = (uri, {headers}) async {
      fetchCount++;
      return http.Response('Not found', 404);
    };
    SteamApiService.httpGetImpl = (uri, {headers}) async {
      return http.Response('Not found', 404);
    };

    const url = 'https://cdn.akamai.steamstatic.com/steam/apps/245070/header.jpg';
    expect(await ImageCacheService.fetchAndCacheImage(url), isNull);
    final countAfterFirst = fetchCount;
    expect(countAfterFirst, greaterThan(0));

    expect(await ImageCacheService.fetchAndCacheImage(url), isNull);
    expect(fetchCount, countAfterFirst);
  });
}
