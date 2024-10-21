part of 'coverage_command.dart';

extension CoverageCommandDirectoryValidator on CoverageCommand {
  /* ------------------------------ Project name ------------------------------ */
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
  /* ------------------------------ Project name ------------------------------ */

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
