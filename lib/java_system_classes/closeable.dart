import 'auto_closeable.dart';

abstract class Closeable extends AutoCloseable {
  @override
  void close();
}