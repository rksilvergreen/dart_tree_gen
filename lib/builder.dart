/// Entry point for build_runner integration.
///
/// **DEPRECATED**: build_runner integration is deprecated.
/// Use the standalone generator instead:
///
/// ```bash
/// dart run dart_tree_gen:generate --directory lib
/// ```
///
/// This provides better performance and avoids build_runner complexity.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'src/tree_object_generator.dart';
import 'src/schema_based_generator.dart';
import 'src/schema_marker_builder.dart';

/// **DEPRECATED**: Use standalone generator instead.
///
/// Creates the builder for generating TreeNode classes and Tree implementations.
/// This is the legacy builder for @treeObject annotations.
@Deprecated('Use dart run dart_tree_gen:generate instead')
Builder treeObjectBuilder(BuilderOptions options) {
  return SharedPartBuilder([TreeObjectGenerator()], 'tree');
}

/// **DEPRECATED**: Use standalone generator instead.
///
/// Creates the builder for generating code from schema definitions.
/// This is the new schema-first builder for @schema annotations.
@Deprecated('Use dart run dart_tree_gen:generate instead')
Builder schemaBuilder(BuilderOptions options) {
  return SharedPartBuilder([SchemaBasedGenerator()], 'schema');
}

/// **DEPRECATED**: Use standalone generator instead.
///
/// Creates the multi-file schema builder that generates separate files.
/// This builder identifies files with @schema annotations and generates
/// individual files for each TreeObject, TreeNode, and a single Tree class.
@Deprecated('Use dart run dart_tree_gen:generate instead')
Builder schemaMarkerBuilder(BuilderOptions options) {
  return SchemaMarkerBuilder(options);
}
