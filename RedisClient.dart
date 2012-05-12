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

  //ADMIN
  Future<Date> get lastsave();
  Future<int> get dbsize();
  Future<Map> get info();
  Future flushdb();
  Future flushall();
  Future<bool> ping();
  Future save();
  Future bgsave();
  Future shutdown();
  Future bgrewriteaof();
  Future quit();

  //KEYS
  Future<Object> get(String key);
  Future<Object> getset(String key, Object value);
  Future set(String key, Object value);
  Future setex(String key, int expireInSecs, Object value);
  Future psetex(String key, int expireInMs, Object value);
  Future mset(Map map);
  Future<bool> msetnx(Map map);
  Future<bool> exists(String key);
  Future<int> del(String key);
  Future<int> mdel(List<String> keys);
  Future<int> incr(String key);
  Future<int> incrby(String key, int incrBy);
  Future<double> incrbyfloat(String key, double incrBy);
  Future<int> decr(String key);
  Future<int> decrby(String key, int decrBy);
  Future<int> strlen(String key);
  Future<int> append(String key, String value);
  Future<String> substr(String key, int fromIndex, int toIndex);
  Future<String> getrange(String key, int fromIndex, int toIndex);
  Future<String> setrange(String key, int offset, String value);
  Future<int> getbit(String key, int offset);
  Future<int> setbit(String key, int offset, int value);
  Future<String> randomkey();
  Future rename(String oldKey, String newKey);
  Future<bool> renamenx(String oldKey, String newKey);
  Future<bool> expire(String key, int expireInSecs);
  Future<bool> pexpire(String key, int expireInMs);
  Future<bool> expireat(String key, int unixTimeSecs);
  Future<bool> pexpireat(String key, int unixTimeMs);
  Future<int> ttl(String key);
  Future<int> pttl(String key);

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

  RedisNativeClient get raw() => client;

  //ADMIN
  Future<int> get dbsize() => client.dbsize;
  Future<Date> get lastsave() => client.lastsave.transform((int unixTs) => new Date.fromEpoch(unixTs, new TimeZone.utc()));
  Future<Map> get info() => client.info;
  Future flushdb() => client.flushdb();
  Future flushall() => client.flushall();
  Future<bool> ping() => client.ping();
  Future save() => client.save();
  Future bgsave() => client.bgsave();
  Future shutdown() => client.shutdown();
  Future bgrewriteaof() => client.bgrewriteaof();
  Future quit() => client.quit();

  //KEYS
  Future<String> type(String key) => client.type(key);
  Future<Object> get(String key) => client.get(key).transform(toObject);
  Future<List<Object>> mget(List<String> keys) => client.mget(keys).transform((x) => x.map(toObject));
  Future<Object> getset(String key, Object value) => client.getset(key, toBytes(value)).transform(toObject);
  Future set(String key, Object value) => client.set(key, toBytes(value));
  Future setex(String key, int expireInSecs, Object value) => client.setex(key, expireInSecs, toBytes(value));
  Future psetex(String key, int expireInMs, Object value) => client.psetex(key, expireInMs, toBytes(value));
  Future<bool> persist(String key) => client.persist(key);
  Future mset(Map map){ _Tuple<List<List<int>>> kvps = keyValueBytes(map); return client.mset(kvps.item1, kvps.item2); }
  Future<bool> msetnx(Map map){ _Tuple<List<List<int>>> kvps = keyValueBytes(map); return client.msetnx(kvps.item1, kvps.item2); }
  Future<bool> exists(String key) => client.exists(key);
  Future<int> del(String key) => client.del(key);
  Future<int> mdel(List<String> keys) => client.mdel(keys);
  Future<int> incr(String key) => client.incr(key);
  Future<int> incrby(String key, int incrBy) => client.incrby(key, incrBy);
  Future<double> incrbyfloat(String key, double incrBy) => client.incrbyfloat(key, incrBy);
  Future<int> decr(String key) => client.decr(key);
  Future<int> decrby(String key, int decrBy) => client.decrby(key, decrBy);
  Future<int> strlen(String key) => client.strlen(key);
  Future<int> append(String key, String value) => client.append(key, toBytes(value));
  Future<String> substr(String key, int fromIndex, int toIndex) => client.substr(key, fromIndex, toIndex).transform(toStr);
  Future<String> getrange(String key, int fromIndex, int toIndex) => client.getrange(key, fromIndex, toIndex).transform(toStr);
  Future<String> setrange(String key, int offset, String value) => client.setrange(key, offset, toBytes(value)).transform(toStr);
  Future<int> getbit(String key, int offset) => client.getbit(key, offset);
  Future<int> setbit(String key, int offset, int value) => client.setbit(key, offset, value);
  Future<String> randomkey() => client.randomkey().transform(toStr);
  Future rename(String oldKey, String newKey) => client.rename(oldKey, newKey);
  Future<bool> renamenx(String oldKey, String newKey) => client.renamenx(oldKey, newKey);
  Future<bool> expire(String key, int expireInSecs) => client.expire(key, expireInSecs);
  Future<bool> pexpire(String key, int expireInMs) => client.pexpire(key, expireInMs);
  Future<bool> expireat(String key, int unixTimeSecs) => client.expireat(key, unixTimeSecs);
  Future<bool> pexpireat(String key, int unixTimeMs) => client.pexpireat(key, unixTimeMs);
  Future<int> ttl(String key) => client.ttl(key);
  Future<int> pttl(String key) => client.pttl(key);

  void close() => raw.close();

  List<int> toBytes(Object obj) => bytesEncoder.toBytes(obj);
  Object toObject(List<int> bytes) => bytesEncoder.toObject(bytes);
  static String toStr(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes);

  _Tuple<List<List<int>>> keyValueBytes(Map map){
    List<List<int>> keys = new List<List<int>>();
    List<List<int>> values = new List<List<int>>();
    for(String key in map.getKeys()){
      keys.add(key.charCodes());
      values.add(toBytes(map[key]));
    }
    return new _Tuple(keys,values);
  }
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
