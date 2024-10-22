part of 'coverage_command.dart';

/// Spawns an isolate to resolve the widgets in a flutter project
/// and returns the list of widgets found.
Future<List<String>> _getProjectWidgets(
  PathData pathData,
  Logger logger,
) async {
  final timerLogger = TimeLogger(logger);
  timerLogger.start('Resolving widgets...');

  final widgetReceivePort = ReceivePort();
  final widgetIsolateTask = await Isolate.spawn(
    _resolveFlutterProjectWidgets,
    InitialIsolateData(
      sendPort: widgetReceivePort.sendPort,
      filePaths: pathData.filePaths,
      projectRootPath: pathData.projectRootPath,
    ),
  );

  var widgets = <String>[];

  await for (final data in widgetReceivePort) {
    if (data is! SenderPortData) continue;
    if (data.isFinished) {
      widgets = [...data.result];
      widgetIsolateTask.kill();
      stdout.write('\r');
      timerLogger.stop('Total widgets found: ${data.result.length}');
      break;
    }
    stdout.write('\rWidgets found: ${data.result.length}'.padRight(30));
  }

  return widgets;
}

/// Resolves the widgets in a flutter project,
/// run in a seperate isolate as it is a heavy operation
Future<void> _resolveFlutterProjectWidgets(InitialIsolateData data) async {
  final widgetVisitor = WidgetVisitor();

  final analyzerContext = AnalysisContextCollection(
    includedPaths: [
      Directory(data.projectRootPath).absolute.path,
    ],
  );

  for (final filePath in data.filePaths) {
    final context = analyzerContext.contextFor(filePath);
    final result = await context.currentSession.getResolvedUnit(filePath);

    if (result is! ResolvedUnitResult) continue;

    result.unit.visitChildren(widgetVisitor);
    data.sendPort.send(
      SenderPortData(
        result: widgetVisitor.widgets,
      ),
    );
  }

  // signals the end of the stream
  analyzerContext.dispose();
  data.sendPort.send(
    SenderPortData(
      isFinished: true,
      result: widgetVisitor.widgets,
    ),
  );
}
