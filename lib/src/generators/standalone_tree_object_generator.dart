import '../schema/schema_info.dart';
import 'tree_object_class_generator.dart';

/// Generates standalone TreeObject files with imports.
class StandaloneTreeObjectGenerator {
  final SchemaInfo schema;
  final List<SchemaInfo> allSchemas;
  final String sourceBaseName;

  StandaloneTreeObjectGenerator(this.schema, this.allSchemas, this.sourceBaseName);

  String generate() {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from $sourceBaseName.dart');
    buffer.writeln();

    // Imports
    buffer.writeln("import 'package:dart_tree/dart_tree.dart';");

    // For union schemas or schemas with typeArguments in properties, import the deserializers file
    final hasTypeArgumentsInProperties = schema.properties.values.any(
      (p) => p.typeArguments != null && p.typeArguments!.isNotEmpty,
    );
    if (schema.isUnion || hasTypeArgumentsInProperties) {
      buffer.writeln("import '../${sourceBaseName}_deserializers.dart';");
    }

    // Generate class using existing generator
    final classGenerator = TreeObjectClassGenerator(schema);

    // Import referenced objects (including unions)
    final importedObjects = <String>{};

    for (final property in schema.properties.values) {
      if (property.type == SchemaType.object && property.referencedSchema != null) {
        final refTitle = property.referencedSchema!.title;
        importedObjects.add(refTitle);
        // Import type argument types (e.g. AdminObject for RefObject<AdminObject>)
        if (property.typeArguments != null) {
          for (final argProp in property.typeArguments!.values) {
            final argType = _getObjectTitleForProperty(argProp);
            if (argType != null) importedObjects.add(argType);
          }
        }
      }
      if (property.type == SchemaType.union && property.referencedSchema != null) {
        final refTitle = property.referencedSchema!.title;
        importedObjects.add(refTitle);
      }
      if (property.type == SchemaType.array && property.referencedSchema != null) {
        final refTitle = property.referencedSchema!.title;
        importedObjects.add(refTitle);
      }
    }

    // For union schemas, import the types in the union
    if (schema.isUnion) {
      for (final type in schema.unionInfo!.types) {
        if (type.title != 'String' && type.title != 'Integer' && type.title != 'Number' && type.title != 'Boolean') {
          importedObjects.add(type.title);
        }
      }
    }

    for (final refTitle in importedObjects) {
      buffer.writeln("import '${_toSnakeCase(refTitle)}_object.dart';");
    }

    buffer.writeln();

    buffer.write(classGenerator.generate());

    // Generate ListObject/MapObject classes that reference this schema
    _generateListMapObjects(buffer);

    return buffer.toString();
  }

  /// Generates ListObject classes that reference this schema as their item type.
  /// Named by item schema (e.g. ReferencesListObject for Reference), not by property name.
  void _generateListMapObjects(StringBuffer buffer) {
    final generated = <String>{};
    for (final otherSchema in allSchemas) {
      for (final property in otherSchema.properties.values) {
        void checkProperty(PropertyInfo p) {
          if (p.referencedSchema?.title == schema.title && p.type == SchemaType.array) {
            final className = _getListClassName(schema.title, p.uniqueItems);
            if (generated.add(className)) {
              buffer.writeln();
              buffer.writeln('/// Generated ListObject for ${schema.title}');
              buffer.writeln('class $className extends ListObject<${schema.title}Object> {');
              buffer.writeln('  $className(super.elements);');
              buffer.writeln('}');
            }
          }
          for (final arg in p.typeArguments?.values ?? []) {
            checkProperty(arg);
          }
        }

        checkProperty(property);
      }
    }
  }

  /// Returns list class name by item schema (e.g. ReferencesListObject for Reference).
  String _getListClassName(String itemSchemaTitle, bool uniqueItems) {
    final plural = '${itemSchemaTitle}s';
    return uniqueItems ? '${plural}SetObject' : '${plural}ListObject';
  }

  String _capitalize(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }

  /// Returns the schema title for import if this property references an object type.
  /// Returns null for primitives (String, Integer, etc.) which come from dart_tree.
  String? _getObjectTitleForProperty(PropertyInfo property) {
    if (property.type == SchemaType.object && property.referencedSchema != null) {
      return property.referencedSchema!.title;
    }
    return null;
  }
}
