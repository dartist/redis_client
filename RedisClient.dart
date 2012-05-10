#library("RedisClient");
#import("dart:io");
#import("RedisConnection.dart");
#import("RedisNativeClient.dart");

interface RedisClient default _RedisClient {
  RedisClient([String connStr]);
  RedisNativeClient get raw();
  
  Future<Date> get lastsave();

  Future<String> get(String key);
  Future<String> getset(String key, String value);
  Future set(String key, String value);
  Future setex(String key, int expireInSecs, String value);
  Future psetex(String key, int expireInMs, String value);
  Future mset(Map map);
  Future<bool> msetnx(Map map);
 
  void close();
}

class _RedisClient implements RedisClient {
  String connStr;
  RedisNativeClient client;
  _RedisClient([String this.connStr]){
    client = new RedisNativeClient(connStr);
  }
  
  static String string(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes); 
  static List<int> toBytes(val) => val == null ? new List<int>() : val.toString().charCodes();  
  static _Tuple<List<List<int>>> keyValueBytes(Map map){
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
  
  Future<String> get(String key) =>
    client.get(key).transform((List<int> bytes) => string(bytes));  
  
  Future<String> getset(String key, String value) =>
    client.getset(key, toBytes(value)).transform((List<int> bytes) => string(bytes));  
  
  Future set(String key, String value) => 
      client.set(key, toBytes(value));
  
  Future setex(String key, int expireInSecs, String value) =>
      client.setex(key, expireInSecs, toBytes(value));
  
  Future psetex(String key, int expireInMs, String value) =>
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
