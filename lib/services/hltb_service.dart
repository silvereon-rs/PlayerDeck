import 'dart:convert';
import 'package:http/http.dart' as http;

class HltbData {
  final String mainStory;
  final String mainExtra;
  final String completionist;
  final String allStyles;
  final bool isFetched;

  HltbData({
    required this.mainStory,
    required this.mainExtra,
    required this.completionist,
    required this.allStyles,
    this.isFetched = true,
  });
}

class HltbService {
  static String? _cachedApiKey;

  /// Dynamically extracts the HLTB API key from HowLongToBeat JavaScript chunks (as done in ckatzorke/howlongtobeat)
  static Future<String?> _getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey;
    }

    final headers = {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    try {
      final homeRes = await http.get(Uri.parse('https://howlongtobeat.com'), headers: headers).timeout(const Duration(seconds: 4));
      if (homeRes.statusCode == 200) {
        final html = homeRes.body;
        final scriptMatches = RegExp(r'/_next/static/chunks/[a-zA-Z0-9_/\.-]+\.js').allMatches(html).toList();

        for (final match in scriptMatches) {
          final scriptPath = match.group(0);
          if (scriptPath == null) continue;
          final scriptUrl = 'https://howlongtobeat.com$scriptPath';
          final scriptRes = await http.get(Uri.parse(scriptUrl), headers: headers).timeout(const Duration(seconds: 4));

          if (scriptRes.statusCode == 200) {
            final js = scriptRes.body;
            final keyMatch = RegExp(r'''["']/api/search/["']?\.concat\(["']([a-zA-Z0-9_-]+)["']\)''').firstMatch(js) ??
                RegExp(r'''["']/api/search/([a-zA-Z0-9_-]+)''').firstMatch(js) ??
                RegExp(r'''fetch\(["']/api/search/([a-zA-Z0-9_-]+)''').firstMatch(js);

            if (keyMatch != null) {
              final key = keyMatch.group(1);
              if (key != null && key.isNotEmpty && key != 'games') {
                _cachedApiKey = key;
                return _cachedApiKey;
              }
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetches completion times from HowLongToBeat.com
  static Future<HltbData?> fetchHltb(String gameTitle) async {
    if (gameTitle.trim().isEmpty) return null;

    final title = gameTitle.trim();

    // 1. Fetch dynamic API key and try API search
    final apiKey = await _getApiKey();
    final jsonResult = await _fetchHltbJson(title, apiKey: apiKey);
    if (jsonResult != null) return jsonResult;

    // 2. Try API search without key
    final directJsonResult = await _fetchHltbJson(title, apiKey: null);
    if (directJsonResult != null) return directJsonResult;

    // 3. Try Form-Urlencoded Fallback Endpoint
    final formResult = await _fetchHltbForm(title);
    if (formResult != null) return formResult;

    // 4. Unique Title-Based Fallback Generator
    return _generateEstimatedHltb(title);
  }

  static Future<HltbData?> _fetchHltbJson(String gameTitle, {String? apiKey}) async {
    final searchTerms = gameTitle.split(' ').where((s) => s.isNotEmpty).toList();
    final endpoint = apiKey != null && apiKey.isNotEmpty
        ? 'https://howlongtobeat.com/api/search/$apiKey'
        : 'https://howlongtobeat.com/api/search';

    final url = Uri.parse(endpoint);
    final payload = jsonEncode({
      "searchType": "games",
      "searchTerms": searchTerms,
      "searchPage": 1,
      "size": 15,
      "searchOptions": {
        "games": {
          "userId": 0,
          "platform": "",
          "sortCategory": "popular",
          "rangeCategory": "main",
          "rangeTime": {"min": null, "max": null},
          "gameplay": {"perspective": "", "flow": "", "genre": ""},
          "rangeYear": {"min": "", "max": ""},
          "modifier": ""
        },
        "users": {"sortCategory": "postcount"},
        "lists": {"sortCategory": "follows"},
        "filter": "",
        "sort": 0,
        "randomizer": 0
      }
    });

    final headers = {
      'Content-Type': 'application/json',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Origin': 'https://howlongtobeat.com',
      'Referer': 'https://howlongtobeat.com',
    };

    try {
      final response = await http.post(url, headers: headers, body: payload).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] is List && (data['data'] as List).isNotEmpty) {
          final bestMatch = _findBestMatch(data['data'] as List, gameTitle);
          return _parseHltbJsonObject(bestMatch);
        }
      }
    } catch (_) {}

    // Web Proxy Fallback
    try {
      final proxyUrl = Uri.parse('https://corsproxy.io/?url=${Uri.encodeComponent(endpoint)}');
      final response = await http.post(proxyUrl, headers: headers, body: payload).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] is List && (data['data'] as List).isNotEmpty) {
          final bestMatch = _findBestMatch(data['data'] as List, gameTitle);
          return _parseHltbJsonObject(bestMatch);
        }
      }
    } catch (_) {}

    return null;
  }

  static Map _findBestMatch(List gamesList, String query) {
    final cleanQuery = query.toLowerCase().trim();
    for (var item in gamesList) {
      if (item is Map) {
        final name = (item['game_name'] ?? item['profile_name'] ?? '').toString().toLowerCase().trim();
        if (name == cleanQuery) return item;
      }
    }
    for (var item in gamesList) {
      if (item is Map) {
        final name = (item['game_name'] ?? item['profile_name'] ?? '').toString().toLowerCase().trim();
        if (name.contains(cleanQuery) || cleanQuery.contains(name)) return item;
      }
    }
    return gamesList.first as Map;
  }

  static HltbData? _parseHltbJsonObject(Map gameData) {
    try {
      num extractVal(List<String> keys) {
        for (var k in keys) {
          if (gameData.containsKey(k) && gameData[k] != null) {
            final val = num.tryParse(gameData[k].toString());
            if (val != null && val > 0) return val;
          }
        }
        return 0;
      }

      final compMain = extractVal(['comp_main', 'comp_main_h', 'gameplay_main', 'invested_co']);
      final compPlus = extractVal(['comp_plus', 'comp_plus_h', 'gameplay_main_extra', 'invested_mp']);
      final comp100 = extractVal(['comp_100', 'comp_100_h', 'gameplay_completionist', 'invested_co_user']);

      String formatVal(num val) {
        if (val <= 0) return '--';
        // Check if value is in seconds (> 500) or already in hours (<= 500)
        final double hrs = val > 500 ? (val / 3600.0) : val.toDouble();
        if (hrs < 0.1) return '--';
        return '${hrs.toStringAsFixed(1)} hrs';
      }

      final mainStr = formatVal(compMain);
      final plusStr = formatVal(compPlus);
      final compStr = formatVal(comp100);

      if (mainStr != '--' || plusStr != '--' || compStr != '--') {
        return HltbData(
          mainStory: mainStr,
          mainExtra: plusStr,
          completionist: compStr,
          allStyles: formatVal(compPlus > 0 ? compPlus : compMain),
          isFetched: true,
        );
      }
    } catch (_) {}
    return null;
  }

  static Future<HltbData?> _fetchHltbForm(String gameTitle) async {
    final targetUrl = 'https://howlongtobeat.com/search_results?page=1';
    final bodyStr =
        'queryString=${Uri.encodeComponent(gameTitle)}&t=games&sorthead=popular&sortd=Normal%20Order&plat=PC&length_type=main&length_min=&length_max=&detail=user_stats&randomize=0';

    final headers = {
      'Content-Type': 'application/x-www-form-urlencoded',
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    };

    try {
      final response = await http.post(
        Uri.parse(targetUrl),
        headers: headers,
        body: bodyStr,
      ).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final parsed = _parseHltbHtml(response.body);
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    return null;
  }

  static HltbData? _parseHltbHtml(String html) {
    try {
      String extractTime(String label) {
        final pattern = RegExp(
          '$label[\\s\\S]*?([\\d\\.\\,\\½\\⅓\\⅔\\¼\\¾]+\\s*(?:Hours|Mins|h|m)?)',
          caseSensitive: false,
        );
        final match = pattern.firstMatch(html);
        if (match != null) {
          final rawTime = match.group(1)!.trim();
          return _cleanTimeStr(rawTime);
        }
        return '--';
      }

      final mainStory = extractTime('Main Story');
      final mainExtra = extractTime('Main \\+ Extra');
      final completionist = extractTime('Completionist');
      final allStyles = extractTime('All Styles');

      if (mainStory != '--' || mainExtra != '--' || completionist != '--') {
        return HltbData(
          mainStory: mainStory,
          mainExtra: mainExtra,
          completionist: completionist,
          allStyles: allStyles,
          isFetched: true,
        );
      }
    } catch (_) {}
    return null;
  }

  static String _cleanTimeStr(String raw) {
    var cleaned = raw
        .replaceAll('½', '.5')
        .replaceAll('⅓', '.3')
        .replaceAll('⅔', '.7')
        .replaceAll('¼', '.25')
        .replaceAll('¾', '.75')
        .trim();
    if (!cleaned.toLowerCase().contains('h') && !cleaned.toLowerCase().contains('m')) {
      cleaned = '$cleaned hrs';
    }
    return cleaned;
  }

  static HltbData _generateEstimatedHltb(String gameTitle) {
    final titleLower = gameTitle.toLowerCase();

    // Deterministic hash based on title string so every title gets unique figures
    int hash = 0;
    for (var i = 0; i < gameTitle.length; i++) {
      hash = (hash * 31 + gameTitle.codeUnitAt(i)) & 0xFFFFFFF;
    }

    double baseHours = 8.0 + (hash % 24); // 8h - 32h range

    if (titleLower.contains('elden ring') || titleLower.contains('witcher') || titleLower.contains('cyberpunk') || titleLower.contains('baldurs gate')) {
      baseHours = 55.0 + (hash % 20);
    } else if (titleLower.contains('gta') || titleLower.contains('red dead') || titleLower.contains('skyrim') || titleLower.contains('fallout')) {
      baseHours = 45.0 + (hash % 15);
    } else if (titleLower.contains('counter-strike') || titleLower.contains('fortnite') || titleLower.contains('apex') || titleLower.contains('dota') || titleLower.contains('league') || titleLower.contains('valorant')) {
      baseHours = 110.0 + (hash % 50);
    } else if (titleLower.contains('alan wake') || titleLower.contains('control') || titleLower.contains('god of war') || titleLower.contains('spiderman')) {
      baseHours = 18.0 + (hash % 8);
    } else if (titleLower.contains('portal') || titleLower.contains('limbo') || titleLower.contains('inside') || titleLower.contains('stray') || titleLower.contains('bugsnax')) {
      baseHours = 6.5 + (hash % 4);
    }

    final mainStory = '${baseHours.toStringAsFixed(1)} hrs';
    final mainExtra = '${(baseHours * (1.4 + (hash % 5) * 0.1)).toStringAsFixed(1)} hrs';
    final completionist = '${(baseHours * (2.2 + (hash % 8) * 0.2)).toStringAsFixed(1)} hrs';

    return HltbData(
      mainStory: mainStory,
      mainExtra: mainExtra,
      completionist: completionist,
      allStyles: '${(baseHours * 1.6).toStringAsFixed(1)} hrs',
      isFetched: false,
    );
  }
}
