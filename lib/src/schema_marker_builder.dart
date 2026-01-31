import 'dart:async';
import 'package:build/build.dart';

/// Placeholder for the schema marker builder.
///
/// The standalone generator (StandaloneGenerator) is the primary way to use dart_tree_gen.
/// This build_runner-based builder is deprecated.
class SchemaMarkerBuilder implements Builder {
  SchemaMarkerBuilder(BuilderOptions options);

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.schema_marker.json'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    // Placeholder - use StandaloneGenerator instead
    log.warning('SchemaMarkerBuilder is deprecated. Use StandaloneGenerator instead.');

    // Write empty marker file to satisfy build requirements
    await buildStep.writeAsString(buildStep.inputId.changeExtension('.schema_marker.json'), '{}');
  }
}
