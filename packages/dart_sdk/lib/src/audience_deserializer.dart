abstract class AudienceDeserializer {
  Map<String, dynamic>? deserialize(
      List<int> bytes, final int offset, final int length);
}
