import '../schema/schema_info.dart';

/// Generates validation code for schema constraints.
class ValidationCodeGenerator {
  /// Generates validation code for a property.
  ///
  /// Returns the validation code as a string, or empty string if no validation needed.
  String generateValidation(
    String propertyName,
    SchemaType type,
    ValidationConstraints constraints, {
    required bool isNullable,
  }) {
    if (!constraints.hasConstraints) {
      return '';
    }

    final buffer = StringBuffer();

    // Wrap in null check if nullable - use local variable for promotion
    final fieldRef = isNullable ? '${propertyName}Value' : propertyName;
    
    if (isNullable) {
      buffer.writeln('{');
      buffer.writeln('  final $fieldRef = $propertyName;');
      buffer.write('  if ($fieldRef != null) ');
    }

    buffer.write('{');

    switch (type) {
      case SchemaType.string:
        _generateStringValidation(buffer, fieldRef, constraints);
        break;
      case SchemaType.integer:
      case SchemaType.number:
        _generateNumberValidation(buffer, fieldRef, constraints, type);
        break;
      case SchemaType.array:
        _generateArrayValidation(buffer, fieldRef, constraints);
        break;
      default:
        // No validation for other types yet
        break;
    }

    buffer.write('}');
    
    if (isNullable) {
      buffer.writeln();
      buffer.write('}');
    }

    return buffer.toString();
  }

  /// Generates string-specific validation.
  void _generateStringValidation(
    StringBuffer buffer,
    String propertyName,
    ValidationConstraints constraints,
  ) {
    final checks = <String>[];

    if (constraints.minLength != null) {
      checks.add('$propertyName.value.length < ${constraints.minLength}');
    }

    if (constraints.maxLength != null) {
      checks.add('$propertyName.value.length > ${constraints.maxLength}');
    }

    if (constraints.pattern != null) {
      buffer.writeln('final _pattern_$propertyName = RegExp(r\'${constraints.pattern}\');');
      checks.add('!_pattern_$propertyName.hasMatch($propertyName.value)');
    }

    if (checks.isNotEmpty) {
      buffer.write('if (${checks.join(' || ')}) {');
      buffer.write('throw ArgumentError(\'');
      
      final errorParts = <String>[];
      if (constraints.minLength != null && constraints.maxLength != null) {
        errorParts.add('$propertyName must be ${constraints.minLength}-${constraints.maxLength} characters');
      } else if (constraints.minLength != null) {
        errorParts.add('$propertyName must be at least ${constraints.minLength} characters');
      } else if (constraints.maxLength != null) {
        errorParts.add('$propertyName must be at most ${constraints.maxLength} characters');
      }
      
      if (constraints.pattern != null) {
        errorParts.add('$propertyName must match pattern: ${constraints.pattern}');
      }
      
      buffer.write(errorParts.join(', '));
      buffer.write('\');');
      buffer.write('}');
    }
  }

  /// Generates number-specific validation.
  void _generateNumberValidation(
    StringBuffer buffer,
    String propertyName,
    ValidationConstraints constraints,
    SchemaType type,
  ) {
    final checks = <String>[];

    if (constraints.minimum != null) {
      checks.add('$propertyName.value < ${constraints.minimum}');
    }

    if (constraints.exclusiveMinimum != null) {
      checks.add('$propertyName.value <= ${constraints.exclusiveMinimum}');
    }

    if (constraints.maximum != null) {
      checks.add('$propertyName.value > ${constraints.maximum}');
    }

    if (constraints.exclusiveMaximum != null) {
      checks.add('$propertyName.value >= ${constraints.exclusiveMaximum}');
    }

    if (constraints.multipleOf != null) {
      checks.add('($propertyName.value % ${constraints.multipleOf}) != 0');
    }

    if (checks.isNotEmpty) {
      buffer.write('if (${checks.join(' || ')}) {');
      buffer.write('throw ArgumentError(\'');
      
      final errorParts = <String>[];
      if (constraints.minimum != null) {
        errorParts.add('$propertyName must be >= ${constraints.minimum}');
      }
      if (constraints.exclusiveMinimum != null) {
        errorParts.add('$propertyName must be > ${constraints.exclusiveMinimum}');
      }
      if (constraints.maximum != null) {
        errorParts.add('$propertyName must be <= ${constraints.maximum}');
      }
      if (constraints.exclusiveMaximum != null) {
        errorParts.add('$propertyName must be < ${constraints.exclusiveMaximum}');
      }
      if (constraints.multipleOf != null) {
        errorParts.add('$propertyName must be a multiple of ${constraints.multipleOf}');
      }
      
      buffer.write(errorParts.join(', '));
      buffer.write('\');');
      buffer.write('}');
    }
  }

  /// Generates array-specific validation.
  void _generateArrayValidation(
    StringBuffer buffer,
    String propertyName,
    ValidationConstraints constraints,
  ) {
    final checks = <String>[];

    if (constraints.minItems != null) {
      checks.add('$propertyName.length < ${constraints.minItems}');
    }

    if (constraints.maxItems != null) {
      checks.add('$propertyName.length > ${constraints.maxItems}');
    }

    if (checks.isNotEmpty) {
      buffer.write('if (${checks.join(' || ')}) {');
      buffer.write('throw ArgumentError(\'');
      
      final errorParts = <String>[];
      if (constraints.minItems != null && constraints.maxItems != null) {
        errorParts.add('$propertyName must have ${constraints.minItems}-${constraints.maxItems} items');
      } else if (constraints.minItems != null) {
        errorParts.add('$propertyName must have at least ${constraints.minItems} items');
      } else if (constraints.maxItems != null) {
        errorParts.add('$propertyName must have at most ${constraints.maxItems} items');
      }
      
      buffer.write(errorParts.join(', '));
      buffer.write('\');');
      buffer.write('}');
    }

    if (constraints.uniqueItems == true) {
      buffer.writeln('final _set_$propertyName = $propertyName.toSet();');
      buffer.write('if (_set_$propertyName.length != $propertyName.length) {');
      buffer.write('throw ArgumentError(\'$propertyName must have unique items\');');
      buffer.write('}');
    }
  }
}

