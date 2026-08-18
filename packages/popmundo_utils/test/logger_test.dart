import 'package:popmundo_utils/popmundo_utils.dart';
import 'package:test/test.dart';

void main() {
  test('ring buffer keeps 200 newest entries', () {
    final logger = Logger();
    for (var i = 0; i < 205; i++) {
      logger.warn('w$i');
    }
    expect(logger.buffer.length, 200);
    expect(logger.buffer.first.message, 'w5');
    expect(logger.buffer.last.message, 'w204');
  });

  test('error entries are stored', () {
    final logger = Logger();
    logger.error('boom');
    expect(logger.buffer.single.level, 'error');
    expect(logger.buffer.single.message, 'boom');
  });
}
