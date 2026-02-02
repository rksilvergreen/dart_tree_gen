import '../schema/schema_info.dart';

/// Generates barrel file that re-exports all generated files.
class BarrelFileGenerator {
  final List<SchemaInfo> schemas;
  final String sourceBaseName;
  final List<String> listClasses;

  BarrelFileGenerator(this.schemas, this.sourceBaseName, this.listClasses);

  String generate() {
    final buffer = StringBuffer();

    // File header
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// Barrel file for $sourceBaseName schemas');
    buffer.writeln();
    buffer.writeln('library ${sourceBaseName}_generated;');
    buffer.writeln();

    // Export TreeObject files
    buffer.writeln('// TreeObject exports');
    for (final schema in schemas) {
      final fileName = _toSnakeCase(schema.title) + '_object.dart';
      buffer.writeln("export '$sourceBaseName/objects/$fileName';");
    }

    // Export custom ListObject files
    if (listClasses.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('// Custom ListObject exports');
      for (final listClass in listClasses) {
        buffer.writeln("export '$sourceBaseName/objects/$listClass.dart';");
      }
    }

    buffer.writeln();

    // Export TreeNode files
    buffer.writeln('// TreeNode exports');
    for (final schema in schemas) {
      final fileName = _toSnakeCase(schema.title) + '_node.dart';
      buffer.writeln("export '$sourceBaseName/nodes/$fileName';");
    }

    buffer.writeln();

    // Export Tree file
    buffer.writeln('// Tree export');
    buffer.writeln("export '$sourceBaseName/trees/${sourceBaseName}_tree.dart';");

    return buffer.toString();
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(RegExp(r'[A-Z]'), (m) => '_${m.group(0)!.toLowerCase()}')
        .replaceFirst(RegExp(r'^_'), '');
  }
}
