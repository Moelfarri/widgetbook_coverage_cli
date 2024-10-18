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
  --widget_path=lib/widgets= defaults to project_root/lib if not specified
  --widgetbook_path=lib/widgetbook.dart defaults to widgetbook_project_root/lib if not specified
 */

class CoverageCommand extends Command<int> {
  CoverageCommand({
    required Logger logger,
  }) : _logger = logger;

  @override
  String get description =>
      'A command that checks for widgetbook coverage in a project';

  @override
  String get name => 'coverage';

  final Logger _logger;

  final AnalysisContextCollection analyzerContextCollection =
      AnalysisContextCollection(
    includedPaths: [Directory.current.path],
  );

  @override
  Future<int> run() async {
    final argResults = this.argResults;

    if (!_isFlutterProjectRootDirectory()) {
      throw CliException(
        'This is not a Flutter project root directory',
        ExitCode.usage.code,
      );
    }

    //check the input of the user:
    //- is it "lib/some/path" then we know current.path is root
    //- is it "project_name/lib/src" then we know current.path/project_name is root

    //the analyzer context needs to be root, so check for a few things:
    // - check for pubspec.yaml file
    // - check for lib folder
  }

  /// Checks if the current directory is a Flutter project root directory.
  /// By checking for the presence of a pubspec.yaml file or a lib directory.
  bool _isFlutterProjectRootDirectory(String currentPath) {
    final pubspecFile = File('${Directory.current.path}/pubspec.yaml');
    final libDirectory = Directory('${Directory.current.path}/lib');

    return pubspecFile.existsSync() || libDirectory.existsSync();
  }
}
