/// Information extracted from a $Schema definition.
///
/// This represents the analyzed structure of a schema that will be used
/// to generate TreeObject and TreeNode classes.
class SchemaInfo {
  /// Variable name (e.g., 'blogPost') or generated name for inline schemas
  final String name;

  /// Class name from name property (e.g., 'BlogPost')
  final String title;

  /// Whether this schema was directly annotated with @tree
  final bool isAnnotated;

  /// Type parameters defined in this schema (e.g., {'T', 'U'})
  final Set<String> typeParameters;

  /// Properties defined in this schema
  final Map<String, PropertyInfo> properties;

  /// List of required property names
  final List<String> required;

  /// List of allowed property names (for strict validation)
  final List<String>? allowed;

  /// List of nullable property names
  final List<String>? nullable;

  /// Union information if this schema is a union type
  final UnionInfo? unionInfo;

  const SchemaInfo({
    required this.name,
    required this.title,
    required this.isAnnotated,
    required this.properties,
    this.typeParameters = const {},
    this.required = const [],
    this.allowed,
    this.nullable,
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

  /// Type parameter name if this property uses a $TypeParameter
  final String? typeParameterName;

  /// Type arguments for $Object references (maps schema type param -> actual type)
  final Map<String, PropertyInfo>? typeArguments;

  /// Whether array items should be unique (generates Set instead of List)
  final bool uniqueItems;

  const PropertyInfo({
    required this.name,
    required this.type,
    required this.nullable,
    this.referencedSchema,
    this.unionInfo,
    this.typeParameterName,
    this.typeArguments,
    this.uniqueItems = false,
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

  /// Represents a type parameter reference (e.g., $TypeParameter('T'))
  typeParameter,
}

/// Information about a union type.
class UnionInfo {
  /// Union title/name
  final String title;

  /// Schemas that make up this union (concrete types)
  final List<SchemaInfo> types;

  /// Type parameters defined in this union (e.g., {'T', 'U'})
  /// The constructor name for each is derived from lowercase first letter
  final Set<String> typeParameters;

  const UnionInfo({required this.title, required this.types, this.typeParameters = const {}});
}
