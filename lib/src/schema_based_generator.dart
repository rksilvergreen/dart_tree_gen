import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'schema/schema_analyzer.dart';
import 'schema/schema_info.dart';
import 'generators/tree_object_class_generator.dart';
import 'generators/tree_node_class_generator.dart';

/// Generator that creates TreeObject and TreeNode classes from schema definitions.
class SchemaBasedGenerator extends Generator {
  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    // Analyze schemas
    final analyzer = SchemaAnalyzer(buildStep, library);
    final schemas = await analyzer.analyze();

    if (schemas.isEmpty) {
      return null; // No schemas found - don't generate a file
    }

    final buffer = StringBuffer();

    // Write header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from schema definitions');
    buffer.writeln();
    buffer.writeln('// ignore_for_file: unused_import, unused_element');
    buffer.writeln();

    // Deduplicate schemas by title (to avoid generating the same class multiple times)
    final uniqueSchemas = <String, SchemaInfo>{};
    for (final schema in schemas.values) {
      uniqueSchemas[schema.title] = schema;
    }

    // Generate TreeObject classes
    buffer.writeln('// ============================================================================');
    buffer.writeln('// GENERATED TREE OBJECT CLASSES');
    buffer.writeln('// ============================================================================');
    buffer.writeln();

    // First generate any custom list classes needed
    final listClasses = <String>{};
    for (final schema in uniqueSchemas.values) {
      for (final property in schema.properties.values) {
        if (property.type == SchemaType.array && property.referencedSchema != null) {
          final itemType = property.referencedSchema!.title;
          final listClassName = '${property.name.capitalize()}ListObject';
          if (!listClasses.contains(listClassName)) {
            listClasses.add(listClassName);
            buffer.writeln('/// Generated ListObject for ${property.name}');
            buffer.writeln('class $listClassName extends ListObject<${itemType}Object> {');
            buffer.writeln('  $listClassName(super.elements);');
            buffer.writeln('}');
            buffer.writeln();
          }
        }
      }
    }

    for (final schema in uniqueSchemas.values) {
      final generator = TreeObjectClassGenerator(schema);
      buffer.writeln(generator.generate());
      buffer.writeln();
    }

    // Generate TreeNode classes
    buffer.writeln('// ============================================================================');
    buffer.writeln('// GENERATED TREE NODE CLASSES');
    buffer.writeln('// ============================================================================');
    buffer.writeln();

    for (final schema in uniqueSchemas.values) {
      final generator = TreeNodeClassGenerator(schema);
      buffer.writeln(generator.generate());
      buffer.writeln();
    }

    // Generate Tree class
    buffer.writeln('// ============================================================================');
    buffer.writeln('// GENERATED TREE CLASS');
    buffer.writeln('// ============================================================================');
    buffer.writeln();
    buffer.writeln(_generateTreeClass(schemas));

    return buffer.toString();
  }

  /// Generates the unified Tree class with objectToNode implementation.
  String _generateTreeClass(Map<String, SchemaInfo> schemas) {
    // Deduplicate schemas by title
    final uniqueSchemas = <String, SchemaInfo>{};
    for (final schema in schemas.values) {
      uniqueSchemas[schema.title] = schema;
    }

    final buffer = StringBuffer();

    buffer.writeln('/// Generated Tree class with objectToNode conversion.');
    buffer.writeln('class GeneratedTree extends Tree {');
    buffer.writeln('  GeneratedTree({required super.root});');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  (TreeNode, List<(Edge, Object)>)? objectToNode(Object object) {');

    // Handle value objects
    buffer.writeln('    // Handle value objects');
    buffer.writeln('    if (object is StringValue) return (StringValueNode(object.value, jsonStringStyle: object.jsonStringStyle, yamlStringStyle: object.yamlStringStyle), []);');
    buffer.writeln('    if (object is IntValue) return (IntValueNode(object.value, jsonNumberStyle: object.jsonNumberStyle, yamlNumberStyle: object.yamlNumberStyle), []);');
    buffer.writeln('    if (object is DoubleValue) return (DoubleValueNode(object.value, jsonNumberStyle: object.jsonNumberStyle, yamlNumberStyle: object.yamlNumberStyle), []);');
    buffer.writeln('    if (object is BoolValue) return (BoolValueNode(object.value, yamlBoolStyle: object.yamlBoolStyle), []);');
    buffer.writeln('    if (object is NullValue) return (NullValueNode(yamlNullStyle: object.yamlNullStyle), []);');
    buffer.writeln();

    // Handle generated objects
    buffer.writeln('    // Handle generated objects');
    for (final schema in uniqueSchemas.values) {
      buffer.writeln('    if (object is ${schema.title}Object) {');
      buffer.writeln('      final edges = <(Edge, Object)>[];');

      for (final property in schema.properties.values) {
        final nodeType = _getNodeTypeForEdge(property);
        
        if (property.nullable) {
          buffer.writeln('      if (object.${property.name} != null) {');
          buffer.writeln('        edges.add((Edge($nodeType, \'${property.name}\'), object.${property.name}!));');
          buffer.writeln('      }');
        } else {
          buffer.writeln('      edges.add((Edge($nodeType, \'${property.name}\'), object.${property.name}));');
        }
      }

      buffer.writeln('      return (${schema.title}Node(), edges);');
      buffer.writeln('    }');
      buffer.writeln();
    }

    buffer.writeln('    return null;');
    buffer.writeln('  }');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Gets the node type for an edge.
  String _getNodeTypeForEdge(PropertyInfo property) {
    switch (property.type) {
      case SchemaType.string:
        return 'StringValueNode';
      case SchemaType.integer:
        return 'IntValueNode';
      case SchemaType.number:
        return 'DoubleValueNode';
      case SchemaType.boolean:
        return 'BoolValueNode';
      case SchemaType.object:
        return '${property.referencedSchema!.title}Node';
      case SchemaType.array:
        return 'ListTreeNode';
      case SchemaType.union:
        return 'UnionNode2';
    }
  }
}

