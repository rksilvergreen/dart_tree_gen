import 'package:code_builder/code_builder.dart';
import '../analyzers/tree_object_analyzer.dart';

/// Generates serialization methods (toJson/fromJson/toYaml/fromYaml) for TreeObject classes.
class SerializationGenerator {
  final TreeObjectInfo treeObject;

  SerializationGenerator(this.treeObject);

  String generate() {
    final library = Library((b) => b
      ..body.addAll([
        _generateToJsonFunction(),
        _generateToYamlFunction(),
        _generateFromJsonFunction(),
        _generateFromYamlFunction(),
        _generateSerializationExtension(),
      ]));

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return library.accept(emitter).toString();
  }

  Extension _generateSerializationExtension() {
    return Extension((b) => b
      ..name = '${treeObject.className}Serialization'
      ..on = refer(treeObject.className)
      ..docs.add('/// Generated serialization methods for ${treeObject.className}')
      ..methods.addAll([
        _generateToJsonExtensionMethod(),
        _generateToYamlExtensionMethod(),
        _generateFromJsonExtensionMethod(),
        _generateFromYamlExtensionMethod(),
      ]));
  }

  Method _generateToJsonFunction() {
    final buffer = StringBuffer();
    buffer.writeln('final buffer = StringBuffer();');
    buffer.writeln('buffer.write(\'{\');');
    buffer.writeln('int index = 0;');
    
    for (final field in treeObject.fields) {
      if (field.isNullable) {
        buffer.writeln('if (instance.${field.name} != null) {');
        buffer.writeln('  if (index > 0) buffer.write(\', \');');
        buffer.writeln('  buffer.write(\'\"\${\'${field.name}\'}\": \');');
        buffer.writeln('  buffer.write(instance.${field.name}!.toJson());');
        buffer.writeln('  index++;');
        buffer.writeln('}');
      } else {
        buffer.writeln('if (index > 0) buffer.write(\', \');');
        buffer.writeln('buffer.write(\'\"\${\'${field.name}\'}\": \');');
        buffer.writeln('buffer.write(instance.${field.name}.toJson());');
        buffer.writeln('index++;');
      }
    }
    
    buffer.writeln('buffer.write(\'}\');');
    buffer.writeln('return buffer.toString();');

    return Method((m) => m
      ..name = '_\$${treeObject.className}ToJson'
      ..returns = refer('String')
      ..docs.add('/// Serializes [${treeObject.className}] to a JSON string.')
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'instance'
        ..type = refer(treeObject.className)))
      ..body = Code(buffer.toString()));
  }

  Method _generateToJsonExtensionMethod() {
    return Method((m) => m
      ..name = 'toJson'
      ..returns = refer('String')
      ..body = Code('return _\$${treeObject.className}ToJson(this);'));
  }

  Method _generateToYamlFunction() {
    final buffer = StringBuffer();
    buffer.writeln('final buffer = StringBuffer();');
    buffer.writeln('int index = 0;');
    
    for (final field in treeObject.fields) {
      if (field.isNullable) {
        buffer.writeln('if (instance.${field.name} != null) {');
        buffer.writeln('  if (index > 0) buffer.writeln();');
        buffer.writeln('  buffer.write(\'${field.name}: \');');
        buffer.writeln('  buffer.write(instance.${field.name}!.toYaml());');
        buffer.writeln('  index++;');
        buffer.writeln('}');
      } else {
        buffer.writeln('if (index > 0) buffer.writeln();');
        buffer.writeln('buffer.write(\'${field.name}: \');');
        buffer.writeln('buffer.write(instance.${field.name}.toYaml());');
        buffer.writeln('index++;');
      }
    }
    
    buffer.writeln('return buffer.toString();');

    return Method((m) => m
      ..name = '_\$${treeObject.className}ToYaml'
      ..returns = refer('String')
      ..docs.add('/// Serializes [${treeObject.className}] to a YAML string.')
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'instance'
        ..type = refer(treeObject.className)))
      ..body = Code(buffer.toString()));
  }

  Method _generateToYamlExtensionMethod() {
    return Method((m) => m
      ..name = 'toYaml'
      ..returns = refer('String')
      ..body = Code('return _\$${treeObject.className}ToYaml(this);'));
  }

  Method _generateFromJsonFunction() {
    final buffer = StringBuffer();
    buffer.writeln('// Parse JSON string to extract field strings');
    buffer.writeln('final fields = extractJsonObjectFields(json);');
    buffer.writeln('return ${treeObject.className}(');
    
    for (final field in treeObject.fields) {
      final fieldType = field.type.getDisplayString(withNullability: false);
      if (field.isNullable) {
        buffer.writeln('  ${field.name}: fields.containsKey(\'${field.name}\') ? ${_generateFieldJsonDecoder(fieldType, "fields['${field.name}']!")} : null,');
      } else {
        buffer.writeln('  ${field.name}: ${_generateFieldJsonDecoder(fieldType, "fields['${field.name}']!")},');
      }
    }
    
    buffer.writeln(');');

    return Method((m) => m
      ..name = '_\$${treeObject.className}FromJson'
      ..returns = refer(treeObject.className)
      ..docs.add('/// Deserializes [${treeObject.className}] from a JSON string.')
      ..docs.add('///')
      ..docs.add('/// Parses the JSON string and extracts formatting metadata.')
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'json'
        ..type = refer('String')))
      ..body = Code(buffer.toString()));
  }

  Method _generateFromYamlFunction() {
    final buffer = StringBuffer();
    buffer.writeln('// Parse YAML string to extract field strings');
    buffer.writeln('final fields = extractYamlMappingFields(yaml);');
    buffer.writeln('return ${treeObject.className}(');
    
    for (final field in treeObject.fields) {
      final fieldType = field.type.getDisplayString(withNullability: false);
      if (field.isNullable) {
        buffer.writeln('  ${field.name}: fields.containsKey(\'${field.name}\') ? ${_generateFieldYamlDecoder(fieldType, "fields['${field.name}']!")} : null,');
      } else {
        buffer.writeln('  ${field.name}: ${_generateFieldYamlDecoder(fieldType, "fields['${field.name}']!")},');
      }
    }
    
    buffer.writeln(');');

    return Method((m) => m
      ..name = '_\$${treeObject.className}FromYaml'
      ..returns = refer(treeObject.className)
      ..docs.add('/// Deserializes [${treeObject.className}] from a YAML string.')
      ..docs.add('///')
      ..docs.add('/// Parses the YAML string and extracts formatting metadata.')
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'yaml'
        ..type = refer('String')))
      ..body = Code(buffer.toString()));
  }

  String _generateFieldJsonDecoder(String fieldType, String accessor) {
    // Remove nullable marker for processing
    final baseType = fieldType.replaceAll('?', '');
    
    // Handle value types
    if (baseType == 'StringValue') return 'StringValue.fromJson($accessor)';
    if (baseType == 'IntValue') return 'IntValue.fromJson($accessor)';
    if (baseType == 'DoubleValue') return 'DoubleValue.fromJson($accessor)';
    if (baseType == 'BoolValue') return 'BoolValue.fromJson($accessor)';
    if (baseType == 'NullValue') return 'NullValue.fromJson($accessor)';
    
    // Handle custom TreeObject types - use the generated function
    return '_\$${baseType}FromJson($accessor)';
  }

  String _generateFieldYamlDecoder(String fieldType, String accessor) {
    // Remove nullable marker for processing
    final baseType = fieldType.replaceAll('?', '');
    
    // Handle value types
    if (baseType == 'StringValue') return 'StringValue.fromYaml($accessor)';
    if (baseType == 'IntValue') return 'IntValue.fromYaml($accessor)';
    if (baseType == 'DoubleValue') return 'DoubleValue.fromYaml($accessor)';
    if (baseType == 'BoolValue') return 'BoolValue.fromYaml($accessor)';
    if (baseType == 'NullValue') return 'NullValue.fromYaml($accessor)';
    
    // Handle custom TreeObject types - use the generated function
    return '_\$${baseType}FromYaml($accessor)';
  }

  Method _generateFromJsonExtensionMethod() {
    return Method((m) => m
      ..name = 'fromJson'
      ..static = true
      ..returns = refer(treeObject.className)
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'json'
        ..type = refer('String')))
      ..body = Code('return _\$${treeObject.className}FromJson(json);'));
  }

  Method _generateFromYamlExtensionMethod() {
    return Method((m) => m
      ..name = 'fromYaml'
      ..static = true
      ..returns = refer(treeObject.className)
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'yaml'
        ..type = refer('String')))
      ..body = Code('return _\$${treeObject.className}FromYaml(yaml);'));
  }
}

