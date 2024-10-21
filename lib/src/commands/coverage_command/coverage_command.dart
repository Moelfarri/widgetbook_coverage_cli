import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:widgetbook_coverage_cli/src/error_handling/cli_exception.dart';

part 'analyze_widgetbook_usecases_target.dart';
part 'analyze_widgets_target.part.dart';
part 'directory_validator.part.dart';

////TODO: Allow user to ignore certain files, folders
/// TODO: Add a coverage file
/// TODO: Allow user to specify the output file for the coverage report
/// TODO: exclude private widgets

class CoverageCommand extends Command<int> {
  CoverageCommand({
    required Logger logger,
  }) : _logger = logger {
    argParser
      ..addOption(
        'flutter_project',
        help:
            'Target path for analyzer context of the Flutter project, defaults to the current directory if not specified.',
      )
      ..addOption(
        'widgetbook_project',
        help:
            'Target path for analyzer context of the widgetbook project, defaults to the current directory if not specified.',
      )
      ..addOption(
        'widgets_target',
        help:
            'Target path for the widgets folder, defaults to  <flutter_project>/lib if not specified.',
      )
      ..addOption(
        'widgetbook_usecases_target',
        help:
            'Target path for the widgetbook usecases folder, defaults to  <widgetbook_project>/lib if not specified.',
      );
  }

  @override
  String get description =>
      'A command that checks for widgetbook coverage in a project.';

  @override
  String get name => 'coverage';

  final Logger _logger;

  AnalysisContextCollection get analyzerContext => AnalysisContextCollection(
        includedPaths: [
          Directory(flutterProject).absolute.path,
          if (flutterProject != widgetbookProject)
            Directory(widgetbookProject).absolute.path,
        ],
      );

  String? _flutterProjectFlutterProjectName;
  String? _widgetbookProjectFlutterProjectName;

  /* --------------------------------- Options -------------------------------- */
  /// The target path used by the analyzer to include the context to output
  /// The widgets in the project and their dependencies.
  String get flutterProject =>
      argResults?['flutter_project'] as String? ?? Directory.current.path;

  /// The option used by the analyzer to include enough context to output
  /// the widgets included in widgetbook.
  String get widgetbookProject =>
      argResults?['widgetbook_project'] as String? ?? Directory.current.path;

  /// The target path for the widgets folder we wish to check for coverage.
  String get widgetsTarget =>
      argResults?['widgets_target'] as String? ?? '$flutterProject/lib';

  /// The target path for the widgetbook folder we wish to check for coverage.
  String get widgetbookUsecasesTarget =>
      argResults?['widgetbook_usecases_target'] as String? ??
      '$widgetbookProject/lib';
  /* --------------------------------- Options -------------------------------- */

  @override
  Future<int> run() async {
    try {
      if (!_isValidDirectoryInputs()) {
        return ExitCode.usage.code;
      }

      /* ---------------------- validity checks of the input ---------------------- */
      if (!_isFlutterProject() || !_isValidWidgetbookProject()) {
        return ExitCode.usage.code;
      }

      /* ---------------------- validity checks of the input ---------------------- */

      /* ------------- get file paths to be evaluated by the analyzer ------------- */
      final widgetPaths = await _getFilePaths(widgetsTarget);
      final widgetbookPaths = widgetsTarget == widgetbookUsecasesTarget
          ? widgetPaths
          : await _getFilePaths(widgetbookUsecasesTarget);
      /* ------------- get file paths to be evaluated by the analyzer ------------- */

      //TODO: test a bit different stuff
      _resolveDartFiles(
        widgetPaths,
        analyzerContext: analyzerContext,
      ).listen((data) {
        print(data);
      });

      return ExitCode.success.code;
    } on CliException catch (e) {
      _logger.err(
        e.message.split('\n').map((line) => line.trim()).join('\n'),
      );
      return e.exitCode;
    } catch (e) {
      _logger.err(e.toString());
      return ExitCode.software.code;
    }
  }

  /// gets all the absolute file paths in a directory path.
  Future<List<String>> _getFilePaths(String directoryPath) async =>
      Directory(directoryPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .map((file) => file.absolute.path)
          .toList();
}
