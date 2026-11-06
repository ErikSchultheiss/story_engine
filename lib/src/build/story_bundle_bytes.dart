void validateStoryBundleBytes(List<int> bytes) {
  for (var index = 0; index < bytes.length; index++) {
    final byte = bytes[index];
    if (byte < 0 || byte > 255) {
      throw RangeError.range(byte, 0, 255, 'bytes[$index]');
    }
  }
}
