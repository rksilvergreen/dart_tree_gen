import 'dart:async';
import 'dart:io';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:path/path.dart' as p;

import 'schema/schema_info.dart';
import 'schema/standalone_schema_analyzer.dart';
import 'generators/standalone_tree_object_generator.dart';
import 'generators/standalone_tree_node_generator.dart';
import 'generators/standalone_tree_generator.dart';
import 'generators/barrel_file_generator.dart';
import 'generators/deserializers_generator.dart';

/// Result of generation process.
class GenerationResult {
  final int filesGenerated;
  final int schemasProcessed;
  final List<String> errors;

  GenerationResult({
    required this.filesGenerated,
    required this.schemasProcessed,
    required this.errors,
  });
}

/// Standalone generator that runs outside build_runner.
class StandaloneGenerator {
  final Directory directory;

  StandaloneGenerator(this.directory);

  /// Generate all schema files.
  Future<GenerationResult> generate() async {
    int filesGenerated = 0;
    int schemasProcessed = 0;
    final errors = <String>[];

    try {
      // Find all .dart files with @schema annotations
      final schemaFiles = await _findSchemaFiles();

      if (schemaFiles.isEmpty) {
        print('No schema files found.');
        return GenerationResult(
          filesGenerated: 0,
          schemasProcessed: 0,
          errors: [],
        );
      }

      // Create analysis context
      final absolutePath = p.normalize(p.absolute(directory.path));
      final collection = AnalysisContextCollection(
        includedPaths: [absolutePath],
      );

      // Process each file
      for (final file in schemaFiles) {
        try {
          print('Processing: ${p.relative(file.path, from: directory.path)}');

          final result = await _generateForFile(file, collection);
          filesGenerated += result.filesGenerated;
          schemasProcessed += result.schemasCount;

          print('  ✓ Generated ${result.schemasCount} schemas');
        } on FormatException catch (e) {
          final error = 'Syntax error in ${p.basename(file.path)}: ${e.message}';
          errors.add(error);
          print('  ✗ $error');
        } on FileSystemException catch (e) {
          final error = 'File system error: ${e.message}';
          errors.add(error);
          print('  ✗ $error');
        } on Exception catch (e) {
          final error = 'Error processing ${p.basename(file.path)}: $e';
          errors.add(error);
          print('  ✗ $error');
        } catch (e, stack) {
          final error = 'Unexpected error processing ${p.basename(file.path)}: $e';
          errors.add(error);
          print('  ✗ $error');
          print('    Stack trace:');
          print('    ${stack.toString().split('\n').take(5).join('\n    ')}');
        }
      }
    } catch (e, stack) {
      errors.add('Fatal error: $e\n$stack');
    }

    return GenerationResult(
      filesGenerated: filesGenerated,
      schemasProcessed: schemasProcessed,
      errors: errors,
    );
  }

  /// Clean generated files.
  Future<void> clean() async {
    // Find and delete barrel files
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.generated.dart')) {
        await entity.delete();
        print('  Deleted: ${p.relative(entity.path, from: directory.path)}');
      }
    }

    // Find and delete generated directories (look for directories with 'objects' subdirectory)
    await for (final entity in directory.list(recursive: true)) {
      if (entity is Directory) {
        final name = p.basename(entity.path);
        if (name == 'objects' || name == 'nodes' || name == 'trees') {
          final parent = entity.parent;
          // Only delete if it looks like a generated schema directory
          if (await Directory(p.join(parent.path, 'objects')).exists() &&
              await Directory(p.join(parent.path, 'nodes')).exists() &&
              await Directory(p.join(parent.path, 'trees')).exists()) {
            await parent.delete(recursive: true);
            print('  Deleted directory: ${p.relative(parent.path, from: directory.path)}');
            break; // Break to avoid deleting subdirectories of already deleted parent
          }
        }
      }
    }
  }

  /// Watch for changes and regenerate.
  Future<void> watch() async {
    print('Watching not yet implemented. Use --no-watch for one-time generation.');
    // TODO: Implement file watching
  }

  /// Find all .dart files that might contain @schema annotations.
  Future<List<File>> _findSchemaFiles() async {
    final dartFiles = <File>[];

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        // Skip generated files, test files, and .dart_tool
        final path = entity.path;
        if (path.contains('.dart_tool') ||
            path.contains('.g.dart') ||
            path.contains('.generated.dart') ||
            path.contains('_test.dart')) {
          continue;
        }

        // Quick check if file contains @schema
        final content = await entity.readAsString();
        if (content.contains('@schema')) {
          dartFiles.add(entity);
        }
      }
    }

    return dartFiles;
  }

  /// Generate files for a single schema file.
  Future<_FileGenerationResult> _generateForFile(
    File file,
    AnalysisContextCollection collection,
  ) async {
    try {
      // Get the analysis context for this file
      final absolutePath = p.normalize(p.absolute(file.path));
      final context = collection.contextFor(absolutePath);
      final session = context.currentSession;

      // Resolve the library
      final result = await session.getResolvedLibrary(absolutePath);
      if (result is! ResolvedLibraryResult) {
        throw Exception('Could not resolve library: ${file.path}');
      }

      // Find @schema annotations
      final schemas = await _analyzeSchemas(result);

      if (schemas.isEmpty) {
        return _FileGenerationResult(filesGenerated: 0, schemasCount: 0);
      }

      // Deduplicate by title
      final uniqueSchemas = <String, SchemaInfo>{};
      for (final schema in schemas) {
        if (uniqueSchemas.containsKey(schema.title)) {
          print('  ⚠ Warning: Duplicate schema title "${schema.title}" - using last definition');
        }
        uniqueSchemas[schema.title] = schema;
      }

      // Generate files
      return await _generateFiles(file, uniqueSchemas.values.toList());
    } catch (e) {
      // Re-throw with more context
      throw Exception('Failed to generate from ${p.basename(file.path)}: $e');
    }
  }

  /// Analyze a library for schema definitions.
  Future<List<SchemaInfo>> _analyzeSchemas(ResolvedLibraryResult result) async {
    final analyzer = StandaloneSchemaAnalyzer(result);
    final schemasMap = await analyzer.analyze();
    return schemasMap.values.toList();
  }

  /// Generate all output files for a schema file.
  Future<_FileGenerationResult> _generateFiles(
    File sourceFile,
    List<SchemaInfo> schemas,
  ) async {
    final inputPath = sourceFile.path;
    final inputBaseName = p.basenameWithoutExtension(inputPath);
    final inputDir = sourceFile.parent.path;
    final outputBaseDir = p.join(inputDir, inputBaseName);

    int filesGenerated = 0;

    // Create output directories
    await Directory(p.join(outputBaseDir, 'objects')).create(recursive: true);
    await Directory(p.join(outputBaseDir, 'nodes')).create(recursive: true);
    await Directory(p.join(outputBaseDir, 'trees')).create(recursive: true);

    // Generate TreeObject files
    for (final schema in schemas) {
      final objectFileName = _toSnakeCase(schema.title) + '_object.dart';
      final objectPath = p.join(outputBaseDir, 'objects', objectFileName);

      final objectGenerator = StandaloneTreeObjectGenerator(
        schema,
        schemas,
        inputBaseName,
      );
      final objectCode = objectGenerator.generate();

      await File(objectPath).writeAsString(objectCode);
      filesGenerated++;
    }

    // Generate TreeNode files
    for (final schema in schemas) {
      final nodeFileName = _toSnakeCase(schema.title) + '_node.dart';
      final nodePath = p.join(outputBaseDir, 'nodes', nodeFileName);

      final nodeGenerator = StandaloneTreeNodeGenerator(
        schema,
        schemas,
        inputBaseName,
      );
      final nodeCode = nodeGenerator.generate();

      await File(nodePath).writeAsString(nodeCode);
      filesGenerated++;
    }

    // Generate Tree file
    final treeFileName = '${inputBaseName}_tree.dart';
    final treePath = p.join(outputBaseDir, 'trees', treeFileName);

    final treeGenerator = StandaloneTreeGenerator(
      schemas,
      inputBaseName,
    );
    final treeCode = treeGenerator.generate();

    await File(treePath).writeAsString(treeCode);
    filesGenerated++;

    // Generate deserializers file
    final deserializersFileName = '${inputBaseName}_deserializers.dart';
    final deserializersPath = p.join(outputBaseDir, deserializersFileName);

    final deserializersGenerator = DeserializersGenerator(
      schemas: schemas,
      sourceFileName: '$inputBaseName.dart',
    );
    final deserializersCode = deserializersGenerator.generate();

    await File(deserializersPath).writeAsString(deserializersCode);
    filesGenerated++;

    // Generate barrel file
    final barrelFileName = '$inputBaseName.generated.dart';
    final barrelPath = p.join(inputDir, barrelFileName);

    final barrelGenerator = BarrelFileGenerator(
      schemas,
      inputBaseName,
      [],
    );
    final barrelCode = barrelGenerator.generate();

    await File(barrelPath).writeAsString(barrelCode);
    filesGenerated++;

    return _FileGenerationResult(
      filesGenerated: filesGenerated,
      schemasCount: schemas.length,
    );
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
            RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}

class _FileGenerationResult {
  final int filesGenerated;
  final int schemasCount;

  _FileGenerationResult({
    required this.filesGenerated,
    required this.schemasCount,
  });
}

