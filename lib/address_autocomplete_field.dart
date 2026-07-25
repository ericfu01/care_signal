import 'dart:async';

import 'package:flutter/material.dart';

import 'address_place.dart';
import 'address_search_service.dart';

/// Address field with saved picks and search suggestions in a dropdown.
class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onPlaceChanged,
    this.savedPlaces = const [],
    this.zipCode,
    this.initialPlace,
  });

  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<AddressPlace?> onPlaceChanged;
  final List<AddressPlace> savedPlaces;
  final String? zipCode;
  final AddressPlace? initialPlace;

  @override
  State<AddressAutocompleteField> createState() =>
      AddressAutocompleteFieldState();
}

class AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  AddressPlace? _selectedPlace;
  List<AddressPlace> _searchResults = [];
  bool _searching = false;
  Timer? _debounce;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _selectedPlace = widget.initialPlace;
    if (_selectedPlace != null && !_selectedPlace!.isEmpty) {
      _controller.text = _selectedPlace!.displayLabel;
    }
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant AddressAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialPlace != oldWidget.initialPlace &&
        widget.initialPlace != null &&
        !_focusNode.hasFocus) {
      _applyPlace(widget.initialPlace!, notify: false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() => _showSuggestions = _focusNode.hasFocus);
    if (_focusNode.hasFocus && _controller.text.trim().length >= 3) {
      _runSearch(_controller.text);
    }
  }

  Future<void> _applyPlace(AddressPlace place, {bool notify = true}) async {
    var resolved = place;
    final needsResolve = place.placeId != null && !place.hasCoordinates;
    if (needsResolve) {
      setState(() => _searching = true);
      resolved = await AddressSearchService.instance.resolvePlace(place) ?? place;
      if (!mounted) return;
      setState(() => _searching = false);
    }

    setState(() {
      _selectedPlace = resolved;
      _controller.text = resolved.displayLabel;
      _showSuggestions = false;
      _searchResults = [];
    });
    _focusNode.unfocus();
    if (notify) widget.onPlaceChanged(resolved);
  }

  void _onTextChanged(String value) {
    final trimmed = value.trim();
    setState(() {
      _selectedPlace = null;
      _showSuggestions = _focusNode.hasFocus;
    });
    widget.onPlaceChanged(
      trimmed.isEmpty
          ? null
          : AddressPlace(formattedAddress: trimmed),
    );

    _debounce?.cancel();
    if (trimmed.length < 3) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _runSearch(trimmed);
    });
  }

  String get currentText => _controller.text.trim();

  /// Selected place, geocoded match, or typed text — for Uber/Lyft handoff.
  Future<AddressPlace?> resolveCurrentPlace() async {
    if (_selectedPlace != null && !_selectedPlace!.isEmpty) {
      return _selectedPlace;
    }

    final text = currentText;
    if (text.isEmpty) return null;

    final results = await AddressSearchService.instance.search(
      text,
      zipCode: widget.zipCode,
    );
    if (!mounted) return AddressPlace(formattedAddress: text);

    if (results.isNotEmpty) {
      final best =
          await AddressSearchService.instance.resolvePlace(results.first) ??
              results.first;
      if (!mounted) return best;
      setState(() {
        _selectedPlace = best;
        _controller.text = best.displayLabel;
        _showSuggestions = false;
        _searchResults = [];
      });
      widget.onPlaceChanged(best);
      return best;
    }

    final draft = AddressPlace(formattedAddress: text);
    final resolved =
        await AddressSearchService.instance.resolvePlace(draft) ?? draft;
    if (!mounted) return resolved;
    widget.onPlaceChanged(resolved);
    return resolved;
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await AddressSearchService.instance.search(
      query,
      zipCode: widget.zipCode,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  List<AddressPlace> get _savedOptions {
    return widget.savedPlaces.where((place) => !place.isEmpty).toList();
  }

  bool get _hasDropdownContent =>
      _savedOptions.isNotEmpty || _searchResults.isNotEmpty || _searching;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.words,
          onChanged: _onTextChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _selectedPlace?.hasCoordinates == true
                    ? Icon(Icons.check_circle, color: Colors.green.shade600)
                    : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _selectedPlace?.hasCoordinates == true
              ? _selectedPlace!.formattedAddress
              : 'Tap a search result, or Open Uber/Lyft — we will look up what you typed.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: _selectedPlace?.hasCoordinates == true
                ? Colors.black54
                : Colors.black45,
            height: 1.3,
          ),
        ),
        if (_showSuggestions && _hasDropdownContent) ...[
          const SizedBox(height: 8),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_savedOptions.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Text(
                      'Your addresses',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  for (final place in _savedOptions)
                    _AddressSuggestionTile(
                      place: place,
                      leadingIcon: Icons.home_rounded,
                      onTap: () => _applyPlace(place),
                    ),
                  if (_searchResults.isNotEmpty || _searching)
                    const Divider(height: 1),
                ],
                if (_searchResults.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                    child: Text(
                      'Search results',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  for (final place in _searchResults)
                    _AddressSuggestionTile(
                      place: place,
                      leadingIcon: Icons.place_outlined,
                      onTap: () => _applyPlace(place),
                    ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AddressSuggestionTile extends StatelessWidget {
  const _AddressSuggestionTile({
    required this.place,
    required this.leadingIcon,
    required this.onTap,
  });

  final AddressPlace place;
  final IconData leadingIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(leadingIcon, size: 22),
      title: Text(
        place.displayLabel,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: place.subtitle.isNotEmpty
          ? Text(
              place.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: onTap,
    );
  }
}
