#library("RedisClient");
#import("dart:io");
#import("Mixin.dart");
#import("RedisConnection.dart");

interface RedisNativeClient default _RedisNativeClient {
  RedisNativeClient([String connStr]);
  
  Future<int> get dbsize();
  Future<int> get lastsave();
  Future flushdb();
  Future flushall();
  Future<Map> get info();
  Future<bool> get ping();  
  
  //Keys
  Future<String> type(String key);
  Future<List<int>> get(String key);
  Future<List<int>> getset(String key, List<int> value);
  Future set(String key, List<int> value);
  Future<int> strlen(String key);
  Future setex(String key, int expireInSecs, List<int> value);
  Future psetex(String key, int expireInMs, List<int> value);
  Future<bool> persist(String key);
  Future mset(List<List<int>> keys, List<List<int>> values);
  Future<bool> msetnx(List<List<int>> keys, List<List<int>> values);
  Future<bool> exists(String key);
  Future<int> del(String key);
  Future<int> mdel(List<String> keys);
  Future<int> incr(String key);
  Future<int> incrby(String key, int count);
  Future<double> incrbyfloat(String key, double count);
  Future<int> decr(String key);
  Future<int> decrby(String key, double count);

  void close();
}

class _RedisNativeClient implements RedisNativeClient {
  String connStr;
  RedisConnection conn;
  _RedisNativeClient([String this.connStr]){
    conn = new RedisConnection(connStr);
  }
  
  static String string(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes); 
  static List<int> toBytes(val) => val == null ? new List<int>() : val.toString().charCodes();  
  
  Future<int> get dbsize() => conn.sendExpectInt([_Cmd.DBSIZE]);
  
  Future<int> get lastsave() => conn.sendExpectInt([_Cmd.LASTSAVE]);
  
  Future flushdb() => conn.sendExpectSuccess([_Cmd.FLUSHDB]);
  
  Future flushall() => conn.sendExpectSuccess([_Cmd.FLUSHALL]);
  
  Future<Map> get info(){
    return conn.sendExpectString([_Cmd.INFO])
      .transform((String lines){
         Map info = {};
         for(String line in lines.split("\r\n")){
           List<String> kvp = $(line).splitOnFirst(":");
           info[kvp[0]] = kvp.length == 2 ? kvp[1] : null;
         }
         return info;
      });
  }
  
  Future<bool> get ping() => conn.sendExpectCode([_Cmd.PING]).transform((String r) => r == "PONG");
  
  Future<String> type(String key) => conn.sendExpectCode([_Cmd.TYPE, toBytes(key)]);
  
  Future<int> strlen(String key) => conn.sendExpectInt([_Cmd.STRLEN, toBytes(key)]);
  
  Future<List<int>> get(String key) =>
      conn.sendExpectData([_Cmd.GET, toBytes(key)]);
  
  Future<List<int>> getset(String key, List<int> value) =>
      conn.sendExpectData([_Cmd.GETSET, toBytes(key), value]);
  
  Future set(String key, List<int> value) => 
      conn.sendExpectSuccess([_Cmd.SET, toBytes(key), value]);
  
  Future setex(String key, int expireInSecs, List<int> value) => 
      conn.sendExpectSuccess([_Cmd.SETEX, toBytes(key), toBytes(expireInSecs), value]);
  
  Future psetex(String key, int expireInMs, List<int> value) => 
      conn.sendExpectSuccess([_Cmd.SETEX, toBytes(key), toBytes(expireInMs), value]);
  
  Future<bool> persist(String key) => conn.sendExpectIntSuccess([_Cmd.PERSIST,toBytes(key)]);
  
  Future mset(List<List<int>> keys, List<List<int>> values) =>
    conn.sendExpectSuccess(_Utils.mergeCommandWithKeysAndValues(_Cmd.MSET, keys, values));  
  
  Future<bool> msetnx(List<List<int>> keys, List<List<int>> values) =>
    conn.sendExpectIntSuccess(_Utils.mergeCommandWithKeysAndValues(_Cmd.MSETNX, keys, values));  
  
  Future<bool> exists(String key) => conn.sendExpectIntSuccess([_Cmd.EXISTS,toBytes(key)]);

  Future<int> del(String key) => conn.sendExpectInt([_Cmd.DEL, toBytes(key)]);
  
  Future<int> mdel(List<String> keys) => conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.DEL, keys));

  Future<int> incr(String key) => conn.sendExpectInt([_Cmd.INCR, toBytes(key)]);

  Future<int> incrby(String key, int count) => conn.sendExpectInt([_Cmd.INCRBY, toBytes(key), toBytes(count)]);

  Future<double> incrbyfloat(String key, double count) => conn.sendExpectDouble([_Cmd.INCRBYFLOAT, toBytes(key), toBytes(count)]);

  Future<int> decr(String key) => conn.sendExpectInt([_Cmd.DECR, toBytes(key)]);

  Future<int> decrby(String key, double count) => conn.sendExpectInt([_Cmd.DECRBY, toBytes(key), toBytes(count)]);
  
  void close() => conn.close();
}

//TODO change to lazy static initializers
class _Cmd {
  
  //Admin
  static get DBSIZE() => "DBSIZE".charCodes();
  static get INFO() => "INFO".charCodes();
  static get LASTSAVE() => "LASTSAVE".charCodes();
  static get PING() => "PING".charCodes();
  static get SLAVEOF() => "SLAVEOF".charCodes();
  static get NO() => "NO".charCodes();
  static get ONE() => "ONE".charCodes();
  static get CONFIG() => "CONFIG".charCodes(); //GET SET
  static get RESETSTAT() => "RESETSTAT".charCodes();
  static get TIME() => "TIME".charCodes();
  static get DEBUG() => "DEBUG".charCodes(); //OBJECT SEGFAULT
  static get SEGFAULT() => "SEGFAULT".charCodes();
  static get RESTORE() => "RESTORE".charCodes();
  static get MIGRATE() => "MIGRATE".charCodes();
  static get MOVE() => "MOVE".charCodes();
  static get OBJECT() => "OBJECT".charCodes(); //REFCOUNT ENCODING IDLETIME
  static get REFCOUNT() => "REFCOUNT".charCodes();
  static get ENCODING() => "ENCODING".charCodes();
  static get IDLETIME() => "IDLETIME".charCodes();
  static get SAVE() => "SAVE".charCodes();
  static get BGSAVE() => "BGSAVE".charCodes();
  static get SHUTDOWN() => "SHUTDOWN".charCodes();
  static get BGREWRITEAOF() => "BGREWRITEAOF".charCodes();
  static get QUIT() => "QUIT".charCodes();
  static get FLUSHDB() => "FLUSHDB".charCodes();
  static get FLUSHALL() => "FLUSHALL".charCodes();
  static get KEYS() => "KEYS".charCodes();
  static get SLOWLOG() => "SLOWLOG".charCodes();

  //Keys
  static get TYPE() => "TYPE".charCodes();
  static get STRLEN() => "STRLEN".charCodes();
  static get SET() => "SET".charCodes();
  static get GET() => "GET".charCodes();
  static get DEL() => "DEL".charCodes();
  static get SETEX() => "SETEX".charCodes();
  static get PSETEX() => "PSETEX".charCodes();
  static get SETNX() => "SETNX".charCodes();
  static get PERSIST() => "PERSIST".charCodes();
  static get MSET() => "MSET".charCodes();
  static get MSETNX() => "MSETNX".charCodes();
  static get GETSET() => "GETSET".charCodes();
  static get EXISTS() => "EXISTS".charCodes();
  static get INCR() => "INCR".charCodes();
  static get INCRBY() => "INCRBY".charCodes();
  static get INCRBYFLOAT() => "INCRBYFLOAT".charCodes();
  static get DECR() => "DECR".charCodes();
  static get DECRBY() => "DECRBY".charCodes();
  static get APPEND() => "APPEND".charCodes();
  static get SUBSTR() => "SUBSTR".charCodes();
  static get GETRANGE() => "GETRANGE".charCodes();
  static get SETRANGE() => "SETRANGE".charCodes();
  static get GETBIT() => "GETBIT".charCodes();
  static get SETBIT() => "SETBIT".charCodes();
  static get RANDOMKEY() => "RANDOMKEY".charCodes();
  static get RENAME() => "RENAME".charCodes();
  static get RENAMENX() => "RENAMENX".charCodes();
  static get EXPIRE() => "EXPIRE".charCodes();
  static get PEXPIRE() => "PEXPIRE".charCodes();
  static get EXPIREAT() => "EXPIREAT".charCodes();
  static get PEXPIREAT() => "PEXPIREAT".charCodes();
  static get TTL() => "TTL".charCodes();
  static get PTTL() => "PTTL".charCodes();
  
  //Transactions
  static get MGET() => "MGET".charCodes();
  static get WATCH() => "WATCH".charCodes();
  static get UNWATCH() => "UNWATCH".charCodes();
  static get MULTI() => "MULTI".charCodes();
  static get EXEC() => "EXEC".charCodes();
  static get DISCARD() => "DISCARD".charCodes();
  
  //SET
  static get SMEMBERS() => "SMEMBERS".charCodes();
  static get SADD() => "SADD".charCodes();
  static get SREM() => "SREM".charCodes();
  static get SPOP() => "SPOP".charCodes();
  static get SMOVE() => "SMOVE".charCodes();
  static get SCARD() => "SCARD".charCodes();
  static get SISMEMBER() => "SISMEMBER".charCodes();
  static get SINTER() => "SINTER".charCodes();
  static get SINTERSTORE() => "SINTERSTORE".charCodes();
  static get SUNION() => "SUNION".charCodes();
  static get SUNIONSTORE() => "SUNIONSTORE".charCodes();
  static get SDIFF() => "SDIFF".charCodes();
  static get SDIFFSTORE() => "SDIFFSTORE".charCodes();
  static get SRANDMEMBER() => "SRANDMEMBER".charCodes();
  
  //List
  static get LRANGE() => "LRANGE".charCodes();
  static get SORT() => "SORT".charCodes();
  static get RPUSH() => "RPUSH".charCodes();
  static get RPUSHX() => "RPUSHX".charCodes();
  static get LPUSH() => "LPUSH".charCodes();
  static get LPUSHX() => "LPUSHX".charCodes();
  static get LTRIM() => "LTRIM".charCodes();
  static get LREM() => "LREM".charCodes();
  static get LLEN() => "LLEN".charCodes();
  static get LINDEX() => "LINDEX".charCodes();
  static get LINSERT() => "LINSERT".charCodes();
  static get AFTER() => "AFTER".charCodes();
  static get BEFORE() => "BEFORE".charCodes();
  static get LSET() => "LSET".charCodes();
  static get LPOP() => "LPOP".charCodes();
  static get RPOP() => "RPOP".charCodes();
  static get BLPOP() => "BLPOP".charCodes();
  static get BRPOP() => "BRPOP".charCodes();
  static get RPOPLPUSH() => "RPOPLPUSH".charCodes();
  
  //Sorted Sets
  static get ZADD() => "ZADD".charCodes();
  static get ZREM() => "ZREM".charCodes();
  static get ZINCRBY() => "ZINCRBY".charCodes();
  static get ZRANK() => "ZRANK".charCodes();
  static get ZREVRANK() => "ZREVRANK".charCodes();
  static get ZRANGE() => "ZRANGE".charCodes();
  static get ZREVRANGE() => "ZREVRANGE".charCodes();
  static get WITHSCORES() => "WITHSCORES".charCodes();
  static get LIMIT() => "LIMIT".charCodes();
  static get ZRANGEBYSCORE() => "ZRANGEBYSCORE".charCodes();
  static get ZREVRANGEBYSCORE() => "ZREVRANGEBYSCORE".charCodes();
  static get ZREMRANGEBYRANK() => "ZREMRANGEBYRANK".charCodes();
  static get ZREMRANGEBYSCORE() => "ZREMRANGEBYSCORE".charCodes();
  static get ZCARD() => "ZCARD".charCodes();
  static get ZSCORE() => "ZSCORE".charCodes();
  static get ZUNIONSTORE() => "ZUNIONSTORE".charCodes();
  static get ZINTERSTORE() => "ZINTERSTORE".charCodes();
  
  //Hash
  static get HSET() => "HSET".charCodes();
  static get HSETNX() => "HSETNX".charCodes();
  static get HMSET() => "HMSET".charCodes();
  static get HINRYBY() => "HINRYBY".charCodes();
  static get HINRYBYFLOAT() => "HINRYBYFLOAT".charCodes();
  static get HGET() => "HGET".charCodes();
  static get HMGET() => "HMGET".charCodes();
  static get HDEL() => "HDEL".charCodes();
  static get HEXISTS() => "HEXISTS".charCodes();
  static get HLEN() => "HLEN".charCodes();
  static get HKEYS() => "HKEYS".charCodes();
  static get HVALS() => "HVALS".charCodes();
  static get HGETALL() => "HGETALL".charCodes();
  
  //Pub/Sub
  static get PUBLISH() => "PUBLISH".charCodes();
  static get SUBSCRIBE() => "SUBSCRIBE".charCodes();
  static get UNSUBSCRIBE() => "UNSUBSCRIBE".charCodes();
  static get PSUBSCRIBE() => "PSUBSCRIBE".charCodes();
  static get PUNSUBSCRIBE() => "PUNSUBSCRIBE".charCodes();
  
  //Scripting
  static get EVAL() => "EVAL".charCodes();
  static get SCRIPT() => "SCRIPT".charCodes(); //EXISTS FLUSH KILL LOAD
  static get KILL() => "KILL".charCodes();
  static get LOAD() => "LOAD".charCodes();

}

class _Utils {
  static List<List<int>> mergeCommandWithKeysAndValues(List<int> cmd, List<List<int>> keys, List<List<int>> values) =>
    mergeParamsWithKeysAndValues([cmd], keys, values);  
  
  static List<List<int>> mergeParamsWithKeysAndValues(List<List<int>> firstParams, List<List<int>> keys, List<List<int>> values) {
    if (keys == null || keys.length == 0)
      throw new Exception("keys is null");
    if (values == null || values.length == 0)
      throw new Exception("values is null");
    if (keys.length != values.length)
      throw new Exception("keys.length != values.length");
    
    int keyValueStartIndex = firstParams != null ? firstParams.length : 0;

    int keysAndValuesLength = keys.length * 2 + keyValueStartIndex;
    List<List<int>> keysAndValues = new List<List<int>>();

    for (int i = 0; i < keyValueStartIndex; i++){
      keysAndValues.add(firstParams[i]);
    }

    int j = 0;
    for (int i = keyValueStartIndex; i < keysAndValuesLength; i += 2){
      keysAndValues.add(keys[j]);
      keysAndValues.add(values[j]);
      j++;
    }
    return keysAndValues;    
  }

  static List<List<int>> mergeCommandWithStringArgs(List<int> cmd, List<String> args) =>
    mergeCommandWithArgs(cmd, args.map((x) => x.charCodes()));

  static List<List<int>> mergeCommandWithArgs(List<int> cmd, List<List<int>> args){
    List<List<int>> mergedBytes = new List<List<int>>();
    mergedBytes.add(cmd);
    for (var i = 0; i < args.length; i++){
      mergedBytes.add(args[i]);
    }
    return mergedBytes;
  }
  
}