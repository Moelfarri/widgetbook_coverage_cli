part of 'coverage_command.dart';

/// A generator function that creates one analyzer context
/// for each file and yields the resolved unit result

Stream<SomeResolvedUnitResult> _resolveDartFiles(
  /// Assumes that the files given are valid Dart files.
  List<String> filePaths, {
  required AnalysisContextCollection analyzerContext,
}) async* {
  if (filePaths.isEmpty) {
    throw CliException(
      'Empty list of files provided to analyzer context.',
      ExitCode.ioError.code,
    );
  }

  for (final filePath in filePaths) {
    final context = analyzerContext.contextFor(filePath);
    final result = await context.currentSession.getResolvedUnit(filePath);
    yield result;
  }
}
