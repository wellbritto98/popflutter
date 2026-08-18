import 'package:flutter/material.dart';
import 'package:popmundo_utils/popmundo_utils.dart';

class CookieSummary {
  const CookieSummary({required this.name, required this.domain});

  final String name;
  final String domain;
}

class DebugOverlay extends StatefulWidget {
  const DebugOverlay({
    super.key,
    required this.host,
    required this.events,
    required this.evaluate,
    this.cookies = const [],
    this.visible = false,
    this.onClose,
    this.child,
  });

  final HostTracker host;
  final PopmundoEventBus events;
  final Future<String?> Function(String source) evaluate;
  final List<CookieSummary> cookies;
  final bool visible;
  final VoidCallback? onClose;
  final Widget? child;

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  final _networks = <NetworkEvent>[];
  final _consoles = <ConsoleEvent>[];
  final _evalController = TextEditingController();
  String? _evalResult;

  @override
  void initState() {
    super.initState();
    widget.events.network.listen((e) {
      if (mounted) setState(() => _networks.add(e));
    });
    widget.events.console.listen((e) {
      if (mounted) setState(() => _consoles.add(e));
    });
  }

  @override
  void dispose() {
    _evalController.dispose();
    super.dispose();
  }

  void _clear() {
    setState(() {
      _networks.clear();
      _consoles.clear();
      _evalResult = null;
    });
  }

  Future<void> _runEval() async {
    try {
      final result = await widget.evaluate(_evalController.text);
      setState(() => _evalResult = result ?? 'null');
    } catch (e) {
      setState(() => _evalResult = 'error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.child != null) Positioned.fill(child: widget.child!),
        if (widget.visible)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 320,
            child: Material(
              key: const Key('debug-panel'),
              color: Colors.black.withValues(alpha: 0.92),
              child: _panel(),
            ),
          ),
      ],
    );
  }

  Widget _panel() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        ListTile(
          dense: true,
          title: Text(
            'host: ${widget.host.currentOrigin.host}',
            key: const Key('debug-host'),
            style: const TextStyle(color: Colors.white),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const Key('debug-clear'),
                onPressed: _clear,
                child: const Text('clear'),
              ),
              IconButton(
                key: const Key('debug-close'),
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        if (widget.cookies.isNotEmpty)
          Wrap(
            spacing: 4,
            children: [
              for (final cookie in widget.cookies)
                Chip(label: Text('${cookie.name}@${cookie.domain}')),
            ],
          ),
        const Text('network', style: TextStyle(color: Colors.white70)),
        for (final e in _networks)
          Text(
            '${e.method} ${e.status ?? '-'} ${e.url}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        const Text('console', style: TextStyle(color: Colors.white70)),
        for (final e in _consoles)
          Text(
            '${e.level}: ${e.message}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        TextField(
          key: const Key('debug-eval-input'),
          controller: _evalController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'evaluateJavascript',
            hintStyle: TextStyle(color: Colors.white54),
          ),
        ),
        TextButton(
          key: const Key('debug-eval-run'),
          onPressed: _runEval,
          child: const Text('run'),
        ),
        if (_evalResult != null)
          Text(
            _evalResult!,
            key: const Key('debug-eval-result'),
            style: const TextStyle(color: Colors.greenAccent),
          ),
      ],
    );
  }
}
