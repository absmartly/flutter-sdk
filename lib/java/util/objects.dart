class Objects{
  static bool equals(dynamic a, dynamic b) => (a == b) || (a != null && a.equals(b));
  static int hash(List<Object> values) => values.hashCode;

}