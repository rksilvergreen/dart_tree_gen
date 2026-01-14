/// Information extracted from a $Schema definition.
///
/// This represents the analyzed structure of a schema that will be used
/// to generate TreeObject and TreeNode classes.
class SchemaInfo {
  /// Variable name (e.g., 'blogPost') or generated name for inline schemas
  final String name;

  /// Class name from title property (e.g., 'BlogPost')
  final String title;

  /// Whether this schema was directly annotated with @schema
  final bool isAnnotated;

  /// Properties defined in this schema
  final Map<String, PropertyInfo> properties;

  /// List of required property names
  final List<String> required;

  /// List of allowed property names (for strict validation)
  final List<String>? allowed;

  /// List of nullable property names
  final List<String>? nullable;

  /// Minimum number of properties (for validation)
  final int? minProperties;

  /// Maximum number of properties (for validation)
  final int? maxProperties;

  /// Union information if this schema is a union type
  final UnionInfo? unionInfo;

  const SchemaInfo({
    required this.name,
    required this.title,
    required this.isAnnotated,
    required this.properties,
    this.required = const [],
    this.allowed,
    this.nullable,
    this.minProperties,
    this.maxProperties,
    this.unionInfo,
  });

  /// Whether a property is required (non-nullable)
  bool isPropertyRequired(String propertyName) {
    return required.contains(propertyName);
  }
  
  /// Whether this schema represents a union type
  bool get isUnion => unionInfo != null;
}

/// Information about a single property in a schema.
class PropertyInfo {
  /// Property name
  final String name;

  /// Property type
  final SchemaType type;

  /// Whether this property is nullable
  final bool nullable;

  /// Referenced schema for object/array types
  final SchemaInfo? referencedSchema;

  /// Union information for union types
  final UnionInfo? unionInfo;

  /// Validation constraints
  final ValidationConstraints constraints;

  const PropertyInfo({
    required this.name,
    required this.type,
    required this.nullable,
    this.referencedSchema,
    this.unionInfo,
    required this.constraints,
  });
}

/// Type of schema property.
enum SchemaType {
  string,
  integer,
  number,
  boolean,
  object,
  array,
  union,
}

/// Validation constraints for a property.
class ValidationConstraints {
  // String constraints
  final String? pattern;
  final int? minLength;
  final int? maxLength;
  final String? format;

  // Number constraints
  final num? minimum;
  final num? exclusiveMinimum;
  final num? maximum;
  final num? exclusiveMaximum;
  final num? multipleOf;

  // Array constraints
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;

  const ValidationConstraints({
    this.pattern,
    this.minLength,
    this.maxLength,
    this.format,
    this.minimum,
    this.exclusiveMinimum,
    this.maximum,
    this.exclusiveMaximum,
    this.multipleOf,
    this.minItems,
    this.maxItems,
    this.uniqueItems,
  });

  /// Whether this constraint set has any validation rules
  bool get hasConstraints =>
      pattern != null ||
      minLength != null ||
      maxLength != null ||
      format != null ||
      minimum != null ||
      exclusiveMinimum != null ||
      maximum != null ||
      exclusiveMaximum != null ||
      multipleOf != null ||
      minItems != null ||
      maxItems != null ||
      uniqueItems != null;
}

/// Information about a union type.
class UnionInfo {
  /// Union title/name
  final String title;

  /// Schemas that make up this union
  final List<SchemaInfo> types;

  /// Type parameters map: type parameter name -> constructor name
  /// e.g., {'T': 'value', 'U': 'car'}
  final Map<String, String> typeParameters;
  
  const UnionInfo({
    required this.title,
    required this.types,
    this.typeParameters = const {},
  });
}

