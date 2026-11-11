import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../main.dart';
import '../services/epic_api_service.dart';
import 'riot_login_dialog.dart';
import 'steam_login_dialog.dart';

class PlatformsScreen extends StatefulWidget {
  final List<PlatformAccount> accounts;
  final Function(List<PlatformAccount> updatedAccounts) onAccountsUpdated;
  final Function(List<Game> importedGames, PlatformAccount steamAccount) onSteamLibraryImported;
  final void Function(GamePlatform platform) onPlatformLoggedOut;
  final Future<String?> Function() onSyncAllRequested;

  const PlatformsScreen({
    super.key,
    required this.accounts,
    required this.onAccountsUpdated,
    required this.onSteamLibraryImported,
    required this.onPlatformLoggedOut,
    required this.onSyncAllRequested,
  });

  @override
  State<PlatformsScreen> createState() => _PlatformsScreenState();
}

class _PlatformsScreenState extends State<PlatformsScreen> {
  late List<PlatformAccount> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = List.from(widget.accounts);
  }

  @override
  void didUpdateWidget(covariant PlatformsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accounts != oldWidget.accounts) {
      setState(() {
        _accounts = List.from(widget.accounts);
      });
    }
  }

  void _handleSwitchToggle(PlatformAccount account, bool targetState) {
    if (targetState) {
      // Connect Flow
      if (account.platform == GamePlatform.steam) {
        _openSteamLoginDialog(account);
      } else if (account.platform == GamePlatform.riot) {
        _openRiotLoginDialog(account);
      } else if (account.platform == GamePlatform.epic) {
        _openEpicLoginDialog(account);
      } else {
        _openGenericPlatformConnectDialog(account);
      }
    } else {
      // Logout / Disconnect Flow
      _confirmLogout(account);
    }
  }

  void _openRiotLoginDialog(PlatformAccount account) async {
    final result = await showRiotLoginDialog(context, account: account);
    if (result == null || !mounted) return;

    final fetchedGames = result['games'] as List<Game>;
    final riotId = result['riotId'] as String;
    final avatarUrl = (result['avatarUrl'] as String?) ?? '';
    final puuid = (result['puuid'] as String?) ?? '';
    final region = (result['region'] as String?) ?? 'na1';
    final apiKey = (result['apiKey'] as String?) ?? '';
    final accentColor = AccentColorScope.of(context);

    setState(() {
      account.isConnected = true;
      account.username = riotId;
      account.avatarUrl = avatarUrl;
      account.accountId = puuid;
      account.region = region;
      account.apiKey = apiKey;
      account.lastSynced = DateTime.now();
      account.totalGamesCount = fetchedGames.length;
    });

    widget.onSteamLibraryImported(fetchedGames, account);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connected to Riot Games ($riotId)! Imported ${fetchedGames.length} games.'),
        backgroundColor: accentColor,
      ),
    );
  }

  void _openSteamLoginDialog(PlatformAccount account) async {
    final result = await showSteamLoginDialog(context, account: account);
    if (result == null || !mounted) return;

    final fetchedGames = result['games'] as List<Game>;
    final username = result['username'] as String;
    final avatarUrl = result['avatarUrl'] as String;
    final steamId64 = (result['steamId64'] as String?) ?? '';
    final apiKey = (result['apiKey'] as String?) ?? '';
    final accentColor = AccentColorScope.of(context);

    setState(() {
      account.isConnected = true;
      account.username = username;
      account.avatarUrl = avatarUrl;
      account.accountId = steamId64;
      account.apiKey = apiKey;
      account.lastSynced = DateTime.now();
      account.totalGamesCount = fetchedGames.length;
    });

    widget.onSteamLibraryImported(fetchedGames, account);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connected to Steam ($username)! Imported ${fetchedGames.length} games.'),
        backgroundColor: accentColor,
      ),
    );
  }

  void _openEpicLoginDialog(PlatformAccount account) async {
    final codeController = TextEditingController();
    bool isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !isLoading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final accentColor = AccentColorScope.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Icon(GamePlatform.epic.iconData, color: GamePlatform.epic.accentColor),
                const SizedBox(width: 10),
                const Text('Epic Games Login'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Log into your Epic Games account to auto-import your personal purchased library & entitlements.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Step 1: Sign in via Epic Games Web',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Opens official Epic Games Login Portal.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(EpicApiService.epicAuthLoginUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Open Epic Games Sign In Page'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Step 2: Paste Authorization Code / Redirect URL',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: codeController,
                    enabled: !isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Authorization Code (?code=...)',
                      hintText: 'Paste code or redirect URL after sign-in',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Submits code to POST https://account-public-service-prod.ol.epicgames.com to exchange for access_token.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                  ),
                  if (isLoading) ...[
                    const SizedBox(height: 20),
                    const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text('Exchanging OAuth Token & Fetching Epic Library...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: isLoading
                ? []
                : [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: accentColor),
                      onPressed: () async {
                        final rawCode = codeController.text.trim();
                        if (rawCode.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please paste the authorization code from Epic Games login.')),
                          );
                          return;
                        }

                        setDialogState(() => isLoading = true);

                        try {
                          String authCode = rawCode;
                          if (rawCode.contains('code=')) {
                            final match = RegExp(r'code=([a-zA-Z0-9_-]+)').firstMatch(rawCode);
                            if (match != null) {
                              authCode = match.group(1)!;
                            }
                          }

                          final result = await EpicApiService.importEpicLibrary(authCode);
                          final List<Game> fetchedGames = result['games'] as List<Game>;
                          final String displayName = result['displayName'] as String;

                          setState(() {
                            account.isConnected = true;
                            account.username = displayName;
                            account.lastSynced = DateTime.now();
                            account.totalGamesCount = fetchedGames.length;
                          });

                          widget.onSteamLibraryImported(fetchedGames, account);
                          widget.onAccountsUpdated(_accounts);

                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Connected to Epic Games ($displayName)! Imported ${fetchedGames.length} games.'),
                                backgroundColor: accentColor,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => isLoading = false);
                          if (mounted) {
                            showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 44),
                                title: const Text('Epic Games Login Failed'),
                                content: Text(e.toString().replaceAll('Exception: ', '')),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
                                ],
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Exchange Code & Import'),
                    ),
                  ],
          );
        },
      ),
    );
  }

  void _openGenericPlatformConnectDialog(PlatformAccount account) async {
    final controller = TextEditingController(text: account.username);
    final newTag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Connect ${account.platform.displayName}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: '${account.platform.displayName} Gamertag / ID',
            hintText: 'Enter account username',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Connect'),
          ),
        ],
      ),
    );

    if (newTag != null && newTag.isNotEmpty) {
      setState(() {
        account.isConnected = true;
        account.username = newTag;
        account.lastSynced = DateTime.now();
      });
      widget.onAccountsUpdated(_accounts);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connected to ${account.platform.displayName} ($newTag)')),
        );
      }
    }
  }

  void _confirmLogout(PlatformAccount account) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Disconnect ${account.platform.displayName}?'),
        content: Text(
          'Toggling off will log out your ${account.platform.displayName} account (${account.username}) and disconnect synced library data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        account.isConnected = false;
        account.username = '';
        account.avatarUrl = '';
        account.accountId = '';
        account.apiKey = '';
        account.region = '';
        account.totalGamesCount = 0;
      });

      if (account.platform == GamePlatform.steam ||
          account.platform == GamePlatform.riot) {
        widget.onPlatformLoggedOut(account.platform);
      } else {
        widget.onAccountsUpdated(_accounts);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged out of ${account.platform.displayName}')),
        );
      }
    }
  }

  void _editGamertag(PlatformAccount account) async {
    final controller = TextEditingController(text: account.username);
    final newTag = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${account.platform.displayName} ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Gamertag / Account ID'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTag != null && newTag.isNotEmpty) {
      setState(() {
        account.username = newTag;
      });
      widget.onAccountsUpdated(_accounts);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AccentColorScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Platforms', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(content: Text('Syncing game libraries across connected platforms...')),
              );
              try {
                final resultMsg = await widget.onSyncAllRequested();
                if (!mounted) return;
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(resultMsg ?? 'Platform sync complete.'),
                    backgroundColor: accentColor,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Sync failed: ${e.toString().replaceFirst('Exception: ', '')}'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unified Aggregator Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withOpacity(0.85),
                    const Color(0xFF1E2235),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 42),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Unified Library Aggregator',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Toggle platforms ON to connect & import games. Toggle OFF to log out.',
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'PLATFORM ACCOUNTS',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final acc = _accounts[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _handleSwitchToggle(acc, !acc.isConnected),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: acc.platform.color,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(acc.platform.iconData, color: Colors.white, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      acc.platform.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(width: 6),
                                    if (acc.isConnected)
                                      Icon(Icons.check_circle_rounded, color: accentColor, size: 16),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  acc.isConnected ? '${acc.username} • ${acc.totalGamesCount} games synced' : 'Tap switch to connect & login',
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          if (acc.isConnected)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editGamertag(acc),
                            ),
                          Switch(
                            value: acc.isConnected,
                            activeColor: acc.platform.accentColor,
                            onChanged: (val) => _handleSwitchToggle(acc, val),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
