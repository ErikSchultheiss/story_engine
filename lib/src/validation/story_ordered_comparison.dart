/// Lexicographically compares lists using their element ordering contract.
///
/// Preserve the first nonzero compareTo result and use length only when
/// the shared prefix compares equal. No identity shortcut or sign
/// normalization is introduced. This helper is not exported by the facade.
int compareStoryOrderedValues<T extends Comparable<T>>(
  List<T> left,
  List<T> right,
) {
  final sharedLength = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < sharedLength; index++) {
    final comparison = left[index].compareTo(right[index]);
    if (comparison != 0) {
      return comparison;
    }
  }
  return left.length.compareTo(right.length);
}
