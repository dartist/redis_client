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

  List<int> serialize(Object obj) => encodeUtf8(stringify(obj));


  Object deserialize(List<int> bytes) {
    if (bytes == null || bytes.length == 0) return null;

    return parse(decodeUtf8(bytes));
  }


}