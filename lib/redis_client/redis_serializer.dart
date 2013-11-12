part of redis_client;


abstract class RedisSerializer {

  factory RedisSerializer() => new JsonRedisSerializer();

  List<int> serialize(Object obj);  

  String serializeToString(Object obj);
  
  List<String> serializeFromZSet(Set<ZSetEntry> zSet);
  
  List<String> serializeToList(Object obj);

  Object deserialize(List<int> bytes);
  Map<String, Object> deserializeToMap(map);
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
    if (obj == null) return obj;
    
    List<String> values = new List();
    if (obj is Iterable) {
      values.addAll(obj.map(serializeToString));
    } else if (obj is Map) {
      values.addAll(serializeFromMap(obj));
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
    
    if (decodedObject is String) { 
      if (_isDate(decodedObject)) {
        int timeSinceEpoch = int.parse(decodedObject.substring(DATE_PREFIX.length, decodedObject.length - DATE_SUFFIX.length));
        return new DateTime.fromMillisecondsSinceEpoch(timeSinceEpoch, isUtc: true);    
      }
    } 
    return decodedObject;
  }

  
  List<String> serializeFromMap(Map map) {
    var variadicValueList = new List<String>(map.length * 2);
    var i = 0;
    map.forEach((key, value) {
      variadicValueList[i++] = serializeToString(key);
      variadicValueList[i++] = serializeToString(value);
    });

    return variadicValueList;
  }
  
  List<String> serializeFromZSet(Iterable<ZSetEntry> zSet) {
    var variadicValueList = new List<String>(zSet.length * 2);
    var i = 0;
    
    zSet.forEach((ZSetEntry zSetEntry) {
      variadicValueList[i++] = serializeToString(zSetEntry.score);
      variadicValueList[i++] = serializeToString(zSetEntry.entry);
    });
    
    return variadicValueList;
  }

  Map<String, Object> deserializeToMap(List<RedisReply> replies) {
    var multiBulkMap = new Map<String, Object>();
    if (replies.isNotEmpty) {
      for (int i = 0 ; i < replies.length ; i++) {
        multiBulkMap[deserialize((replies[i] as BulkReply).bytes)] = deserialize((replies[++i] as BulkReply).bytes);
      }
    }
    return multiBulkMap;
  }
  
  bool _isDate(decodedString) => decodedString.startsWith(DATE_PREFIX);
}

class ZSetEntry<Object, num> {
  Object entry;
  num score;
  
  ZSetEntry(this.entry, this.score);
}