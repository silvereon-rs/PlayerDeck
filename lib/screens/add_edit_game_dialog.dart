import 'package:flutter/material.dart';
import '../models.dart';
import '../main.dart';

class AddEditGameDialog extends StatefulWidget {
  final Game? gameToEdit;

  const AddEditGameDialog({super.key, this.gameToEdit});

  @override
  State<AddEditGameDialog> createState() => _AddEditGameDialogState();
}

class _AddEditGameDialogState extends State<AddEditGameDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late GamePlatform _platform;
  late GameStatus _status;
  late String _coverUrl;
  late String _bannerUrl;
  late String _developer;
  late String _publisher;
  late int _releaseYear;
  late int _metacriticScore;
  late double _personalRating;
  late double _hoursPlayed;
  late String _summary;
  late String _genre;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    final g = widget.gameToEdit;
    _title = g?.title ?? '';
    _platform = g?.platform ?? GamePlatform.steam;
    _status = g?.status ?? GameStatus.playing;
    _coverUrl = g?.coverUrl ?? '';
    _bannerUrl = g?.bannerUrl ?? '';
    _developer = g?.developer ?? '';
    _publisher = g?.publisher ?? '';
    _releaseYear = g?.releaseYear ?? DateTime.now().year;
    _metacriticScore = g?.metacriticScore ?? 80;
    _personalRating = g?.personalRating ?? 4.0;
    _hoursPlayed = g?.hoursPlayed ?? 0.0;
    _summary = g?.summary ?? '';
    _genre = g?.genre ?? 'Action RPG';
    _isFavorite = g?.isFavorite ?? false;
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final game = Game(
        id: widget.gameToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _title,
        platform: _platform,
        status: _status,
        coverUrl: _coverUrl.isNotEmpty
            ? _coverUrl
            : 'https://images.unsplash.com/photo-1550745165-9bc0b252726f?q=80&w=600&auto=format&fit=crop',
        bannerUrl: _bannerUrl.isNotEmpty
            ? _bannerUrl
            : 'https://images.unsplash.com/photo-1542751371-adc38448a05e?q=80&w=1200&auto=format&fit=crop',
        developer: _developer.isNotEmpty ? _developer : 'Indie Studio',
        publisher: _publisher.isNotEmpty ? _publisher : 'Indie Publisher',
        releaseYear: _releaseYear,
        metacriticScore: _metacriticScore,
        personalRating: _personalRating,
        hoursPlayed: _hoursPlayed,
        lastPlayed: widget.gameToEdit?.lastPlayed ?? DateTime.now(),
        summary: _summary,
        genre: _genre,
        isFavorite: _isFavorite,
        achievements: widget.gameToEdit?.achievements ?? [],
        personalNotes: widget.gameToEdit?.personalNotes,
      );
      Navigator.pop(context, game);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = AccentColorScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final double safeBottom = bottomInset > 0 ? bottomInset : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: safeBottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.gameToEdit == null ? 'Add Game to Deck' : 'Edit Game Details',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: 'Game Title *',
                  prefixIcon: Icon(Icons.videogame_asset_outlined),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter game title' : null,
                onSaved: (val) => _title = val!.trim(),
              ),
              const SizedBox(height: 14),

              // Platform Selector
              DropdownButtonFormField<GamePlatform>(
                initialValue: _platform,
                decoration: const InputDecoration(
                  labelText: 'Platform',
                  prefixIcon: Icon(Icons.devices_other_rounded),
                ),
                items: GamePlatform.values.map((p) {
                  return DropdownMenuItem(
                    value: p,
                    child: Row(
                      children: [
                        Icon(p.iconData, color: p.accentColor, size: 20),
                        const SizedBox(width: 8),
                        Text(p.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _platform = val);
                },
              ),
              const SizedBox(height: 14),

              // Status Selector
              DropdownButtonFormField<GameStatus>(
                initialValue: _status,
                decoration: const InputDecoration(
                  labelText: 'Library Status',
                  prefixIcon: Icon(Icons.bookmark_outline_rounded),
                ),
                items: GameStatus.values.map((s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(s.icon, color: s.badgeColor, size: 20),
                        const SizedBox(width: 8),
                        Text(s.displayName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
              const SizedBox(height: 14),

              // Genre & Release Year Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _genre,
                      decoration: const InputDecoration(labelText: 'Genre', prefixIcon: Icon(Icons.category_outlined)),
                      onSaved: (val) => _genre = val?.trim() ?? 'Action',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _releaseYear.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Year', prefixIcon: Icon(Icons.calendar_today_outlined)),
                      onSaved: (val) => _releaseYear = int.tryParse(val ?? '') ?? 2024,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Developer & Publisher
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _developer,
                      decoration: const InputDecoration(labelText: 'Developer', prefixIcon: Icon(Icons.business_outlined)),
                      onSaved: (val) => _developer = val?.trim() ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _publisher,
                      decoration: const InputDecoration(labelText: 'Publisher', prefixIcon: Icon(Icons.storefront_outlined)),
                      onSaved: (val) => _publisher = val?.trim() ?? '',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Playtime & Rating
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _hoursPlayed.toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Hours Played', prefixIcon: Icon(Icons.timer_outlined)),
                      onSaved: (val) => _hoursPlayed = double.tryParse(val ?? '') ?? 0.0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _metacriticScore.toString(),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Metacritic Score', prefixIcon: Icon(Icons.stars_rounded)),
                      onSaved: (val) => _metacriticScore = int.tryParse(val ?? '') ?? 80,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Image Cover & Banner URL
              TextFormField(
                initialValue: _coverUrl,
                decoration: const InputDecoration(
                  labelText: 'Cover Art Image URL',
                  prefixIcon: Icon(Icons.image_outlined),
                ),
                onSaved: (val) => _coverUrl = val?.trim() ?? '',
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: _bannerUrl,
                decoration: const InputDecoration(
                  labelText: 'Header Banner Image URL',
                  prefixIcon: Icon(Icons.aspect_ratio_rounded),
                ),
                onSaved: (val) => _bannerUrl = val?.trim() ?? '',
              ),
              const SizedBox(height: 14),

              // Summary
              TextFormField(
                initialValue: _summary,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Summary / Description',
                  alignLabelWithHint: true,
                ),
                onSaved: (val) => _summary = val?.trim() ?? '',
              ),
              const SizedBox(height: 14),

              // Favorite Toggle
              SwitchListTile(
                value: _isFavorite,
                activeThumbColor: accentColor,
                title: const Text('Mark as Favorite Game'),
                secondary: const Icon(Icons.star_rounded, color: Colors.amber),
                onChanged: (val) => setState(() => _isFavorite = val),
              ),
              const SizedBox(height: 20),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.gameToEdit == null ? 'ADD GAME TO LIBRARY' : 'SAVE CHANGES',
                    style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
