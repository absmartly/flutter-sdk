
class Algorithm {
  static List<R?> mapSetToArray<T, R>(Set<T> set, List<R?> list, Function(T) mapper) {
    final int size = set.length;
    if (list.length < size) {
      list = List<R?>.generate(size, (int index) => null, growable: true);
    }

    if (list.length > size) {
      list[size] = null;
    }

    int index = 0;
    for (final T value in set) {
      list[index++] = mapper(value);
    }
    return list;
  }
}

