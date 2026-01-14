import 'dart:io';
import 'package:args/args.dart';
import 'package:dart_tree_gen/src/standalone_generator.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'directory',
      abbr: 'd',
      defaultsTo: '.',
      help: 'Directory to search for schema files',
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      defaultsTo: false,
      help: 'Watch for file changes and regenerate',
    )
    ..addFlag(
      'clean',
      abbr: 'c',
      defaultsTo: false,
      help: 'Clean generated files before generating',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage information',
    );

  final argResults = parser.parse(arguments);

  if (argResults['help'] as bool) {
    print('dart_tree_gen - Schema-based code generator');
    print('');
    print('Usage: dart run dart_tree_gen:generate [options]');
    print('');
    print(parser.usage);
    exit(0);
  }

  final directory = argResults['directory'] as String;
  final watch = argResults['watch'] as bool;
  final clean = argResults['clean'] as bool;

  print('🌳 dart_tree_gen - Standalone Generator');
  print('');
  print('Scanning directory: $directory');
  print('');

  final generator = StandaloneGenerator(Directory(directory));

  if (clean) {
    print('🧹 Cleaning generated files...');
    await generator.clean();
    print('✅ Clean complete');
    print('');
  }

  if (watch) {
    print('👀 Watching for changes...');
    await generator.watch();
  } else {
    print('⚙️  Generating files...');
    final result = await generator.generate();
    
    print('');
    print('✅ Generation complete!');
    print('   Files generated: ${result.filesGenerated}');
    print('   Schemas processed: ${result.schemasProcessed}');
    
    if (result.errors.isNotEmpty) {
      print('');
      print('❌ Errors:');
      for (final error in result.errors) {
        print('   - $error');
      }
      exit(1);
    }
  }
}

