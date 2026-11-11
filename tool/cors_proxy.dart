// Local CORS proxy server for Flutter Web development.
// Run this with: dart run tool/cors_proxy.dart
// It proxies requests to external APIs (Steam, etc.) and adds CORS headers.

import 'dart:async';
import 'dart:io';

const int proxyPort = 9999;

const Set<String> _strippedRequestHeaders = {
  'host',
  'content-length',
  'connection',
  'accept-encoding',
  'origin',
  'referer',
  'sec-fetch-dest',
  'sec-fetch-mode',
  'sec-fetch-site',
  'sec-ch-ua',
  'sec-ch-ua-mobile',
  'sec-ch-ua-platform',
};

Future<void> _handleRequest(HttpRequest request, HttpClient client) async {
  // Add CORS headers to every response
  request.response.headers.set('Access-Control-Allow-Origin', '*');
  request.response.headers.set(
    'Access-Control-Allow-Methods',
    'GET, POST, OPTIONS',
  );
  request.response.headers.set('Access-Control-Allow-Headers', '*');

  // Handle preflight OPTIONS requests
  if (request.method == 'OPTIONS') {
    request.response.statusCode = 204;
    await request.response.close();
    return;
  }

  final targetUrl = request.uri.queryParameters['url'];
  if (targetUrl == null || targetUrl.isEmpty) {
    request.response.statusCode = 400;
    request.response.write(
      'Missing "url" query parameter. Usage: /proxy?url=<encoded_url>',
    );
    await request.response.close();
    return;
  }

  final targetUri = Uri.tryParse(targetUrl);
  if (targetUri == null ||
      (targetUri.scheme != 'http' && targetUri.scheme != 'https')) {
    request.response.statusCode = 400;
    request.response.write('Invalid target URL: $targetUrl');
    await request.response.close();
    return;
  }

  try {
    final HttpClientRequest proxyRequest;

    if (request.method == 'POST') {
      proxyRequest = await client.postUrl(targetUri);
      final bodyBytes = await request.fold<List<int>>([], (p, e) => p..addAll(e));
      if (bodyBytes.isNotEmpty) {
        proxyRequest.add(bodyBytes);
      }
    } else {
      proxyRequest = await client.getUrl(targetUri);
    }

    // Forward safe headers without browser-only or hop-by-hop headers
    request.headers.forEach((name, values) {
      final lowerName = name.toLowerCase();
      if (!_strippedRequestHeaders.contains(lowerName)) {
        for (var val in values) {
          proxyRequest.headers.add(name, val);
        }
      }
    });

    if (request.headers.value('user-agent') == null) {
      proxyRequest.headers.set(
        'User-Agent',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) PlayerDeck/1.0',
      );
    }

    final proxyResponse = await proxyRequest.close().timeout(
      const Duration(seconds: 15),
    );

    request.response.statusCode = proxyResponse.statusCode;
    final contentType = proxyResponse.headers.contentType;
    if (contentType != null) {
      request.response.headers.contentType = contentType;
    }

    await proxyResponse.pipe(request.response);
    stdout.writeln(
      '[${DateTime.now().toIso8601String()}] ${request.method} ${proxyResponse.statusCode} -> $targetUrl',
    );
  } catch (e) {
    request.response.statusCode = 502;
    request.response.write('Proxy error: $e');
    await request.response.close();
    stdout.writeln('[ERROR] $targetUrl -> $e');
  }
}

Future<void> main() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10);

  final ipv4Server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    proxyPort,
  );
  stdout.writeln(
    'CORS Proxy running at http://127.0.0.1:$proxyPort (and http://localhost:$proxyPort)',
  );
  stdout.writeln(
    'Usage: http://127.0.0.1:$proxyPort/proxy?url=<encoded_target_url>',
  );
  stdout.writeln('Press Ctrl+C to stop.\n');

  HttpServer? ipv6Server;
  try {
    ipv6Server = await HttpServer.bind(
      InternetAddress.loopbackIPv6,
      proxyPort,
    );
  } catch (_) {
    // IPv6 loopback may be unavailable on some systems; IPv4 is active.
  }

  void listenServer(HttpServer server) {
    server.listen((request) {
      unawaited(_handleRequest(request, client));
    });
  }

  listenServer(ipv4Server);
  if (ipv6Server != null) {
    listenServer(ipv6Server);
  }
}
