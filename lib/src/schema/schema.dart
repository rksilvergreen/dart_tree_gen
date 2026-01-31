// enum ????

class $Tree {
  final Map<String, $Schema> schemas;

  const $Tree({required this.schemas});
}

class _Schema {
  const _Schema();
}

const schema = const _Schema();

abstract class $Schema {
  final String? title;

  const $Schema({this.title});
}

class $Union extends $Schema {
  final Set<$Schema>? types;
  final Map<String, String> typeParameters;
  const $Union({required super.title, this.types, this.typeParameters = const {}});
}

class $Integer extends $Schema {
  final int? minimum;
  final int? exclusiveMinimum;
  final int? maximum;
  final int? exclusiveMaximum;
  final int? multipleOf;

  const $Integer({
    super.title,
    this.minimum,
    this.exclusiveMinimum,
    this.maximum,
    this.exclusiveMaximum,
    this.multipleOf,
  });
}

class $Double extends $Schema {
  final double? minimum;
  final double? exclusiveMinimum;
  final double? maximum;
  final double? exclusiveMaximum;
  final double? multipleOf;

  const $Double({
    super.title,
    this.minimum,
    this.exclusiveMinimum,
    this.maximum,
    this.exclusiveMaximum,
    this.multipleOf,
  });
}

class $String extends $Schema {
  final String? pattern;
  final int? minLength;
  final int? maxLength;
  final String? format;

  const $String({super.title, this.pattern, this.minLength, this.maxLength, this.format});
}

class $Boolean extends $Schema {
  const $Boolean({super.title});
}

class $Array extends $Schema {
  final $Schema? items;
  final int? minItems;
  final int? maxItems;
  final bool? uniqueItems;

  const $Array({super.title, this.items, this.minItems, this.maxItems, this.uniqueItems});
}

class $Object extends $Schema {
  final int? minProperties;
  final int? maxProperties;
  final List<String>? required;
  final List<String>? allowed;
  final List<String>? nullable;
  final Map<String, $Schema>? properties;
  final Map<String, $Schema>? patternProperties;

  const $Object({
    super.title,
    this.minProperties,
    this.maxProperties,
    this.required,
    this.allowed,
    this.nullable,
    this.properties,
    this.patternProperties,
  });
}

