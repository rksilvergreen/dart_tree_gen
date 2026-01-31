import 'dart:async';
import 'package:build/build.dart';

/// Placeholder for the multi-file builder.
///
/// The standalone generator (StandaloneGenerator) is the primary way to use dart_tree_gen.
/// This build_runner-based builder is deprecated.
class MultiFileBuilder implements PostProcessBuilder {
  MultiFileBuilder(BuilderOptions options);

  @override
  final inputExtensions = const ['.schema_marker.json'];

  @override
  Future<void> build(PostProcessBuildStep buildStep) async {
    // Placeholder - use StandaloneGenerator instead
    log.warning('MultiFileBuilder is deprecated. Use StandaloneGenerator instead.');
  }
}
