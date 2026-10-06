import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../background/background_platform.dart';

class SchedulerPermissionsCard extends StatefulWidget {
  const SchedulerPermissionsCard({super.key, required this.platform});
  final BackgroundPlatform platform;
  @override
  State<SchedulerPermissionsCard> createState() =>
      SchedulerPermissionsCardState();
}

class SchedulerPermissionsCardState extends State<SchedulerPermissionsCard> {
  bool? _notification, _battery, _running;
  bool _pending = false, _failed = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final values = await Future.wait([
        widget.platform.isNotificationGranted(),
        widget.platform.isIgnoringBatteryOptimizations(),
        widget.platform.isRunningService(),
      ]);
      if (!mounted) return;
      setState(() {
        _notification = values[0];
        _battery = values[1];
        _running = values[2];
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _request() async {
    setState(() => _pending = true);
    try {
      if (!await widget.platform.isNotificationGranted()) {
        await widget.platform.requestNotificationPermission();
      }
      if (!await widget.platform.isIgnoringBatteryOptimizations()) {
        await widget.platform.requestIgnoreBatteryOptimization();
      }
      await refresh();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  String _value(bool? state, String yes, String no) => [
    'scheduler',
    state == null
        ? 'unknown'
        : state
        ? yes
        : no,
  ].join('.').tr();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('scheduler.permissionsExplanation'.tr()),
          const SizedBox(height: 8),
          Text(
            'scheduler.notificationStatus'.tr(
              args: [_value(_notification, 'allowed', 'denied')],
            ),
          ),
          Text(
            'scheduler.batteryStatus'.tr(
              args: [_value(_battery, 'unrestricted', 'optimized')],
            ),
          ),
          Text(
            'scheduler.serviceStatus'.tr(
              args: [_value(_running, 'running', 'stopped')],
            ),
          ),
          if (_failed)
            Text(
              'scheduler.statusFailed'.tr(),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextButton(
            key: const Key('schedule-permissions'),
            onPressed: _pending ? null : _request,
            child: Text('scheduler.permissionsAction'.tr()),
          ),
        ],
      ),
    ),
  );
}
