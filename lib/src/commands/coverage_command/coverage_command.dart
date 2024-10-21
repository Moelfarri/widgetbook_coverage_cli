import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:widgetbook_coverage_cli/src/error_handling/cli_exception.dart';

part 'analyze_widget_target.part.dart';
part 'analyze_widgetbook_target.part.dart';
part 'directory_validator.extension.dart';

/*
How should the command be looking like?

widgetbook_coverage_cli coverage
  --widget_context=<project_root> 
  --widgetbook_context=<widgetbook_project_root> if not specified defaults to widget_context
  --widget_target=lib/widgets= defaults to project_root/lib if not specified
  --widgetbook_target=lib/widgetbook.dart defaults to widgetbook_project_root/lib if not specified
 */

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
        'widget_context',
        help:
            'Target path for analyzer context of the Flutter project, defaults to the current directory if not specified.',
      )
      ..addOption(
        'widgetbook_context',
        help:
            'Target path for analyzer context of the widgetbook project, defaults to the current directory if not specified.',
      )
      ..addOption(
        'widget_target',
        help:
            'Target path for the widgets folder, defaults to  <widget_context>/lib if not specified.',
      )
      ..addOption(
        'widgetbook_target',
        help:
            'Target path for the widgetbook, defaults to  <widgetbook_context>/lib if not specified.',
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
          Directory(widgetContext).absolute.path,
          if (widgetContext != widgetbookContext)
            Directory(widgetbookContext).absolute.path,
        ],
      );

  String? _widgetContextFlutterProjectName;
  String? _widgetbookContextFlutterProjectName;

  /* --------------------------------- Options -------------------------------- */
  /// The target path used by the analyzer to include the context to output
  /// The widgets in the project and their dependencies.
  String get widgetContext =>
      argResults?['widget_context'] as String? ?? Directory.current.path;

  /// The option used by the analyzer to include enough context to output
  /// the widgets included in widgetbook.
  String get widgetbookContext =>
      argResults?['widgetbook_context'] as String? ?? Directory.current.path;

  /// The target path for the widgets folder we wish to check for coverage.
  String get widgetTarget =>
      argResults?['widget_target'] as String? ?? '$widgetContext/lib';

  /// The target path for the widgetbook folder we wish to check for coverage.
  String get widgetbookTarget =>
      argResults?['widgetbook_target'] as String? ?? '$widgetbookContext/lib';
  /* --------------------------------- Options -------------------------------- */

  @override
  Future<int> run() async {
    try {
      /* ---------------------- validity checks of the input ---------------------- */
      if (!_isFlutterProject() || !_isValidWidgetbookProject()) {
        return ExitCode.usage.code;
      }

      if (!_isValidDirectory(widgetContext) ||
          !_isValidDirectory(widgetbookContext) ||
          !_isValidDirectory(widgetTarget) ||
          !_isValidDirectory(widgetbookTarget)) {
        return ExitCode.usage.code;
      }
      /* ---------------------- validity checks of the input ---------------------- */

      /* ------------- get file paths to be evaluated by the analyzer ------------- */
      final widgetPaths = await _getFilePaths(widgetTarget);
      final widgetbookPaths = widgetTarget == widgetbookTarget
          ? widgetPaths
          : await _getFilePaths(widgetbookTarget);
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
