#library("RedisClient");
#import("dart:io");
#import("dart:json");
#import("RedisConnection.dart");
#import("RedisNativeClient.dart");

interface BytesEncoder default JsonEncoder {
  BytesEncoder();
  List<int> toBytes(Object obj);
  String stringify(Object obj);
  Object toObject(List<int> bytes);
}

interface RedisClient default _RedisClient {
  RedisClient([String connStr]);
  RedisNativeClient get raw();

  Future<Date> get lastsave();

  Future<Object> get(String key);
  Future<Object> getset(String key, Object value);
  Future set(String key, Object value);
  Future setex(String key, int expireInSecs, Object value);
  Future psetex(String key, int expireInMs, Object value);
  Future mset(Map map);
  Future<bool> msetnx(Map map);

  void close();
}

class _RedisClient implements RedisClient {
  String connStr;
  RedisNativeClient client;
  BytesEncoder bytesEncoder;

  _RedisClient([String this.connStr])
    : bytesEncoder = new BytesEncoder() {
    client = new RedisNativeClient(connStr);
  }

  List<int> toBytes(Object obj) => bytesEncoder.toBytes(obj);
  Object toObject(List<int> bytes) => bytesEncoder.toObject(bytes);
  static String string(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes);

  _Tuple<List<List<int>>> keyValueBytes(Map map){
    List<List<int>> keys = new List<List<int>>();
    List<List<int>> values = new List<List<int>>();
    for(String key in map.getKeys()){
      keys.add(key.charCodes());
      values.add(toBytes(map[key]));
    }
    return new _Tuple(keys,values);
  }

  RedisNativeClient get raw() => client;

  Future<Date> get lastsave() => client.lastsave
      .transform((int unixTs) => new Date.fromEpoch(unixTs, new TimeZone.utc()));

  Future<Object> get(String key) => client.get(key).transform(toObject);

  Future<Object> getset(String key, Object value) =>
    client.getset(key, toBytes(value)).transform(toObject);

  Future set(String key, Object value) => client.set(key, toBytes(value));

  Future setex(String key, int expireInSecs, Object value) =>
      client.setex(key, expireInSecs, toBytes(value));

  Future psetex(String key, int expireInMs, Object value) =>
      client.psetex(key, expireInMs, toBytes(value));

  Future mset(Map map){
    _Tuple<List<List<int>>> kvps = keyValueBytes(map);
    return client.mset(kvps.item1, kvps.item2);
  }

  Future<bool> msetnx(Map map){
    _Tuple<List<List<int>>> kvps = keyValueBytes(map);
    return client.msetnx(kvps.item1, kvps.item2);
  }

  void close() => raw.close();
}

class _Tuple<E> {
  E item1;
  E item2;
  E item3;
  E item4;
  _Tuple(this.item1, this.item2, [this.item3, this.item4]);
}

class JsonEncoder implements BytesEncoder {
  static final int OBJECT_START = 123; // {
  static final int ARRAY_START  = 91;  // [
  static final int ZERO         = 48;  // 0
  static final int NINE         = 57;  // 9
  static final int SIGN         = 45;  // -

  static final String DATE_PREFIX = "/Date(";
  static final String DATE_SUFFIX = ")/";
  static final String TRUE  = "true";
  static final String FALSE = "false";

  List<int> toBytes(Object obj) => stringify(obj).charCodes();

  String stringify(Object obj) =>
      obj == null ?
      ""
    : obj is String ?
      obj
    : obj is Date ?
      "/Date(${obj.changeTimeZone(new TimeZone.utc()).value})/"
    : obj is bool || obj is num ?
      obj.toString() :
      JSON.stringify(obj);

  Object toObject(List<int> bytes) =>
      bytes == null || bytes.length == 0 ?
      null
    : _isJson(bytes[0]) ?
      JSON.parse(new String.fromCharCodes(bytes)) :
      _fromBytes(bytes);

  bool _isJson(int firstByte) =>
      firstByte == OBJECT_START || firstByte == ARRAY_START || firstByte == SIGN
   || (firstByte >= ZERO && firstByte <= NINE);

  Object _fromBytes(List<int> bytes){
    try{
      String str = new String.fromCharCodes(bytes);
      if (str.startsWith(DATE_PREFIX)) {
        int epoch = Math.parseInt(str.substring(DATE_PREFIX.length, str.length - DATE_SUFFIX.length));
        return new Date.fromEpoch(epoch, new TimeZone.utc());
      }
      if (str == TRUE)  return true;
      if (str == FALSE) return false;
      return str;
    } catch(var e) { print("ERROR: $e"); }
    return bytes;
  }
}
