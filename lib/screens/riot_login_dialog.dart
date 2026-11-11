import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../models.dart';
import '../services/riot_api_service.dart';

/// Opens the Riot Games Account Login dialog and returns imported Riot Games payload
/// (`puuid`, `riotId`, `region`, `avatarUrl`, `apiKey`, `games`) on success.
Future<Map<String, dynamic>?> showRiotLoginDialog(
  BuildContext context, {
  PlatformAccount? account,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RiotLoginDialog(account: account),
  );
}

class _RiotLoginDialog extends StatefulWidget {
  final PlatformAccount? account;

  const _RiotLoginDialog({this.account});

  @override
  State<_RiotLoginDialog> createState() => _RiotLoginDialogState();
}

class _RiotLoginDialogState extends State<_RiotLoginDialog> {
  late final TextEditingController _riotIdController;
  late final TextEditingController _apiKeyController;
  late String _selectedRegion;
  bool _includeValorantOnDevKey = true;
  bool _obscureApiKey = true;
  bool _isLoading = false;
  String? _idError;
  String? _apiKeyError;

  @override
  void initState() {
    super.initState();
    _riotIdController = TextEditingController(
      text: widget.account?.username ?? '',
    );
    _apiKeyController = TextEditingController(
      text: widget.account?.apiKey ?? '',
    );
    final savedRegion = widget.account?.region ?? '';
    _selectedRegion = savedRegion.isNotEmpty ? savedRegion : 'na1';
  }

  @override
  void dispose() {
    _riotIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final rawId = _riotIdController.text.trim();
    final apiKey = _apiKeyController.text.trim();

    String? idErr;
    if (rawId.isEmpty) {
      idErr = 'Please enter your Riot ID (GameName#TagLine).';
    } else {
      try {
        RiotApiService.parseRiotId(rawId);
      } catch (e) {
        idErr = e.toString().replaceFirst('Exception: ', '');
      }
    }

    final String? keyErr = apiKey.isEmpty
        ? 'Please enter your Riot Games API Key.'
        : null;

    if (idErr != null || keyErr != null) {
      setState(() {
        _idError = idErr;
        _apiKeyError = keyErr;
      });
      return;
    }

    setState(() {
      _idError = null;
      _apiKeyError = null;
      _isLoading = true;
    });

    try {
      final result = await RiotApiService.importRiotLibrary(
        rawId,
        apiKey: apiKey,
        regionCode: _selectedRegion,
        includeValorantOnDevKey: _includeValorantOnDevKey,
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
          title: const Text('Riot Connection Failed'),
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
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: GamePlatform.riot.color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                GamePlatform.riot.iconData,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Riot Games Login'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect your Riot account to fetch League of Legends, TFT, Legends of Runeterra, and VALORANT along with ranks, mastery, and recent match data.',
                style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _riotIdController,
                enabled: !_isLoading,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Riot ID (GameName#TagLine)',
                  hintText: 'e.g. Faker#KR1 or Player#NA1',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  errorText: _idError,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedRegion,
                decoration: const InputDecoration(
                  labelText: 'Server / Region',
                  prefixIcon: Icon(Icons.public_rounded),
                ),
                items: RiotApiService.regions
                    .map(
                      (r) => DropdownMenuItem(
                        value: r.code,
                        child: Text(r.label, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: _isLoading
                    ? null
                    : (val) {
                        if (val != null) setState(() => _selectedRegion = val);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyController,
                enabled: !_isLoading,
                obscureText: _obscureApiKey,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _connect(),
                decoration: InputDecoration(
                  labelText: 'Riot Games API Key',
                  hintText: 'RGAPI-...',
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
                          final uri = Uri.parse(
                            RiotApiService.riotDeveloperPortalUrl,
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(
                    'Get a Riot Games API Key',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text(
                  'Include VALORANT if dev key restricts shard lookup',
                  style: TextStyle(fontSize: 12),
                ),
                value: _includeValorantOnDevKey,
                onChanged: _isLoading
                    ? null
                    : (v) => setState(
                        () => _includeValorantOnDevKey = v ?? true,
                      ),
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        'Connecting to Riot Games & fetching game stats...',
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

