part of redis_client;


abstract class RedisSerializer {

  factory RedisSerializer() => new JsonRedisSerializer();

  List<int> serialize(Object obj);  

  String serializeToString(Object obj);
  
  List<String> serializeToList(Object obj);

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
   * Serializes given object into its' String representation and returns the
   * binary of it.
   */
  List<int> serialize(Object obj) {
    if (obj == null) return obj;
    return UTF8.encode(serializeToString(obj));
  }
  
  /**
   * Serializes given object into its' String representation.
   */    
  String serializeToString(Object obj) {
    if (obj == null || obj is String) return obj;
    else if (obj is DateTime) return "$DATE_PREFIX${obj.millisecondsSinceEpoch}$DATE_SUFFIX";
    else if (obj is Set) return serializeToString(obj.toList());
    else return JSON.encode(obj);
  }
  
  List<String> serializeToList(Object obj) {
    if(obj == null) return obj;
    List<String> values = new List();
    if(obj is Iterable) {
      values.addAll(obj.map(serializeToString));
    } else { values.add(serializeToString(obj)); }
    return values;
  }

  /**
   * Deserializes the String form of given bytes and returns the native object
   * for it.
   */
  Object deserialize(List<int> deserializable) {
    if (deserializable == null) return deserializable;
    
    var decodedObject = UTF8.decode(deserializable);
    try { decodedObject = JSON.decode(decodedObject); } 
    on FormatException catch (e) { }
    
    if(decodedObject is String){ 
      if (_isDate(decodedObject)) {
        int timeSinceEpoch = int.parse(decodedObject.substring(DATE_PREFIX.length, decodedObject.length - DATE_SUFFIX.length));
        return new DateTime.fromMillisecondsSinceEpoch(timeSinceEpoch, isUtc: true);    
      }
    } 
    return decodedObject;
  }
  
  bool _isDate(decodedString) => decodedString.startsWith(DATE_PREFIX);
}