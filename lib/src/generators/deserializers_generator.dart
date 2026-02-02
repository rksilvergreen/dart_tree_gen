import '../schema/schema_info.dart';

/// Generates a file with generic fromJson/fromYaml functions.
class DeserializersGenerator {
  final List<SchemaInfo> schemas;
  final String sourceFileName;

  DeserializersGenerator({required this.schemas, required this.sourceFileName});

  /// Generates the deserializers file content.
  String generate() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Generated from $sourceFileName');
    buffer.writeln();
    buffer.writeln("import 'package:dart_tree/dart_tree.dart';");

    // Collect all types (including union member types) that don't have type parameters
    // Types with type parameters can't be in the generic fromJson/fromYaml since they need deserializer args
    final allTypesByDartType = <String, SchemaInfo>{};
    for (final schema in schemas) {
      if (!schema.isUnion && schema.typeParameters.isEmpty) {
        final dartType = _getDartType(schema);
        allTypesByDartType[dartType] = schema;
      } else if (schema.isUnion && schema.unionInfo!.typeParameters.isEmpty) {
        // Only add unions without type parameters
        final dartType = _getDartType(schema);
        allTypesByDartType[dartType] = schema;
        // Add union member types
        for (final type in schema.unionInfo!.types) {
          final memberDartType = _getDartType(type);
          allTypesByDartType[memberDartType] = type;
        }
      }
    }

    // Import all object files (deduplicated)
    final importedTitles = <String>{};
    for (final type in allTypesByDartType.values) {
      if (!importedTitles.contains(type.title)) {
        importedTitles.add(type.title);
        buffer.writeln("import 'objects/${_toSnakeCase(type.title)}_object.dart';");
      }
    }

    buffer.writeln();

    // Generate typedef
    buffer.writeln('typedef Deserializer<T> = T Function(String json);');
    buffer.writeln();

    // Generate fromJson function
    buffer.writeln('/// Generic fromJson function that dispatches to the correct type.');
    buffer.writeln('T fromJson<T extends TreeObject>(String json) {');

    for (final dartType in allTypesByDartType.keys) {
      buffer.writeln('  if (T == $dartType) return $dartType.fromJson(json) as T;');
    }

    buffer.writeln("  throw UnsupportedError('Type \$T is not supported for fromJson in this schema');");
    buffer.writeln('}');
    buffer.writeln();

    // Generate fromYaml function
    buffer.writeln('/// Generic fromYaml function that dispatches to the correct type.');
    buffer.writeln('T fromYaml<T extends TreeObject>(String yaml) {');

    for (final dartType in allTypesByDartType.keys) {
      buffer.writeln('  if (T == $dartType) return $dartType.fromYaml(yaml) as T;');
    }

    buffer.writeln("  throw UnsupportedError('Type \$T is not supported for fromYaml in this schema');");
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Gets the Dart type name for a schema.
  String _getDartType(SchemaInfo type) {
    if (type.title == 'String') return 'StringValue';
    if (type.title == 'Integer') return 'IntValue';
    if (type.title == 'Number') return 'DoubleValue';
    if (type.title == 'Boolean') return 'BoolValue';
    return '${type.title}Object';
  }

  /// Converts a title to snake_case for file names.
  String _toSnakeCase(String text) {
    return text
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }
}
