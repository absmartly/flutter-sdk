int leftRotate(int n, int d) {
  return (n << d) | (n >> (64 - d));
}
class Helper{
  static String? response;
}