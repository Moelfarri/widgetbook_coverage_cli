// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:widgetbook_coverage_cli/src/error_handling/cli_exception.dart';

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
            'Target path for the widgets folder, defaults to  <current directory>/lib if not specified.',
      )
      ..addOption(
        'widgetbook_target',
        help:
            'Target path for the widgetbook, defaults to  <current directory>/lib if not specified.',
      );
  }

  @override
  String get description =>
      'A command that checks for widgetbook coverage in a project.';

  @override
  String get name => 'coverage';

  final Logger _logger;

  final AnalysisContextCollection analyzerContextCollection =
      AnalysisContextCollection(
    includedPaths: [Directory.current.path],
  );

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
      argResults?['widget_target'] as String? ??
      '${Directory.current.path}/lib';

  /// The target path for the widgetbook folder we wish to check for coverage.
  String get widgetbookTarget =>
      argResults?['widgetbook_target'] as String? ??
      '${Directory.current.path}/lib';

  @override
  Future<int> run() async {
    try {
      /* ---------------------- validity checks of the input ---------------------- */
      if (!_isFlutterProjectRootDirectory()) {
        return ExitCode.usage.code;
      }

      if (!_isValidDirectory(widgetContext) ||
          !_isValidDirectory(widgetbookContext) ||
          !_isValidDirectory(widgetTarget) ||
          !_isValidDirectory(widgetbookTarget)) {
        return ExitCode.usage.code;
      }
      /* ---------------------- validity checks of the input ---------------------- */

      //TODO:
      // - Get all the files in the widget directory
      // - Get all the files in the widgetbook directory

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

  /// Checks if the current directory is a Flutter project root directory.
  /// By checking for the presence of a pubspec.yaml file
  /// and Flutter dependency in the pubspec.yaml file.
  bool _isFlutterProjectRootDirectory() {
    final pubspecFile = File('${Directory.current.path}/pubspec.yaml');

    // Check if pubspec.yaml exists
    if (!pubspecFile.existsSync()) {
      throw CliException(
        '''
        Cannot find a pubspec.yaml file, the coverage command can 
        only run from a Flutter project root directory.
        ''',
        ExitCode.usage.code,
      );
    }

    // Read the contents of pubspec.yaml
    final pubspecContent = pubspecFile.readAsStringSync();

    // Check for the presence of 'flutter' in the pubspec.yaml file
    if (!pubspecContent.contains('flutter:')) {
      throw CliException(
        '''
        Cannot find Flutter dependency in pubspec.yaml file, the coverage 
        command can only run from a Flutter project root directory.
        ''',
        ExitCode.usage.code,
      );
    }

    return true;
  }

  /// Checks if the provided path is a valid directory.
  bool _isValidDirectory(String path) {
    final directory = Directory(path);

    if (path.isEmpty) {
      throw CliException(
        'Empty path argument is invalid.',
        ExitCode.usage.code,
      );
    }

    if (directory.statSync().type != FileSystemEntityType.directory) {
      throw CliException(
        '$path is not a directory.',
        ExitCode.ioError.code,
      );
    }

    if (!directory.existsSync()) {
      throw CliException(
        'Directory $path not found.',
        ExitCode.ioError.code,
      );
    }

    if (directory.listSync().isEmpty) {
      throw CliException(
        'Empty directory $path cannot be set as target for coverage.',
        ExitCode.ioError.code,
      );
    }

    return true;
  }
}
