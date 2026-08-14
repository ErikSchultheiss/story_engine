/// Immutable declarative payload preserved for one opaque Story Format
/// extension.
///
/// Payload values are restricted to the portable JSON-shaped value domain:
/// null, Boolean, String, portable Integer, finite Number, ordered lists, and
/// string-keyed objects containing the same values. No callbacks, Dart source,
/// classes, or executable code can be embedded through this API.
final class StoryFormatExtensionPayload {
  factory StoryFormatExtensionPayload(Object? value) =>
      StoryFormatExtensionPayload._(_copyAndValidate(value, r'$'));

  StoryFormatExtensionPayload._(this.value);

  /// Deeply immutable normalized payload value.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoryFormatExtensionPayload &&
          _deepEquals(value, other.value);

  @override
  int get hashCode => Object.hash(
    StoryFormatExtensionPayload,
    _deepHash(value),
  );

  @override
  String toString() => 'StoryFormatExtensionPayload($value)';
}

const int _maxPortableInteger = 9007199254740991;
const int _minPortableInteger = -9007199254740991;

Object? _copyAndValidate(Object? value, String path) {
  if (value == null || value is bool || value is String) {
    return value;
  }

  if (value is int) {
    if (value < _minPortableInteger || value > _maxPortableInteger) {
      throw ArgumentError.value(
        value,
        path,
        'Story Format extension integers must remain within the portable '
            'exact-integer range.',
      );
    }
    return value;
  }

  if (value is double) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        path,
        'Story Format extension numbers must be finite.',
      );
    }
    return value;
  }

  if (value is List<Object?>) {
    return List<Object?>.unmodifiable([
      for (var index = 0; index < value.length; index++)
        _copyAndValidate(value[index], '$path[$index]'),
    ]);
  }

  if (value is Map<Object?, Object?>) {
    final keys = <String>[];
    for (final key in value.keys) {
      if (key is! String) {
        throw ArgumentError.value(
          key,
          path,
          'Story Format extension object keys must be strings.',
        );
      }
      keys.add(key);
    }
    keys.sort();

    return Map<String, Object?>.unmodifiable({
      for (final key in keys)
        key: _copyAndValidate(value[key], '$path.$key'),
    });
  }

  throw ArgumentError.value(
    value,
    path,
    'Story Format extension payloads may contain only null, Boolean, String, '
        'portable Integer, finite Number, List, and string-keyed Map values.',
  );
}

bool _deepEquals(Object? left, Object? right) {
  if (identical(left, right)) {
    return true;
  }
  if (left is List<Object?> && right is List<Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index++) {
      if (!_deepEquals(left[index], right[index])) {
        return false;
      }
    }
    return true;
  }
  if (left is Map<String, Object?> && right is Map<String, Object?>) {
    if (left.length != right.length) {
      return false;
    }
    for (final entry in left.entries) {
      if (!right.containsKey(entry.key) ||
          !_deepEquals(entry.value, right[entry.key])) {
        return false;
      }
    }
    return true;
  }
  return left == right;
}

int _deepHash(Object? value) {
  if (value is List<Object?>) {
    return Object.hashAll(value.map(_deepHash));
  }
  if (value is Map<String, Object?>) {
    return Object.hashAll(
      value.entries.map(
        (entry) => Object.hash(entry.key, _deepHash(entry.value)),
      ),
    );
  }
  return value?.hashCode ?? 0;
}
