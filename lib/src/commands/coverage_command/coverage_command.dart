import 'dart:io';
import 'dart:isolate';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:args/command_runner.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:widgetbook_coverage_cli/src/error_handling/cli_exception.dart';

part 'analyze_widgetbook_usecases_target.dart';
part 'analyze_widgets_target.part.dart';

////TODO: Feature ideas:
/// - Allow user to ignore certain files, folders
/// - Add a coverage file
/// - Allow user to specify the output file for the coverage report
/// - Allow user to exclude private widgets

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
  String get flutterProjectProjectName {
    _flutterProjectFlutterProjectName ??= File('$flutterProject/pubspec.yaml')
        .readAsStringSync()
        .split('\n')
        .firstWhere((line) => line.contains('name:'))
        .split(':')
        .last
        .trim();
    return _flutterProjectFlutterProjectName!;
  }

  String? _widgetbookProjectFlutterProjectName;
  String get widgetbookProjectProjectName {
    _widgetbookProjectFlutterProjectName ??=
        File('$widgetbookProject/pubspec.yaml')
            .readAsStringSync()
            .split('\n')
            .firstWhere((line) => line.contains('name:'))
            .split(':')
            .last
            .trim();
    return _widgetbookProjectFlutterProjectName!;
  }

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
      /* ---------------------- validity checks of the input ---------------------- */
      if (!_isValidDirectoryInputs()) {
        return ExitCode.usage.code;
      }

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

      //TODO:
      // - evaluate the _resolveDartFiles name
      // - test getting the widgets
      // - test getting the widgetbook usecases
      // - compare the widgets and widgetbook usecases
      // - output the widgets that are not covered by the widgetbook usecases
      // - Make a figma design of how the command works currently

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

  /// Checks if the [flutterProject] directory is a Flutter project root directory.
  /// By checking for the presence of a pubspec.yaml file
  /// and Flutter dependency in the pubspec.yaml file.
  bool _isFlutterProject() {
    final pubspecFile = File('$flutterProject/pubspec.yaml').absolute;

    // Check if pubspec.yaml exists
    if (!pubspecFile.existsSync()) {
      throw CliException(
        '''
        Cannot find a pubspec.yaml file for $flutterProject, 
        the coverage command can only run from a Flutter project root directory.
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

    if (!widgetsTarget.contains(flutterProject)) {
      throw CliException(
        '''
        The flutter_project and widgets_target options should point to the
        same project. The flutter_project project is $flutterProject and
        the widgets_target project is $widgetsTarget.
        ''',
        ExitCode.usage.code,
      );
    }

    return true;
  }

  /// Checks if the [widgetbookProject] directory is a valid widgetbook project.
  /// By checking for the presence of a pubspec.yaml file
  /// and widgetbook dependency in the pubspec.yaml file.
  /// If the [widgetbookProject] is different from the [flutterProject],
  /// it checks if the widgetbook project imports the flutter project in the
  /// [flutterProject] directory.
  bool _isValidWidgetbookProject() {
    final pubspecFile = File('$widgetbookProject/pubspec.yaml');

    // Check if pubspec.yaml exists
    if (!pubspecFile.existsSync()) {
      throw CliException(
        '''
        Cannot find a pubspec.yaml file for $widgetbookProject, 
        the coverage command can only run from a Flutter project root directory.
        ''',
        ExitCode.usage.code,
      );
    }

    // Read the contents of pubspec.yaml
    final pubspecContent = pubspecFile.readAsStringSync();

    // Check for the presence of 'widgetbook' in the pubspec.yaml file
    if (!pubspecContent.contains('widgetbook:')) {
      throw CliException(
        '''
        Cannot find widgetbook dependency in pubspec.yaml file, the coverage 
        command can only run from a Flutter project containing a widgetbook
        dependency. Specify the widgetbook_project option to a project
        containing a widgetbook dependency.
        ''',
        ExitCode.usage.code,
      );
    }

    // if widgetbook context is a different project, check if the widgetbook
    // project imports the flutter project
    if (widgetbookProject != flutterProject) {
      if (!pubspecContent.contains('$flutterProjectProjectName:')) {
        throw CliException(
          '''
          The widgetbook project in $widgetbookProject does not depend on the
          Flutter project $flutterProjectProjectName. widgetbook_project
          should point to the widgetbook project related to the Flutter project
          in flutter_project $flutterProject. 
          ''',
          ExitCode.usage.code,
        );
      }
    }

    if (!widgetbookUsecasesTarget.contains(widgetbookProject)) {
      throw CliException(
        '''
        The widgetbook_project and widgetbook_usecases_target options should point to the
        same project, the widgetbook_project project is $widgetbookProject and
        and the widgetbook_usecases_target project is $widgetbookUsecasesTarget.
        ''',
        ExitCode.usage.code,
      );
    }

    return true;
  }

  bool _isValidDirectoryInputs() =>
      _isValidDirectory(
        flutterProject,
        option: 'flutter_project',
      ) &&
      _isValidDirectory(
        widgetbookProject,
        option: 'widgetbook_project',
      ) &&
      _isValidDirectory(
        widgetsTarget,
        option: 'widgets_target',
      ) &&
      _isValidDirectory(
        widgetbookUsecasesTarget,
        option: 'widgetbook_usecases_target',
      );

  /// Checks if the provided path is a valid directory.
  bool _isValidDirectory(
    String path, {
    required String option,
  }) {
    final directory = Directory(path);

    if (path.isEmpty) {
      throw CliException(
        'Empty path argument is invalid for $option.',
        ExitCode.usage.code,
      );
    }

    if (directory.statSync().type != FileSystemEntityType.directory) {
      throw CliException(
        '$path is not a directory for $option.',
        ExitCode.ioError.code,
      );
    }

    if (!directory.existsSync()) {
      throw CliException(
        'Directory $path not found for $option.',
        ExitCode.ioError.code,
      );
    }

    if (directory.listSync().isEmpty) {
      throw CliException(
        'Empty directory $path cannot be set as target for coverage for $option.',
        ExitCode.ioError.code,
      );
    }

    return true;
  }
}
