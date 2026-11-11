import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../main.dart';
import '../profile_store.dart';
import '../cloud_sync.dart';
import '../file_helper.dart';
import '../services/epic_api_service.dart';
import 'riot_login_dialog.dart';
import 'steam_login_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(Color) onAccentChanged;
  final void Function(Color) onAccentSaved;
  final List<Color> recentColors;
  final bool isDarkMode;
  final void Function(bool) onToggleDarkMode;
  final List<Game> games;
  final List<PlatformAccount> accounts;
  final List<FriendActivity> activities;
  final Function(List<PlatformAccount> updatedAccounts) onAccountsUpdated;
  final Function(List<Game> importedGames, PlatformAccount steamAccount) onSteamLibraryImported;
  final void Function(GamePlatform platform) onPlatformLoggedOut;
  final Future<String?> Function() onSyncAllRequested;
  final VoidCallback onResetDataRequested;

  const SettingsScreen({
    super.key,
    required this.onAccentChanged,
    required this.onAccentSaved,
    required this.recentColors,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.games,
    required this.accounts,
    required this.activities,
    required this.onAccountsUpdated,
    required this.onSteamLibraryImported,
    required this.onPlatformLoggedOut,
    required this.onSyncAllRequested,
    required this.onResetDataRequested,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late List<PlatformAccount> _accounts;

  @override
  void initState() {
    super.initState();
    _accounts = List.from(widget.accounts);
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accounts != oldWidget.accounts) {
      setState(() {
        _accounts = List.from(widget.accounts);
      });
    }
  }

  void _showProfileEditor() async {
    final nameCtrl = TextEditingController(text: ProfileStore.name);
    final handleCtrl = TextEditingController(text: ProfileStore.handle);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Gamer Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Display Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: handleCtrl,
              decoration: const InputDecoration(labelText: 'Gamer Tag / Handle'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              await ProfileStore.save(
                name: nameCtrl.text.trim(),
                handle: handleCtrl.text.trim(),
              );
              if (mounted) {
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: const Text('Save Profile'),
          ),
        ],
      ),
    );
  }

  void _changeProfileAvatar() {
    pickImageFile(
      (bytes) async {
        await ProfileStore.save(
          name: ProfileStore.name,
          handle: ProfileStore.handle,
          imageBytes: bytes,
        );
        if (mounted) setState(() {});
      },
      (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Avatar error: $err')));
        }
      },
    );
  }

  void _handleSwitchToggle(PlatformAccount account, bool targetState) {
    if (targetState) {
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

  void _exportBackup() {
    CloudSync.exportLibraryToFile(widget.games, widget.accounts, widget.activities);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting PlayerDeck library backup JSON...')),
    );
  }

  void _importBackup() {
    importJsonFile(
      (jsonStr) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restoring PlayerDeck library backup...')),
        );
      },
      (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup import error: $err')),
        );
      },
    );
  }

  void _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 48),
        title: const Text('Sign Out & Clear All Data?'),
        content: const Text(
          'This will disconnect all platform accounts, clear local cache, and remove all games from PlayerDeck.\n\nAre you sure?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SIGN OUT'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      widget.onResetDataRequested();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed out & library data cleared completely.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AccentColorScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final avatarBytes = ProfileStore.imageBytes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Platforms', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Gamer Profile Header
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: accentColor.withOpacity(0.2),
                          backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes) : null,
                          child: avatarBytes == null ? Icon(Icons.person, color: accentColor, size: 28) : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: _changeProfileAvatar,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: accentColor,
                              child: const Icon(Icons.camera_alt_rounded, size: 10, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ProfileStore.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ProfileStore.handle,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _showProfileEditor,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Connected Platforms & Accounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CONNECTED PLATFORMS',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                TextButton.icon(
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
                  icon: Icon(Icons.sync_rounded, size: 16, color: accentColor),
                  label: Text('Sync All', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _accounts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final acc = _accounts[index];
                return Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _handleSwitchToggle(acc, !acc.isConnected),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: acc.platform.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(acc.platform.iconData, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      acc.platform.displayName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    if (acc.isConnected)
                                      Icon(Icons.check_circle_rounded, color: accentColor, size: 15),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  acc.isConnected ? '${acc.username} • ${acc.totalGamesCount} games synced' : 'Tap switch to connect & login',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          if (acc.isConnected)
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
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
            const SizedBox(height: 28),

            // Section 3: Data Management & Backup
            const Text(
              'DATA MANAGEMENT & BACKUP',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.download_rounded, color: accentColor),
                    title: const Text('Export JSON Library Backup'),
                    subtitle: const Text('Save your entire game collection & stats to file'),
                    onTap: _exportBackup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.upload_rounded, color: Color(0xFF29B6F6)),
                    title: const Text('Restore from JSON Backup'),
                    subtitle: const Text('Import game collection backup'),
                    onTap: _importBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Section 5: Sign Out / Clear Data
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmSignOut,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                label: const Text(
                  'SIGN OUT / CLEAR ALL DATA',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
