import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduleAvailabilityScreen extends StatelessWidget {
  const ScheduleAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Availability'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _openEditor(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add slot'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('schedules').orderBy('sortKey').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load schedule availability.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No availability slots configured yet.'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final active = data['active'] != false;
              final dayLabel = _dayLabel(data['dayIndex'] as int?);
              final startTimeLabel = (data['startTimeLabel'] as String?) ?? '--:--';
              final endTimeLabel = (data['endTimeLabel'] as String?) ?? '--:--';
              final notes = (data['notes'] as String?)?.trim();

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(color: active ? Colors.blue.shade100 : Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$dayLabel · $startTimeLabel - $endTimeLabel',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ),
                          Chip(
                            label: Text(active ? 'Active' : 'Hidden'),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      if (notes != null && notes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(notes),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              await _openEditor(context, docId: doc.id, initialData: data);
                            },
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await FirebaseFirestore.instance.collection('schedules').doc(doc.id).delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Availability slot deleted.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? initialData,
  }) async {
    final result = await showDialog<_ScheduleSlotInput>(
      context: context,
      builder: (_) => ScheduleSlotEditorDialog(initialData: initialData),
    );

    if (result == null) {
      return;
    }

    final payload = {
      'dayIndex': result.dayIndex,
      'dayLabel': _dayLabel(result.dayIndex),
      'startMinutes': _minutesFromTimeOfDay(result.startTime),
      'endMinutes': _minutesFromTimeOfDay(result.endTime),
      'startTimeLabel': _formatTimeOfDay(result.startTime),
      'endTimeLabel': _formatTimeOfDay(result.endTime),
      'sortKey': result.dayIndex * 10000 + _minutesFromTimeOfDay(result.startTime),
      'notes': result.notes.trim(),
      'active': result.active,
      'updatedAt': FieldValue.serverTimestamp(),
      if (docId == null) 'createdAt': FieldValue.serverTimestamp(),
    };

    await FirebaseFirestore.instance.collection('schedules').doc(docId).set(payload, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(docId == null ? 'Availability slot added.' : 'Availability slot updated.')),
      );
    }
  }

  static String _dayLabel(int? index) {
    switch (index) {
      case 0:
        return 'Monday';
      case 1:
        return 'Tuesday';
      case 2:
        return 'Wednesday';
      case 3:
        return 'Thursday';
      case 4:
        return 'Friday';
      case 5:
        return 'Saturday';
      case 6:
        return 'Sunday';
      default:
        return 'Day';
    }
  }

  static int _minutesFromTimeOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  static String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class ScheduleSlotEditorDialog extends StatefulWidget {
  const ScheduleSlotEditorDialog({super.key, this.initialData});

  final Map<String, dynamic>? initialData;

  @override
  State<ScheduleSlotEditorDialog> createState() => _ScheduleSlotEditorDialogState();
}

class _ScheduleSlotEditorDialogState extends State<ScheduleSlotEditorDialog> {
  late int _dayIndex;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late bool _active;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    _dayIndex = initial?['dayIndex'] as int? ?? 0;
    _startTime = _timeOfDayFromMinutes(initial?['startMinutes'] as int? ?? 540);
    _endTime = _timeOfDayFromMinutes(initial?['endMinutes'] as int? ?? 600);
    _active = initial?['active'] != false;
    _notesController.text = (initial?['notes'] as String?) ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initialData == null ? 'Add availability slot' : 'Edit availability slot'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _dayIndex,
                decoration: const InputDecoration(labelText: 'Day of week'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Monday')),
                  DropdownMenuItem(value: 1, child: Text('Tuesday')),
                  DropdownMenuItem(value: 2, child: Text('Wednesday')),
                  DropdownMenuItem(value: 3, child: Text('Thursday')),
                  DropdownMenuItem(value: 4, child: Text('Friday')),
                  DropdownMenuItem(value: 5, child: Text('Saturday')),
                  DropdownMenuItem(value: 6, child: Text('Sunday')),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _dayIndex = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final selected = await showTimePicker(context: context, initialTime: _startTime);
                        if (selected != null) {
                          setState(() => _startTime = selected);
                        }
                      },
                      child: Text('Start: ${ScheduleAvailabilityScreen._formatTimeOfDay(_startTime)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final selected = await showTimePicker(context: context, initialTime: _endTime);
                        if (selected != null) {
                          setState(() => _endTime = selected);
                        }
                      },
                      child: Text('End: ${ScheduleAvailabilityScreen._formatTimeOfDay(_endTime)}'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Example: Main tutoring room, online consultation, exam prep',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: const Text('Publish this slot'),
                subtitle: const Text('Hidden slots stay saved but are not shown to students.'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_endTime.hour * 60 + _endTime.minute <= _startTime.hour * 60 + _startTime.minute) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('End time must be after start time.')),
              );
              return;
            }

            Navigator.of(context).pop(
              _ScheduleSlotInput(
                dayIndex: _dayIndex,
                startTime: _startTime,
                endTime: _endTime,
                notes: _notesController.text,
                active: _active,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  TimeOfDay _timeOfDayFromMinutes(int minutes) {
    final normalizedMinutes = minutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: normalizedMinutes ~/ 60, minute: normalizedMinutes % 60);
  }
}

class _ScheduleSlotInput {
  const _ScheduleSlotInput({
    required this.dayIndex,
    required this.startTime,
    required this.endTime,
    required this.notes,
    required this.active,
  });

  final int dayIndex;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String notes;
  final bool active;
}