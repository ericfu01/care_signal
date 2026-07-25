import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'address_autocomplete_field.dart';
import 'address_place.dart';
import 'family_models.dart';
import 'rideshare_launcher.dart';
import 'support_catalog.dart';
import 'support_repository.dart';
import 'request_duration.dart';
import 'request_priority.dart';
import 'transport_coverage_config.dart';
import 'transport_coverage_service.dart';
import 'volunteer_availability.dart';
import 'volunteer_matching.dart';

class VolunteerMessagePage extends StatefulWidget {
  const VolunteerMessagePage({
    super.key,
    required this.volunteerId,
    this.volunteerName = 'Volunteer',
  });

  final String volunteerId;
  final String volunteerName;

  @override
  State<VolunteerMessagePage> createState() => _VolunteerMessagePageState();
}

class _VolunteerMessagePageState extends State<VolunteerMessagePage> {
  static const Color _userBubble = Color(0xFF439A7D);

  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    SupportRepository.instance.seedVolunteerGreeting(
      volunteerId: widget.volunteerId,
      volunteerName: widget.volunteerName,
      greeting:
          "Hi — I'm ${widget.volunteerName}. I'm glad you reached out. How can I support you today?",
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    try {
      await SupportRepository.instance.sendVolunteerMessage(
        volunteerId: widget.volunteerId,
        volunteerName: widget.volunteerName,
        text: text,
        isUser: true,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send message: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _userBubble.withValues(alpha: 0.2),
              child: Text(
                widget.volunteerName.isNotEmpty
                    ? widget.volunteerName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: _userBubble,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.volunteerName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Support chat',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: SupportRepository.instance.watchVolunteerMessages(
                  volunteerId: widget.volunteerId,
                ),
                builder: (context, snapshot) {
                  final lines = snapshot.data ?? [];
                  if (lines.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToBottom();
                  });
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return _ChatBubble(
                        text: line['text'] as String? ?? '',
                        isUser: line['isUser'] == true,
                        userColor: _userBubble,
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Material(
            elevation: 8,
            shadowColor: Colors.black26,
            color: theme.colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Message…',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: _userBubble,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.text,
    required this.isUser,
    required this.userColor,
  });

  final String text;
  final bool isUser;
  final Color userColor;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 4),
      bottomRight: Radius.circular(isUser ? 4 : 18),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser ? userColor : Colors.white,
              borderRadius: radius,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.black87,
                  height: 1.35,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VolunteerSchedulePage extends StatefulWidget {
  const VolunteerSchedulePage({
    super.key,
    required this.volunteerId,
    this.volunteerName = 'Volunteer',
    this.volunteerUid,
  });

  final String volunteerId;
  final String volunteerName;
  final String? volunteerUid;

  @override
  State<VolunteerSchedulePage> createState() => _VolunteerSchedulePageState();
}

class _VolunteerSchedulePageState extends State<VolunteerSchedulePage> {
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;
  String? _timeError;
  List<DateTime> _timeSuggestions = const [];
  int _durationMinutes = RequestDuration.defaultForService('respite');
  bool _urgent = false;
  final _instructionsController = TextEditingController();

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _timeError = null;
        _timeSuggestions = const [];
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _timeError = null;
        _timeSuggestions = const [];
      });
    }
  }

  String _dateLabel() {
    if (_date == null) return 'Choose a date';
    final d = _date!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadSuggestions(DateTime scheduledAt) async {
    final suggestions = await VolunteerMatching.instance.scheduleSuggestions(
      catalogId: widget.volunteerId,
      start: scheduledAt,
      durationMinutes: _durationMinutes,
      volunteerUid: widget.volunteerUid,
    );
    if (!mounted) return;
    setState(() => _timeSuggestions = suggestions);
  }

  void _applySuggestion(DateTime suggestion) {
    setState(() {
      _date = DateTime(suggestion.year, suggestion.month, suggestion.day);
      _time = TimeOfDay(hour: suggestion.hour, minute: suggestion.minute);
      _timeError = null;
      _timeSuggestions = const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Book with ${widget.volunteerName}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick a date and time for a video or phone session. You will get a confirmation when they accept.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.calendar_today_rounded),
              title: const Text('Date'),
              subtitle: Text(_dateLabel()),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: const Icon(Icons.schedule_rounded),
              title: const Text('Time'),
              subtitle: Text(
                _time == null ? 'Choose a time' : _time!.format(context),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickTime,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            if (_timeError != null) ...[
              const SizedBox(height: 8),
              Text(
                _timeError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            if (_timeSuggestions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _timeSuggestions
                    .map(
                      (suggestion) => ActionChip(
                        avatar: const Icon(Icons.schedule, size: 16),
                        label: Text(
                          VolunteerAvailability.formatSuggestion(suggestion),
                        ),
                        onPressed: () => _applySuggestion(suggestion),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            RequestDurationPicker(
              selectedMinutes: _durationMinutes,
              onChanged: (value) => setState(() {
                _durationMinutes = value;
                _timeError = null;
                _timeSuggestions = const [];
              }),
            ),
            const SizedBox(height: 20),
            RequestPriorityPicker(
              urgent: _urgent,
              onChanged: (value) => setState(() => _urgent = value),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _instructionsController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Instructions for volunteer',
                hintText: 'Where should they meet you? Anything they should know?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _submitting
                  ? null
                  : () async {
                      if (_date == null || _time == null) {
                        setState(() => _timeError =
                            'Please choose both a date and a time.');
                        return;
                      }
                      final scheduledAt = DateTime(
                        _date!.year,
                        _date!.month,
                        _date!.day,
                        _time!.hour,
                        _time!.minute,
                      );
                      if (!scheduledAt.isAfter(DateTime.now())) {
                        setState(() => _timeError =
                            'Choose a date and time in the future.');
                        return;
                      }
                      if (!_urgent) {
                        final conflict = await VolunteerMatching.instance
                            .scheduleConflictMessage(
                          catalogId: widget.volunteerId,
                          start: scheduledAt,
                          durationMinutes: _durationMinutes,
                          volunteerUid: widget.volunteerUid,
                        );
                        if (conflict != null) {
                          if (!mounted) return;
                          setState(() => _timeError = conflict);
                          await _loadSuggestions(scheduledAt);
                          return;
                        }
                      }
                      setState(() => _submitting = true);
                      try {
                        await SupportRepository.instance.submitVolunteerSchedule(
                          volunteerId: widget.volunteerId,
                          volunteerName: widget.volunteerName,
                          volunteerUid: widget.volunteerUid,
                          scheduledAt: scheduledAt,
                          durationMinutes: _durationMinutes,
                          urgent: _urgent,
                          instructions: _instructionsController.text.trim(),
                        );
                        if (!context.mounted) return;
                        final timeStr = _time!.format(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Request sent for $_dateLabel() at $timeStr.',
                            ),
                          ),
                        );
                        Navigator.of(context).pop();
                      } catch (e) {
                        if (!context.mounted) return;
                        final message = e is StateError
                            ? e.message
                            : 'Could not send request: $e';
                        setState(() => _timeError = message);
                      } finally {
                        if (mounted) setState(() => _submitting = false);
                      }
                    },
              icon: const Icon(Icons.event_available_rounded),
              label: Text(_submitting ? 'Sending…' : 'Send request'),
            ),
          ],
        ),
      ),
    );
  }
}

class TransportationRequestPage extends StatefulWidget {
  const TransportationRequestPage({
    super.key,
    this.onSubmitted,
  });

  final VoidCallback? onSubmitted;

  @override
  State<TransportationRequestPage> createState() =>
      _TransportationRequestPageState();
}

class _TransportationRequestPageState extends State<TransportationRequestPage> {
  static const Color _accent = Color(0xFF7B1FA2);

  TransportCoverageConfig _coverageConfig =
      TransportCoverageConfig.defaultBayArea;
  StreamSubscription<TransportCoverageConfig>? _coverageSub;

  final _zipController = TextEditingController();
  final _pickupFieldKey = GlobalKey<AddressAutocompleteFieldState>();
  final _destinationFieldKey = GlobalKey<AddressAutocompleteFieldState>();

  AddressPlace? _pickupPlace;
  AddressPlace? _destinationPlace;
  AddressPlace? _homeAddress;

  bool _loadingZip = true;
  bool _needsNow = true;
  DateTime? _date;
  TimeOfDay? _time;
  bool _submitting = false;
  String? _scheduleError;
  List<DateTime> _timeSuggestions = const [];
  int _durationMinutes = RequestDuration.defaultForService('transport');
  bool _urgent = false;

  bool get _hasValidZip => VolunteerCoverage.isValidZip(_zipController.text);

  bool get _isCovered =>
      _hasValidZip &&
      VolunteerCoverage.isCovered(_zipController.text, _coverageConfig);

  /// Address fields only when volunteer immediate rides exist, or scheduling ahead.
  bool get _showAddressFields => _isCovered || !_needsNow;

  @override
  void initState() {
    super.initState();
    _coverageSub = TransportCoverageService.instance.watchConfig().listen(
      (config) {
        if (mounted) setState(() => _coverageConfig = config);
      },
    );
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final coverageConfig =
        await TransportCoverageService.instance.loadConfig();
    final savedZip = await SupportRepository.instance.getUserZipCode();
    final home = await SupportRepository.instance.getUserHomeAddress();
    final lastPickup = await SupportRepository.instance.getLastRidePickup();
    final lastDestination =
        await SupportRepository.instance.getLastRideDestination();
    if (!mounted) return;
    if (savedZip != null) {
      _zipController.text = savedZip;
    }
    setState(() {
      _coverageConfig = coverageConfig;
      _homeAddress = home;
      _pickupPlace = lastPickup ?? home;
      _destinationPlace = lastDestination;
      _loadingZip = false;
    });
  }

  @override
  void dispose() {
    _coverageSub?.cancel();
    _zipController.dispose();
    super.dispose();
  }

  List<AddressPlace> get _savedAddresses {
    if (_homeAddress != null && !_homeAddress!.isEmpty) {
      return [_homeAddress!];
    }
    return const [];
  }

  bool _hasAddress(AddressPlace? place) =>
      place != null && !place.isEmpty;

  bool _hasSelectedAddress(AddressPlace? place) =>
      _hasAddress(place) && place!.hasCoordinates;

  Future<AddressPlace?> _resolvePickup() =>
      _pickupFieldKey.currentState?.resolveCurrentPlace() ??
      Future.value(_pickupPlace);

  Future<AddressPlace?> _resolveDestination() =>
      _destinationFieldKey.currentState?.resolveCurrentPlace() ??
      Future.value(_destinationPlace);

  Future<void> _persistRideAddresses({
    AddressPlace? pickup,
    AddressPlace? destination,
  }) async {
    await SupportRepository.instance.saveLastRideAddresses(
      pickup: pickup,
      destination: destination,
    );
  }

  Future<void> _savePickupAsHome() async {
    if (!_hasSelectedAddress(_pickupPlace)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pick a precise pickup address from the list first.'),
        ),
      );
      return;
    }
    final home = AddressPlace(
      formattedAddress: _pickupPlace!.formattedAddress,
      label: 'Home',
      latitude: _pickupPlace!.latitude,
      longitude: _pickupPlace!.longitude,
    );
    await SupportRepository.instance.saveUserHomeAddress(home);
    if (!mounted) return;
    setState(() => _homeAddress = home);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Home address saved.')),
    );
  }

  void _onZipChanged(String _) {
    setState(() {
      if (!_isCovered) {
        _needsNow = true;
        _scheduleError = null;
        _timeSuggestions = const [];
      }
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _scheduleError = null;
        _timeSuggestions = const [];
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ??
          TimeOfDay.fromDateTime(
            DateTime.now().add(const Duration(hours: 1)),
          ),
    );
    if (picked != null) {
      setState(() {
        _time = picked;
        _scheduleError = null;
        _timeSuggestions = const [];
      });
    }
  }

  String _dateLabel() {
    if (_date == null) return 'Choose a date';
    final d = _date!;
    return '${d.month}/${d.day}/${d.year}';
  }

  Future<void> _loadSuggestions(DateTime scheduledAt) async {
    final suggestions = await VolunteerMatching.instance.scheduleSuggestions(
      catalogId: VolunteerMatching.transportCatalogId,
      start: scheduledAt,
      durationMinutes: _durationMinutes,
    );
    if (!mounted) return;
    setState(() => _timeSuggestions = suggestions);
  }

  void _applySuggestion(DateTime suggestion) {
    setState(() {
      _date = DateTime(suggestion.year, suggestion.month, suggestion.day);
      _time = TimeOfDay(hour: suggestion.hour, minute: suggestion.minute);
      _scheduleError = null;
      _timeSuggestions = const [];
    });
  }

  String get _normalizedZip => VolunteerCoverage.normalizeZip(_zipController.text);

  Future<void> _openRideshare({required bool uber}) async {
    FocusScope.of(context).unfocus();

    setState(() => _submitting = true);
    try {
      AddressPlace? pickup;
      AddressPlace? destination;
      if (_showAddressFields) {
        pickup = await _resolvePickup();
        destination = await _resolveDestination();
        if (!_hasAddress(pickup)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Enter a pickup address first.')),
          );
          return;
        }
        if (!mounted) return;
        setState(() {
          _pickupPlace = pickup;
          _destinationPlace = destination;
        });
        await _persistRideAddresses(
          pickup: pickup,
          destination: destination,
        );
      }

      final launched = uber
          ? await openUberRide(pickup: pickup, destination: destination)
          : await openLyftRide(pickup: pickup, destination: destination);
      if (!mounted) return;
      if (!launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uber ? 'Could not open Uber.' : 'Could not open Lyft.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitVolunteerRequest() async {
    if (!_hasValidZip) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 5-digit ZIP code.')),
      );
      return;
    }
    if (!_needsNow && (_date == null || _time == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a date and time.')),
      );
      return;
    }

    DateTime? scheduledAt;
    if (!_needsNow) {
      scheduledAt = DateTime(
        _date!.year,
        _date!.month,
        _date!.day,
        _time!.hour,
        _time!.minute,
      );
      if (!scheduledAt.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a time in the future.')),
        );
        return;
      }
    }

    if (!_hasAddress(_pickupPlace)) {
      final resolved = await _resolvePickup();
      if (!_hasAddress(resolved)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a pickup address.')),
        );
        return;
      }
      _pickupPlace = resolved;
    }
    final destination = await _resolveDestination();

    if (scheduledAt != null && !_urgent) {
      final conflict = await VolunteerMatching.instance.scheduleConflictMessage(
        catalogId: VolunteerMatching.transportCatalogId,
        start: scheduledAt,
        durationMinutes: _durationMinutes,
      );
      if (conflict != null) {
        if (!mounted) return;
        setState(() => _scheduleError = conflict);
        await _loadSuggestions(scheduledAt);
        return;
      }
    }

    setState(() => _submitting = true);
    try {
      await SupportRepository.instance.submitTransportationRequest(
        needsNow: _needsNow,
        scheduledAt: scheduledAt,
        pickupPlace: _pickupPlace,
        destinationPlace: destination,
        zipCode: _normalizedZip,
        volunteerCoverageAvailable: true,
        durationMinutes: _durationMinutes,
        urgent: _urgent,
      );
      await _persistRideAddresses(
        pickup: _pickupPlace,
        destination: destination,
      );
      if (!mounted) return;
      widget.onSubmitted?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _needsNow
                ? 'Ride request sent — a volunteer will respond shortly.'
                : 'Ride scheduled for $_dateLabel() at ${_time!.format(context)}.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      if (e is StateError && scheduledAt != null) {
        setState(() => _scheduleError = e.message);
        await _loadSuggestions(scheduledAt);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send request: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _coverageBanner(ThemeData theme) {
    if (!_hasValidZip) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.pin_drop_outlined, color: Colors.blue.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Enter your ZIP code to see volunteer drivers and ride options near you.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_isCovered) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Volunteer drivers are available in ${_coverageConfig.regionName} (ZIP $_normalizedZip).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'We are currently expanding our services. Transportation volunteers '
              'are not available in your area yet (ZIP $_normalizedZip). '
              'Please use Uber or Lyft below.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _volunteerCard(ThemeData theme) {
    final lane = SupportCatalog.transportationLane;
    return StreamBuilder<Map<String, List<UserProfile>>>(
      stream: VolunteerMatching.instance.watchProfilesByLane(),
      builder: (context, snap) {
        final profiles =
            snap.data?[VolunteerMatching.transportCatalogId] ?? const [];
        UserProfile? profile;
        for (final candidate in profiles) {
          if (candidate.isVolunteerAvailableNow()) {
            profile = candidate;
            break;
          }
        }
        profile ??= profiles.isNotEmpty ? profiles.first : null;

        if (profile == null) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              profiles.isEmpty
                  ? 'No transportation volunteers have signed up yet. Try Uber or Lyft below, or schedule a ride for later.'
                  : 'No transportation volunteers are available right now. Try Uber or Lyft below, or schedule for later.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
                height: 1.4,
              ),
            ),
          );
        }

        final name = profile.displayName;
        final available = profile.isVolunteerAvailableNow();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: _accent.withValues(alpha: 0.18),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      available ? '${lane.role} · Available now' : lane.role,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rideshareButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _openRideshare(uber: true),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Colors.black87,
            side: const BorderSide(color: Colors.black87),
          ),
          icon: const Icon(Icons.local_taxi_rounded),
          label: const Text(
            'Open Uber',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openRideshare(uber: false),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: const Color(0xFFE70B8B),
            side: const BorderSide(color: Color(0xFFE70B8B)),
          ),
          icon: const Icon(Icons.directions_car_rounded),
          label: const Text(
            'Open Lyft',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request a ride'),
      ),
      body: _loadingZip
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _zipController,
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onZipChanged,
                    decoration: InputDecoration(
                      labelText: 'Your ZIP code',
                      hintText: '94102',
                      counterText: '',
                      prefixIcon: const Icon(Icons.pin_drop_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _coverageBanner(theme),
                  if (_hasValidZip && !_isCovered) ...[
                    const SizedBox(height: 24),
                    Text(
                      'We are currently expanding our services, and transportation '
                      'is unavailable in your area right now. Please use Uber or Lyft.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _rideshareButtons(),
                  ] else if (_hasValidZip) ...[
                    const SizedBox(height: 24),
                    Text(
                      'When do you need a ride?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Need now'),
                          icon: Icon(Icons.directions_car_filled_rounded, size: 18),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Schedule later'),
                          icon: Icon(Icons.event_rounded, size: 18),
                        ),
                      ],
                      selected: {_needsNow},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _needsNow = selection.first;
                          _scheduleError = null;
                          _timeSuggestions = const [];
                        });
                      },
                    ),
                    if (!_needsNow) ...[
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: const Icon(Icons.calendar_today_rounded),
                        title: const Text('Date'),
                        subtitle: Text(_dateLabel()),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        leading: const Icon(Icons.schedule_rounded),
                        title: const Text('Time'),
                        subtitle: Text(
                          _time == null
                              ? 'Choose a time'
                              : _time!.format(context),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickTime,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      if (_scheduleError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _scheduleError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (_timeSuggestions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _timeSuggestions
                              .map(
                                (suggestion) => ActionChip(
                                  avatar: const Icon(Icons.schedule, size: 16),
                                  label: Text(
                                    VolunteerAvailability.formatSuggestion(
                                      suggestion,
                                    ),
                                  ),
                                  onPressed: () => _applySuggestion(suggestion),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                    if (_showAddressFields) ...[
                      const SizedBox(height: 24),
                      AddressAutocompleteField(
                        key: _pickupFieldKey,
                        label: 'Pickup location',
                        hint: 'Start typing your address…',
                        icon: Icons.trip_origin_rounded,
                        zipCode: _normalizedZip,
                        savedPlaces: _savedAddresses,
                        initialPlace: _pickupPlace,
                        onPlaceChanged: (place) {
                          setState(() => _pickupPlace = place);
                        },
                      ),
                      if (_hasSelectedAddress(_pickupPlace) &&
                          (_homeAddress == null ||
                              _pickupPlace!.formattedAddress !=
                                  _homeAddress!.formattedAddress)) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _savePickupAsHome,
                            icon: const Icon(Icons.home_outlined, size: 18),
                            label: const Text('Save as home address'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      AddressAutocompleteField(
                        key: _destinationFieldKey,
                        label: 'Destination',
                        hint: 'Doctor, school, pharmacy…',
                        icon: Icons.place_rounded,
                        zipCode: _normalizedZip,
                        savedPlaces: _savedAddresses,
                        initialPlace: _destinationPlace,
                        onPlaceChanged: (place) {
                          setState(() => _destinationPlace = place);
                        },
                      ),
                    ],
                    const SizedBox(height: 24),
                    StreamBuilder<Map<String, List<UserProfile>>>(
                      stream: VolunteerMatching.instance.watchProfilesByLane(),
                      builder: (context, snap) {
                        final profiles = snap.data?[
                                VolunteerMatching.transportCatalogId] ??
                            const <UserProfile>[];
                        final hasAvailableNow = profiles.any(
                          (profile) => profile.isVolunteerAvailableNow(),
                        );
                        final rideshareOnly = _needsNow && !hasAvailableNow;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (rideshareOnly) ...[
                              Text(
                                'No transportation volunteers are available right now. '
                                'Please use Uber or Lyft — enter your trip details in their app.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _rideshareButtons(),
                            ] else ...[
                              if (_needsNow) ...[
                                Text(
                                  'We will match you with the next available volunteer driver.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: Colors.black54,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              RequestPriorityPicker(
                                urgent: _urgent,
                                onChanged: (value) =>
                                    setState(() => _urgent = value),
                              ),
                              const SizedBox(height: 20),
                              RequestDurationPicker(
                                selectedMinutes: _durationMinutes,
                                onChanged: (value) => setState(() {
                                  _durationMinutes = value;
                                  _scheduleError = null;
                                  _timeSuggestions = const [];
                                }),
                                label: 'How long will you need the volunteer?',
                              ),
                              const SizedBox(height: 28),
                              _volunteerCard(theme),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : _submitVolunteerRequest,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _accent,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.volunteer_activism_rounded,
                                ),
                                label: Text(
                                  _submitting
                                      ? 'Sending…'
                                      : _needsNow
                                          ? 'Request volunteer ride'
                                          : 'Schedule volunteer ride',
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
