import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models.dart';
import '../services/steam_api_service.dart';

/// Opens the Steam Account Login dialog and returns the imported Steam payload
/// (`steamId64`, `username`, `avatarUrl`, `games`) when connection succeeds.
Future<Map<String, dynamic>?> showSteamLoginDialog(
  BuildContext context, {
  PlatformAccount? account,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SteamLoginDialog(account: account),
  );
}

class _SteamLoginDialog extends StatefulWidget {
  final PlatformAccount? account;

  const _SteamLoginDialog({this.account});

  @override
  State<_SteamLoginDialog> createState() => _SteamLoginDialogState();
}

class _SteamLoginDialogState extends State<_SteamLoginDialog> {
  late final TextEditingController _idController;
  late final TextEditingController _apiKeyController;
  bool _isLoading = false;
  bool _obscureApiKey = true;
  String? _validationError;
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();
    _idController = TextEditingController(
      text: widget.account?.accountId ?? '',
    );
    _apiKeyController = TextEditingController(
      text: widget.account?.apiKey ?? '',
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final inputId = _idController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    final String? idErr = inputId.isEmpty
        ? 'Please enter your SteamID64, Custom URL, or profile link.'
        : null;
    final String? keyErr = apiKey.isEmpty
        ? 'Please enter your Steam Web API Key.'
        : null;

    if (idErr != null || keyErr != null) {
      setState(() {
        _validationError = idErr;
        _apiKeyError = keyErr;
      });
      return;
    }

    setState(() {
      _validationError = null;
      _apiKeyError = null;
      _isLoading = true;
    });

    try {
      final result = await SteamApiService.importSteamLibrary(
        inputId,
        apiKey: apiKey,
      );
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      final message = e.toString().replaceFirst('Exception: ', '');
      await showDialog<void>(
        context: context,
        builder: (errCtx) => AlertDialog(
          icon: const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 44,
          ),
          title: const Text('Steam Connection Failed'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(errCtx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AccentColorScope.of(context);

    return PopScope(
      canPop: !_isLoading,
      child: AlertDialog(
        title: Row(
          children: [
            Image.asset(
              'assets/small_steam_icon_logo.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                GamePlatform.steam.iconData,
                color: GamePlatform.steam.accentColor,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Steam Account Login'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect your Steam account to auto-import your game library, playtime stats, and profile.',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _idController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'SteamID64 / Custom URL / Profile Link',
                  hintText: 'e.g. 76561198000000000 or custom URL name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _validationError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                enabled: !_isLoading,
                obscureText: _obscureApiKey,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _connect(),
                decoration: InputDecoration(
                  labelText: 'Steam Web API Key',
                  hintText: 'Enter key from steamcommunity.com/dev/apikey',
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  errorText: _apiKeyError,
                  suffixIcon: IconButton(
                    tooltip: _obscureApiKey ? 'Show API key' : 'Hide API key',
                    icon: Icon(
                      _obscureApiKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscureApiKey = !_obscureApiKey),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final uri = Uri.parse(SteamApiService.steamApiKeyUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(
                    'Get a Steam Web API Key',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Ensure "My profile" and "Game details" are set to Public in Steam Privacy Settings.',
                style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 20),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        'Connecting to Steam & fetching games...',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: _isLoading
            ? []
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: accentColor),
                  onPressed: _connect,
                  child: const Text('Connect & Import'),
                ),
              ],
      ),
    );
  }
}
