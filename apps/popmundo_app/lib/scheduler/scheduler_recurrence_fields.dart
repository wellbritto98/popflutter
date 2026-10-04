import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

import 'scheduler_labels.dart';

class SchedulerRecurrenceFields extends StatelessWidget {
  const SchedulerRecurrenceFields({
    super.key,
    required this.weekly,
    required this.pending,
    required this.quantity,
    required this.unit,
    required this.days,
    required this.time,
    required this.onUnit,
    required this.onDays,
    required this.onTime,
  });
  final bool weekly, pending;
  final TextEditingController quantity;
  final IntervalUnit unit;
  final Set<int> days;
  final TimeOfDay time;
  final ValueChanged<IntervalUnit> onUnit;
  final ValueChanged<Set<int>> onDays;
  final ValueChanged<TimeOfDay> onTime;
  @override
  Widget build(BuildContext context) {
    if (!weekly) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              key: const Key('schedule-quantity'),
              controller: quantity,
              enabled: !pending,
              keyboardType: TextInputType.number,
              validator: (text) {
                final n = int.tryParse((text ?? '').trim());
                return n == null || n < 1 || n > 9999
                    ? 'scheduler.quantityError'.tr()
                    : null;
              },
              decoration: InputDecoration(
                labelText: 'scheduler.quantity'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<IntervalUnit>(
              key: const Key('schedule-unit'),
              initialValue: unit,
              decoration: InputDecoration(
                labelText: 'scheduler.unit'.tr(),
                border: const OutlineInputBorder(),
              ),
              items: IntervalUnit.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        ['scheduler.units', value.name].join('.').tr(),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: pending
                  ? null
                  : (value) {
                      if (value != null) onUnit(value);
                    },
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormField<Set<int>>(
          initialValue: days,
          validator: (_) => days.isEmpty ? 'scheduler.weekdayError'.tr() : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      key: Key('schedule-day-$day'),
                      label: Text(
                        ['scheduler.days', day.toString()].join('.').tr(),
                      ),
                      selected: days.contains(day),
                      onSelected: pending
                          ? null
                          : (selected) {
                              final next = Set<int>.of(days);
                              if (selected) {
                                next.add(day);
                              } else {
                                next.remove(day);
                              }
                              onDays(next);
                              field.didChange(next);
                            },
                    ),
                ],
              ),
              if (field.hasError)
                Text(
                  field.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        OutlinedButton.icon(
          key: const Key('schedule-time'),
          icon: const Icon(Icons.schedule),
          label: Text(
            'scheduler.localTime'.tr(
              args: [scheduleTime(time.hour, time.minute)],
            ),
          ),
          onPressed: pending
              ? null
              : () async {
                  final selected = await showTimePicker(
                    context: context,
                    initialTime: time,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (selected != null) onTime(selected);
                },
        ),
      ],
    );
  }
}
