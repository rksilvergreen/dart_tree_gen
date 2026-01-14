import 'dart:async';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:path/path.dart' as p;

import 'schema/schema_analyzer.dart';
import 'schema/schema_info.dart';
import 'generators/standalone_tree_object_generator.dart';
import 'generators/standalone_tree_node_generator.dart';
import 'generators/standalone_tree_generator.dart';
import 'generators/barrel_file_generator.dart';

/// A builder that generates separate files for schemas and creates a marker.
class SchemaMarkerBuilder implements Builder {
  @override
  Map<String, List<String>> get buildExtensions => const {
        '.dart': ['.schema_gen.json'],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;

    try {
      // Create library reader
      final library = await buildStep.inputLibrary;
      final libraryReader = LibraryReader(library);

      // Analyze schemas
      final analyzer = SchemaAnalyzer(buildStep, libraryReader);
      final schemas = await analyzer.analyze();

      if (schemas.isEmpty) {
        // No schemas found - write empty marker
        await buildStep.writeAsString(
          inputId.changeExtension('.schema_gen.json'),
          '{}',
        );
        return;
      }

      // Deduplicate schemas by title
      final uniqueSchemas = <String, SchemaInfo>{};
      for (final schema in schemas.values) {
        uniqueSchemas[schema.title] = schema;
      }

      // Calculate paths
      final inputPath = inputId.path;
      final inputBaseName = p.basenameWithoutExtension(inputPath);
      final inputDir = p.dirname(inputPath);
      final outputBaseDir = p.join(inputDir, inputBaseName);

      // Generate TreeObject files
      for (final schema in uniqueSchemas.values) {
        final objectFileName = _toSnakeCase(schema.title) + '_object.dart';
        final objectPath = p.join(outputBaseDir, 'objects', objectFileName);
        final objectAssetId = AssetId(inputId.package, objectPath);

        final objectGenerator = StandaloneTreeObjectGenerator(
          schema,
          uniqueSchemas.values.toList(),
          inputBaseName,
        );
        final objectCode = objectGenerator.generate();

        await buildStep.writeAsString(objectAssetId, objectCode);
      }

      // Generate custom ListObject classes
      final listClasses = <String>{};
      for (final schema in uniqueSchemas.values) {
        for (final property in schema.properties.values) {
          if (property.type == SchemaType.array &&
              property.referencedSchema != null) {
            final listClassName = '${property.name}_list_object';
            if (!listClasses.contains(listClassName)) {
              listClasses.add(listClassName);

              final listFileName = '$listClassName.dart';
              final listPath = p.join(outputBaseDir, 'objects', listFileName);
              final listAssetId = AssetId(inputId.package, listPath);

              final itemType = property.referencedSchema!.title;
              final listCode = _generateListObjectFile(
                property.name,
                itemType,
                inputBaseName,
              );

              await buildStep.writeAsString(listAssetId, listCode);
            }
          }
        }
      }

      // Generate TreeNode files
      for (final schema in uniqueSchemas.values) {
        final nodeFileName = _toSnakeCase(schema.title) + '_node.dart';
        final nodePath = p.join(outputBaseDir, 'nodes', nodeFileName);
        final nodeAssetId = AssetId(inputId.package, nodePath);

        final nodeGenerator = StandaloneTreeNodeGenerator(
          schema,
          inputBaseName,
        );
        final nodeCode = nodeGenerator.generate();

        await buildStep.writeAsString(nodeAssetId, nodeCode);
      }

      // Generate Tree file
      final treeFileName = '${inputBaseName}_tree.dart';
      final treePath = p.join(outputBaseDir, 'trees', treeFileName);
      final treeAssetId = AssetId(inputId.package, treePath);

      final treeGenerator = StandaloneTreeGenerator(
        uniqueSchemas.values.toList(),
        inputBaseName,
      );
      final treeCode = treeGenerator.generate();

      await buildStep.writeAsString(treeAssetId, treeCode);

      // Generate barrel file
      final barrelFileName = '$inputBaseName.generated.dart';
      final barrelPath = p.join(inputDir, barrelFileName);
      final barrelAssetId = AssetId(inputId.package, barrelPath);

      final barrelGenerator = BarrelFileGenerator(
        uniqueSchemas.values.toList(),
        inputBaseName,
        listClasses.toList(),
      );
      final barrelCode = barrelGenerator.generate();

      await buildStep.writeAsString(barrelAssetId, barrelCode);

      // Write marker file
      final markerData = {
        'has_schemas': true,
        'schemas': schemas.keys.toList(),
        'schema_titles': uniqueSchemas.keys.toList(),
      };

      await buildStep.writeAsString(
        inputId.changeExtension('.schema_gen.json'),
        jsonEncode(markerData),
      );
    } catch (e) {
      // If we can't read as library (e.g., it's a part file), write empty marker
      await buildStep.writeAsString(
        inputId.changeExtension('.schema_gen.json'),
        '{}',
      );
    }
  }

  String _generateListObjectFile(
    String propertyName,
    String itemType,
    String sourceBaseName,
  ) {
    final className = '${_capitalize(propertyName)}ListObject';
    return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from $sourceBaseName.dart

import 'package:dart_tree/dart_tree.dart';
import '${_toSnakeCase(itemType)}_object.dart';

/// Generated ListObject for $propertyName
class $className extends ListObject<${itemType}Object> {
  $className(super.elements);
}
''';
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

