import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

typedef HttpGetCallback =
    Future<http.Response> Function(Uri uri, {Map<String, String>? headers});

/// Shared HTTP GET helper that connects directly on native platforms and
/// routes through local/public CORS proxies on Flutter Web.
class ProxyHttpClient {
  static const String _localProxyBase = 'http://127.0.0.1:9999/proxy?url=';

  static bool? _localProxyAvailable;
  static DateTime? _localProxyCheckedAt;
  static Future<bool>? _inFlightLocalProxyCheck;

  static void resetProxyCache() {
    _localProxyAvailable = null;
    _localProxyCheckedAt = null;
    _inFlightLocalProxyCheck = null;
  }

  @visibleForTesting
  static void resetCacheForTesting() => resetProxyCache();

  static bool _shouldTryLocalProxy() {
    final host = Uri.base.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host.isEmpty;
    if (!isLocalHost) return false;

    if (_localProxyAvailable == false && _localProxyCheckedAt != null) {
      if (DateTime.now().difference(_localProxyCheckedAt!) <
          const Duration(seconds: 60)) {
        return false;
      }
    }
    return true;
  }

  static bool _isCorsfixProxyError(http.Response res) {
    return res.statusCode >= 400 && res.body.contains('"corsfix_error"');
  }

  /// Fetches [targetUrl] directly on native or via CORS proxies on Web.
  ///
  /// When [webUrlTransform] is provided, it transforms [targetUrl] for public
  /// Web proxies (for example, moving a token header into a query parameter).
  static Future<http.Response> get(
    String targetUrl, {
    Map<String, String>? nativeHeaders,
    String Function(String url)? webUrlTransform,
    HttpGetCallback? httpGetImpl,
    bool? forceWeb,
    String serviceName = 'API',
  }) async {
    final performGet = httpGetImpl ?? http.get;
    final isWeb = forceWeb ?? kIsWeb;

    if (!isWeb) {
      return await performGet(
        Uri.parse(targetUrl),
        headers: nativeHeaders,
      ).timeout(const Duration(seconds: 12));
    }

    String? lastFailure;

    // 1. Try local development CORS proxy (tool/cors_proxy.dart) if on localhost.
    if (_shouldTryLocalProxy()) {
      final inFlight = _inFlightLocalProxyCheck;
      bool shouldAttempt = true;
      if (inFlight != null) {
        shouldAttempt = await inFlight;
      }

      if (shouldAttempt) {
        final completer = _localProxyAvailable == null
            ? Completer<bool>()
            : null;
        if (completer != null) {
          _inFlightLocalProxyCheck = completer.future;
        }
        try {
          final effectiveLocalTarget = webUrlTransform != null
              ? webUrlTransform(targetUrl)
              : targetUrl;
          final localUrl =
              '$_localProxyBase${Uri.encodeComponent(effectiveLocalTarget)}';
          final probeTimeout = _localProxyAvailable == true
              ? const Duration(seconds: 10)
              : const Duration(milliseconds: 1500);
          final res = await performGet(
            Uri.parse(localUrl),
          ).timeout(probeTimeout);
          final isProxyFailure =
              res.statusCode == 502 && res.body.startsWith('Proxy error:');
          if (!isProxyFailure) {
            _localProxyAvailable = true;
            _localProxyCheckedAt = DateTime.now();
            completer?.complete(true);
            if (completer != null) _inFlightLocalProxyCheck = null;
            return res;
          }
          lastFailure = 'Local proxy upstream error (${res.statusCode})';
          completer?.complete(true);
          if (completer != null) _inFlightLocalProxyCheck = null;
        } catch (_) {
          _localProxyAvailable = false;
          _localProxyCheckedAt = DateTime.now();
          completer?.complete(false);
          if (completer != null) _inFlightLocalProxyCheck = null;
        }
      }
    }

    // 2. Try public CORS proxies (never pass User-Agent header in browser fetch).
    final webTargetUrl = webUrlTransform != null
        ? webUrlTransform(targetUrl)
        : targetUrl;
    final proxyCandidates = <({String url, Duration timeout, bool isCorsfix})>[
      (
        url: 'https://proxy.corsfix.com/?$webTargetUrl',
        timeout: const Duration(seconds: 10),
        isCorsfix: true,
      ),
      (
        url:
            'https://api.allorigins.win/raw?url=${Uri.encodeComponent(webTargetUrl)}',
        timeout: const Duration(seconds: 6),
        isCorsfix: false,
      ),
      (
        url:
            'https://api.codetabs.com/v1/proxy?quest=${Uri.encodeComponent(webTargetUrl)}',
        timeout: const Duration(seconds: 6),
        isCorsfix: false,
      ),
    ];

    for (final candidate in proxyCandidates) {
      try {
        final res = await performGet(
          Uri.parse(candidate.url),
        ).timeout(candidate.timeout);
        if (candidate.isCorsfix && _isCorsfixProxyError(res)) {
          lastFailure = 'Corsfix proxy error (${res.statusCode})';
          continue;
        }
        if (res.statusCode == 200 ||
            res.statusCode == 400 ||
            res.statusCode == 401 ||
            res.statusCode == 403 ||
            res.statusCode == 404 ||
            res.statusCode == 429) {
          return res;
        }
        lastFailure = 'Proxy HTTP ${res.statusCode}';
      } catch (e) {
        lastFailure = e.toString();
      }
    }

    throw Exception(
      'Unable to reach $serviceName from the browser ($lastFailure). '
      'For local web development, start the CORS proxy with "dart run tool/cors_proxy.dart" and try again.',
    );
  }
}

