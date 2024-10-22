part of 'coverage_command.dart';

class TimeLogger {
  TimeLogger(this.logger);

  final Logger logger;

  final Stopwatch _stopwatch = Stopwatch();

  bool isStopped = false;

  void start(String message) {
    if (_stopwatch.isRunning || isStopped) {
      _stopwatch.reset();
    }

    _stopwatch.start();
    logger.info(message);
    isStopped = false;
  }

  void stop(String message) {
    _stopwatch.stop();
    logger.info('✨ $message (${_stopwatch.elapsedMilliseconds}ms)');
    isStopped = true;
  }
}
