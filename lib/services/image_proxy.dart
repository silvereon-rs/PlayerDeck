import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'steam_api_service.dart';

/// Persistent local image cache with multi-source Steam CDN, SteamCMD/SteamDB PICS,
/// and Steam Store fallback manager.
class ImageCacheService {
  static final Map<String, String> _memoryCache = {};
  static final Set<String> _failedUrls = {};
  static final Map<String, Future<String?>> _inFlightRequests = {};
  static bool _isInit = false;

  @visibleForTesting
  static Future<http.Response> Function(
    Uri uri, {
    Map<String, String>? headers,
  }) httpGetImpl = http.get;

  @visibleForTesting
  static bool? forceWebForTesting;

  @visibleForTesting
  static void clearCacheForTesting() {
    _memoryCache.clear();
    _failedUrls.clear();
    _inFlightRequests.clear();
    _isInit = false;
  }

  static bool get _isWebEnvironment => forceWebForTesting ?? kIsWeb;

  /// Initializes in-memory cache from SharedPreferences
  static Future<void> init() async {
    if (_isInit) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('img_c_'));
      for (var k in keys) {
        try {
          final val = prefs.getString(k);
          if (val != null && val.isNotEmpty) {
            final originalUrl = k.substring(6);
            _memoryCache[originalUrl] = val;
          }
        } catch (_) {}
      }
    } catch (_) {}
    _isInit = true;
  }

  /// Returns cached Base64 string if available locally
  static String? getCachedBase64(String originalUrl) {
    return _memoryCache[originalUrl];
  }

  /// Fetches game cover/banner image from Steam CDN mirrors and alternate metadata sources.
  static Future<String?> fetchAndCacheImage(String originalUrl) {
    if (originalUrl.isEmpty) return Future.value(null);
    if (_memoryCache.containsKey(originalUrl)) {
      return Future.value(_memoryCache[originalUrl]);
    }
    if (_failedUrls.contains(originalUrl)) {
      return Future.value(null);
    }
    return _inFlightRequests.putIfAbsent(originalUrl, () async {
      try {
        return await _fetchAndCacheImageInternal(originalUrl);
      } finally {
        _inFlightRequests.remove(originalUrl);
      }
    });
  }

  static Map<String, String>? get _imageHeaders => _isWebEnvironment
      ? null
      : const {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };

  static Future<({String? dataUri, int statusCode})> _tryDownloadImage(
    String candidateUrl,
  ) async {
    try {
      final response = await httpGetImpl(
        Uri.parse(candidateUrl),
        headers: _imageHeaders,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final contentType = response.headers['content-type'] ?? 'image/jpeg';
        if (contentType.contains('image/') ||
            contentType.contains('octet-stream')) {
          return (
            dataUri:
                'data:$contentType;base64,${base64Encode(response.bodyBytes)}',
            statusCode: response.statusCode,
          );
        }
      }
      return (dataUri: null, statusCode: response.statusCode);
    } catch (_) {
      return (dataUri: null, statusCode: -1);
    }
  }

  static String? _pickLocalizedAsset(dynamic mapOrValue) {
    if (mapOrValue is String && mapOrValue.isNotEmpty) {
      return mapOrValue;
    }
    if (mapOrValue is Map) {
      final english = mapOrValue['english']?.toString();
      if (english != null && english.isNotEmpty) return english;
      for (final val in mapOrValue.values) {
        final s = val?.toString() ?? '';
        if (s.isNotEmpty) return s;
      }
    }
    return null;
  }

  static void _addStoreRelativeCandidates(
    Set<String> out,
    String appid,
    String? relPath,
  ) {
    if (relPath == null || relPath.isEmpty) return;
    if (relPath.startsWith('http://') || relPath.startsWith('https://')) {
      out.add(relPath);
      return;
    }
    out.add(
      'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/$appid/$relPath',
    );
    out.add(
      'https://shared.akamai.steamstatic.com/store_item_assets/steam/apps/$appid/$relPath',
    );
  }

  /// Queries SteamCMD / SteamDB PICS info API (`api.steamcmd.net`, CORS-enabled)
  /// to resolve hashed store assets, community logos, and icons for missing/newer apps.
  static Future<List<String>> _fetchSteamCmdAssetCandidates(String appid) async {
    final candidates = <String>{};
    try {
      final res = await httpGetImpl(
        Uri.parse('https://api.steamcmd.net/v1/info/$appid'),
        headers: _isWebEnvironment
            ? null
            : const {'User-Agent': 'PlayerDeck/1.0'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode != 200) return const [];
      final json = jsonDecode(res.body);
      final dataObj = json is Map ? json['data'] : null;
      final appObj = dataObj is Map ? dataObj[appid] : null;
      final common = appObj is Map ? appObj['common'] : null;
      if (common is! Map) return const [];

      _addStoreRelativeCandidates(
        candidates,
        appid,
        _pickLocalizedAsset(common['header_image']),
      );

      final libraryAssets = common['library_assets_full'];
      if (libraryAssets is Map) {
        _addStoreRelativeCandidates(
          candidates,
          appid,
          _pickLocalizedAsset(libraryAssets['library_header']?['image']),
        );
        _addStoreRelativeCandidates(
          candidates,
          appid,
          _pickLocalizedAsset(libraryAssets['library_capsule']?['image']),
        );
      }

      _addStoreRelativeCandidates(
        candidates,
        appid,
        _pickLocalizedAsset(common['small_capsule']),
      );

      final logoHash = common['logo']?.toString() ?? '';
      if (logoHash.isNotEmpty) {
        candidates.add(
          'https://shared.fastly.steamstatic.com/community_assets/images/apps/$appid/$logoHash.jpg',
        );
      }

      final iconHash = common['icon']?.toString() ?? '';
      if (iconHash.isNotEmpty) {
        candidates.add(
          'https://shared.fastly.steamstatic.com/community_assets/images/apps/$appid/$iconHash.jpg',
        );
      }
    } catch (_) {}
    return candidates.toList();
  }

  static Future<String?> _saveAndReturn(
    String originalUrl,
    String base64Str,
  ) async {
    _memoryCache[originalUrl] = base64Str;

    // Safely attempt to persist to storage without exceeding browser limits
    unawaited(
      SharedPreferences.getInstance()
          .then((prefs) {
            try {
              final existingKeys = prefs
                  .getKeys()
                  .where((k) => k.startsWith('img_c_'))
                  .toList();
              if (existingKeys.length >= 25) {
                for (var k in existingKeys.take(10)) {
                  prefs.remove(k);
                }
              }
              prefs.setString('img_c_$originalUrl', base64Str);
            } catch (_) {}
          })
          .catchError((_) {}),
    );

    return base64Str;
  }

  static Future<String?> _fetchAndCacheImageInternal(String originalUrl) async {
    final firstAttempt = await _tryDownloadImage(originalUrl);
    if (firstAttempt.dataUri != null) {
      return _saveAndReturn(originalUrl, firstAttempt.dataUri!);
    }

    final steamAppIdMatch = RegExp(
      r'/apps?/(\d+)',
    ).firstMatch(originalUrl);
    final appid = steamAppIdMatch?.group(1);

    if (appid != null) {
      final directFallbacks = <String>{
        if (firstAttempt.statusCode != 404) ...[
          'https://cdn.akamai.steamstatic.com/steam/apps/$appid/header.jpg',
          'https://cdn.cloudflare.steamstatic.com/steam/apps/$appid/header.jpg',
          'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/$appid/header.jpg',
        ],
        'https://cdn.akamai.steamstatic.com/steam/apps/$appid/capsule_616x353.jpg',
        'https://shared.fastly.steamstatic.com/store_item_assets/steam/apps/$appid/capsule_616x353.jpg',
        'https://cdn.akamai.steamstatic.com/steam/apps/$appid/library_600x900.jpg',
      }..remove(originalUrl);

      for (final candidate in directFallbacks) {
        final res = await _tryDownloadImage(candidate);
        if (res.dataUri != null) {
          return _saveAndReturn(originalUrl, res.dataUri!);
        }
      }

      // Alternate Source 1: SteamCMD / SteamDB PICS info API (handles hashed & delisted apps)
      final picsCandidates = await _fetchSteamCmdAssetCandidates(appid);
      for (final candidate in picsCandidates) {
        final res = await _tryDownloadImage(candidate);
        if (res.dataUri != null) {
          return _saveAndReturn(originalUrl, res.dataUri!);
        }
      }

      // Alternate Source 2: Steam Store Browse / AppDetails API (proxy-aware on Web)
      final intAppId = int.tryParse(appid);
      if (intAppId != null) {
        final storeCandidates = await SteamApiService.fetchStoreImageCandidates(
          intAppId,
        );
        for (final candidate in storeCandidates) {
          final res = await _tryDownloadImage(candidate);
          if (res.dataUri != null) {
            return _saveAndReturn(originalUrl, res.dataUri!);
          }
        }

        // Alternate Source 3: Community icon hash captured during GetOwnedGames
        final knownIcon = SteamApiService.knownCommunityIcons[intAppId];
        if (knownIcon != null && knownIcon.isNotEmpty) {
          final iconUrls = [
            'https://shared.fastly.steamstatic.com/community_assets/images/apps/$appid/$knownIcon.jpg',
            if (!_isWebEnvironment)
              'https://media.steampowered.com/steamcommunity/public/images/apps/$appid/$knownIcon.jpg',
          ];
          for (final candidate in iconUrls) {
            final res = await _tryDownloadImage(candidate);
            if (res.dataUri != null) {
              return _saveAndReturn(originalUrl, res.dataUri!);
            }
          }
        }
      }
    }

    _failedUrls.add(originalUrl);
    return null;
  }

  /// Returns direct original URL without proxy
  static String url(String originalUrl) {
    return originalUrl;
  }
}

/// A custom widget that displays images from persistent local cache with multi-source fallback support.
class CachedGameImage extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget? placeholder;

  const CachedGameImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.errorBuilder,
    this.placeholder,
  });

  @override
  State<CachedGameImage> createState() => _CachedGameImageState();
}

class _CachedGameImageState extends State<CachedGameImage> {
  String? _base64Data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(CachedGameImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _base64Data = null;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // 1. Check in-memory / local storage cache
    final cached = ImageCacheService.getCachedBase64(widget.imageUrl);
    if (cached != null) {
      if (mounted) {
        setState(() {
          _base64Data = cached;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Fetch directly from Steam CDN mirrors & alternate sources
    if (mounted) setState(() => _isLoading = true);
    final fetchedData = await ImageCacheService.fetchAndCacheImage(
      widget.imageUrl,
    );

    if (mounted) {
      setState(() {
        _base64Data = fetchedData;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_base64Data != null) {
      return Image.network(
        _base64Data!,
        fit: widget.fit,
        errorBuilder: (ctx, err, stack) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(ctx, err, stack);
          }
          return Container(color: const Color(0xFF1E1F25));
        },
      );
    }

    if (_isLoading) {
      return widget.placeholder ??
          Container(
            color: const Color(0xFF141519),
            child: const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white24,
                ),
              ),
            ),
          );
    }

    // Fallback direct network fetch without proxy
    return Image.network(
      ImageCacheService.url(widget.imageUrl),
      fit: widget.fit,
      errorBuilder: widget.errorBuilder,
    );
  }
}
