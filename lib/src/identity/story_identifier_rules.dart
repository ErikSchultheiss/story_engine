final _machineIdPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$');
final _aliasPattern = RegExp(r'^[a-z][a-z0-9_]{0,79}$');

String validateStoryMachineId(String value) {
  if (!_machineIdPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'value',
      'Story machine IDs must be 1-128 ASCII characters, start with a '
          'letter or digit, and then contain only letters, digits, dot, '
          'underscore, colon, or hyphen.',
    );
  }
  return value;
}

String validateStoryAlias(String value) {
  if (!_aliasPattern.hasMatch(value)) {
    throw ArgumentError.value(
      value,
      'value',
      'Story aliases must be 1-80 characters of lower-case ASCII snake_case, '
          'starting with a letter.',
    );
  }
  return value;
}
