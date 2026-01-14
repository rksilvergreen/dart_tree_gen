import 'dart:async';
import 'dart:convert';
import 'package:build/build.dart';
import 'package:path/path.dart' as p;

import 'schema/schema_analyzer.dart';
import 'schema/schema_info.dart';
import 'generators/standalone_tree_object_generator.dart';
import 'generators/standalone_tree_node_generator.dart';
import 'generators/standalone_tree_generator.dart';
import 'generators/barrel_file_generator.dart';

/// A post-process builder that generates separate files for each TreeObject, TreeNode, and Tree class.
///
/// For a source file like `blog_post_schema.dart`, this builder generates:
/// - `blog_post_schema/objects/*.dart` - One file per TreeObject
/// - `blog_post_schema/nodes/*.dart` - One file per TreeNode
/// - `blog_post_schema/trees/blog_post_schema_tree.dart` - Single Tree class
/// - `blog_post_schema.generated.dart` - Barrel file that exports all
class MultiFileSchemaBuilder implements PostProcessBuilder {
  @override
  final inputExtensions = const ['.schema_gen.json'];

  @override
  Future<void> build(PostProcessBuildStep buildStep) async {
    final inputId = buildStep.inputId;
    
    // Read the marker file
    final markerAsset = buildStep.inputId;
    final markerContent = await buildStep.readAsString(markerAsset);
    
    if (markerContent == '{}') {
      // No schemas in this file
      return;
    }
    
    // Parse marker metadata
    final marker = jsonDecode(markerContent) as Map<String, dynamic>;
    final hasSchemas = marker['has_schemas'] as bool?;
    
    if (hasSchemas != true) {
      return;
    }
    
    // Get schema data from marker
    final schemasData = marker['schemas_data'] as List?;
    if (schemasData == null || schemasData.isEmpty) {
      return;
    }
    
    // Deserialize schemas
    final schemaInfos = schemasData
        .map((data) => SchemaInfo.fromJson(data as Map<String, dynamic>))
        .toList();

    // Deduplicate schemas by title
    final uniqueSchemas = <String, SchemaInfo>{};
    for (final schema in schemaInfos.values) {
      uniqueSchemas[schema.title] = schema;
    }

    // Calculate base directory name from original dart file
    final dartPath = originalDartFile.path;
    final inputBaseName = p.basenameWithoutExtension(dartPath).replaceAll('.dart', '');
    final inputDir = p.dirname(dartPath);
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
        if (property.type == SchemaType.array && property.referencedSchema != null) {
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
  }

  /// Generates a custom ListObject file.
  String _generateListObjectFile(
    String propertyName,
    String itemType,
    String sourceBaseName,
  ) {
    final className = '${_capitalize(propertyName)}ListObject';
    return '''
// GENERATED CODE - DO NOT MODIFY BY HAND
// Generated from schema definitions

import 'package:dart_tree/dart_tree.dart';
import '${_toSnakeCase(itemType)}_object.dart';

/// Generated ListObject for $propertyName
class $className extends ListObject<${itemType}Object> {
  $className(super.elements);
}
''';
  }

  /// Converts a string to snake_case.
  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  /// Capitalizes the first letter of a string.
  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }
}

