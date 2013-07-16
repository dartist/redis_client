part of redis_client;


abstract class RedisSerializer {

  factory RedisSerializer() => new JsonRedisSerializer();

  List<int> serialize(Object obj);

  Object deserialize(List<int> bytes);

}




class JsonRedisSerializer implements RedisSerializer {

  static final int OBJECT_START = 123; // {
  static final int ARRAY_START  = 91;  // [
  static final int ZERO         = 48;  // 0
  static final int NINE         = 57;  // 9
  static final int SIGN         = 45;  // -

  static final String DATE_PREFIX = "/Date(";
  static final String DATE_SUFFIX = ")/";
  static final String TRUE  = "true";
  static final String FALSE = "false";


  /**
   * Serializes given object into it's String representation and returns the
   * binary of it.
   */
  List<int> serialize(Object obj) {
    String serialized;

    if (obj == null) serialized = "";
    else if (obj is String) serialized = obj;
    else if (obj is DateTime) serialized = "$DATE_PREFIX${obj.millisecondsSinceEpoch}$DATE_SUFFIX";
    else if (obj is bool || obj is num) serialized = obj.toString();
    else serialized = stringify(obj);

    return encodeUtf8(serialized);
  }


  /**
   * Deserializes the String form of given bytes and returns the native object
   * for it.
   */
  Object deserialize(List<int> bytes) {
    if (bytes == null || bytes.length == 0) return "";

    return parse(decodeUtf8(bytes));
  }


  /**
   * Wheter given bytes are encoded JSON.
   *
   * This is determined by looking at the first byte.
   */
  bool _isSerializedJSON(List <int> bytes) {
    var firstByte = bytes.first;
    return firstByte == OBJECT_START || firstByte == ARRAY_START || firstByte == SIGN
        || (firstByte >= ZERO && firstByte <= NINE); // JSON deserializes numbers just fine.
  }


}