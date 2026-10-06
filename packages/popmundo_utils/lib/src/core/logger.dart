class LogEntry {
  LogEntry({required this.level, required this.message, DateTime? at})
      : at = at ?? DateTime.now();

  final String level;
  final String message;
  final DateTime at;
}

class Logger {
  static const int capacity = 200;

  final List<LogEntry> _buffer = [];

  List<LogEntry> get buffer => List.unmodifiable(_buffer);

  void warn(String message) => _add('warn', message);

  void error(String message) => _add('error', message);

  void _add(String level, String message) {
    _buffer.add(LogEntry(level: level, message: message));
    while (_buffer.length > capacity) {
      _buffer.removeAt(0);
    }
  }
}
