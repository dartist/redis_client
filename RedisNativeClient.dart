#library("RedisClient");
#import("dart:io");
#import("Mixin.dart");
#import("RedisConnection.dart");

interface RedisNativeClient default _RedisNativeClient {
  RedisNativeClient([String connStr]);

  Map get stats();

  Future<int> get dbsize();
  Future<int> get lastsave();
  Future flushdb();
  Future flushall();
  Future<Map> get info();
  Future<bool> ping();
  Future save();
  Future bgsave();
  Future shutdown();
  Future bgrewriteaof();
  Future quit();

  //Keys
  Future<String> type(String key);
  Future<List<int>> get(String key);
  Future<List<List<int>>> mget(List<String> keys);
  Future<List<int>> getset(String key, List<int> value);
  Future set(String key, List<int> value);
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
  Future<int> decrby(String key, int count);
  Future<int> strlen(String key);
  Future<int> append(String key, List<int> value);
  Future<List<int>> substr(String key, int fromIndex, int toIndex);
  Future<List<int>> getrange(String key, int fromIndex, int toIndex);
  Future<List<int>> setrange(String key, int offset, List<int> value);
  Future<int> getbit(String key, int offset);
  Future<int> setbit(String key, int offset, int value);
  Future<List<int>> randomkey();
  Future rename(String oldKey, String newKey);
  Future<bool> renamenx(String oldKey, String newKey);
  Future<bool> expire(String key, int expireInSecs);
  Future<bool> pexpire(String key, int expireInMs);
  Future<bool> expireat(String key, int unixTimeSecs);
  Future<bool> pexpireat(String key, int unixTimeMs);
  Future<int> ttl(String key);
  Future<int> pttl(String key);

  //SET
  Future<List<int>> smembers(String setId);
  Future<int> sadd(String setId, List<int> value);
  Future<int> srem(String setId, List<int> value);
  Future<List<int>> spop(String setId);
  Future smove(String fromSetId, String toSetId, List<int> value);
  Future<int> scard(String setId);
  Future<bool> sismember(String setId, List<int> value);
  Future<List<List<int>>> sinter(List<String> setIds);
  Future sinterstore(String intoSetId, List<String> setIds);
  Future<List<List<int>>> sunion(List<String> setIds);
  Future sunionstore(String intoSetId, List<String> setIds);
  Future<List<List<int>>> sdiff(String fromSetId, List<String> withSetIds);
  Future sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds);
  Future<List<int>> srandmember(String setId);

  //LIST
  Future<List<List<int>>> lrange(String listId, int startingFrom, int endingAt);
  Future<int> lpush(String listId, List<int> value);
  Future<int> lpushx(String listId, List<int> value);
  Future<int> rpush(String listId, List<int> value);
  Future<int> rpushx(String listId, List<int> value);
  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt);
  Future<int> lrem(String listId, int removeNoOfMatches, List<int> value);
  Future<int> llen(String listId);
  Future<List<int>> lindex(String listId, int listIndex);
  Future lset(String listId, int listIndex, List<int> value);
  Future<List<int>> lpop(String listId);
  Future<List<int>> rpop(String listId);
  Future<List<int>> rpoplpush(String fromListId, String toListId);

  //SORTED SETS
  Future<int> zadd(String setId, num score, List<int> value);
  Future<int> zrem(String setId, List<int> value);
  Future<double> zincrby(String setId, num incrBy, List<int> value);
  Future<int> zrank(String setId, List<int> value);
  Future<int> zrevrank(String setId, List<int> value);
  Future<List<List<int>>> zrange(String setId, int min, int max);
  Future<List<List<int>>> zrangeWithScores(String setId, int min, int max);
  Future<List<List<int>>> zrevrange(String setId, int min, int max);
  Future<List<List<int>>> zrevrangeWithScores(String setId, int min, int max);
  Future<List<List<int>>> zrangebyscore(String setId, num min, num max, [int skip, int take]);
  Future<List<List<int>>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]);
  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]);
  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]);
  Future<int> zremrangebyrank(String setId, int min, int max);
  Future<int> zremrangebyscore(String setId, num min, num max);
  Future<int> zcard(String setId);
  Future<double> zscore(String setId, List<int> value);
  Future<int> zunionstore(String intoSetId, List<String> setIds);
  Future<int> zinterstore(String intoSetId, List<String> setIds);

  //HASH
  Future<int> hset(String hashId, String key, List<int> value);
  Future<int> hsetnx(String hashId, String key, List<int> value);
  Future hmset(String hashId, List<List<int>> keys, List<List<int>> values);
  Future<int> hincrby(String hashId, String key, int incrBy);
  Future<double> hincrbyfloat(String hashId, String key, double incrBy);
  Future<List<int>> hget(String hashId, String key);
  Future<List<List<int>>> hmget(String hashId, List<String> keys);
  Future<int> hdel(String hashId, String key);
  Future<bool> hexists(String hashId, String key);
  Future<int> hlen(String hashId);
  Future<List<String>> hkeys(String hashId);
  Future<List<List<int>>> hvals(String hashId);
  Future<List<List<int>>> hgetall(String hashId);

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
  static List<int> keyBytes(String key){
    if (key == null || key.isEmpty()) throw new Exception("key is null");
    return key.charCodes();
  }

  Future<int> get dbsize() => conn.sendExpectInt([_Cmd.DBSIZE]);

  Future<int> get lastsave() => conn.sendExpectInt([_Cmd.LASTSAVE]);

  Future flushdb() => conn.sendExpectSuccess([_Cmd.FLUSHDB]);

  Future flushall() => conn.sendExpectSuccess([_Cmd.FLUSHALL]);

  Future save() => conn.sendExpectSuccess([_Cmd.SAVE]);

  Future bgsave() => conn.sendExpectSuccess([_Cmd.BGSAVE]);

  Future shutdown() => conn.sendExpectSuccess([_Cmd.SHUTDOWN]);

  Future bgrewriteaof() => conn.sendExpectSuccess([_Cmd.BGREWRITEAOF]);

  Future quit() => conn.sendExpectSuccess([_Cmd.QUIT]);

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

  Future<bool> ping() => conn.sendExpectCode([_Cmd.PING]).transform((String r) => r == "PONG");

  Future<String> type(String key) => conn.sendExpectCode([_Cmd.TYPE, keyBytes(key)]);

  Future<List<int>> get(String key) =>
      conn.sendExpectData([_Cmd.GET, keyBytes(key)]);

  Future<List<List<int>>> mget(List<String> keys) =>
    conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.MGET, keys));

  Future<List<int>> getset(String key, List<int> value) =>
      conn.sendExpectData([_Cmd.GETSET, keyBytes(key), value]);

  Future set(String key, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.SET, keyBytes(key), value]);

  Future setex(String key, int expireInSecs, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.SETEX, keyBytes(key), toBytes(expireInSecs), value]);

  Future psetex(String key, int expireInMs, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.SETEX, keyBytes(key), toBytes(expireInMs), value]);

  Future<bool> persist(String key) => conn.sendExpectIntSuccess([_Cmd.PERSIST, keyBytes(key)]);

  Future mset(List<List<int>> keys, List<List<int>> values) =>
    conn.sendExpectSuccess(_Utils.mergeCommandWithKeysAndValues(_Cmd.MSET, keys, values));

  Future<bool> msetnx(List<List<int>> keys, List<List<int>> values) =>
    conn.sendExpectIntSuccess(_Utils.mergeCommandWithKeysAndValues(_Cmd.MSETNX, keys, values));

  Future<bool> exists(String key) => conn.sendExpectIntSuccess([_Cmd.EXISTS, keyBytes(key)]);

  Future<int> del(String key) => conn.sendExpectInt([_Cmd.DEL, keyBytes(key)]);

  Future<int> mdel(List<String> keys) => conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.DEL, keys));

  Future<int> incr(String key) => conn.sendExpectInt([_Cmd.INCR, keyBytes(key)]);

  Future<int> incrby(String key, int count) => conn.sendExpectInt([_Cmd.INCRBY, keyBytes(key), toBytes(count)]);

  Future<double> incrbyfloat(String key, double count) => conn.sendExpectDouble([_Cmd.INCRBYFLOAT, keyBytes(key), toBytes(count)]);

  Future<int> decr(String key) => conn.sendExpectInt([_Cmd.DECR, keyBytes(key)]);

  Future<int> decrby(String key, int count) => conn.sendExpectInt([_Cmd.DECRBY, keyBytes(key), toBytes(count)]);

  Future<int> strlen(String key) => conn.sendExpectInt([_Cmd.STRLEN, keyBytes(key)]);

  Future<int> append(String key, List<int> value) => conn.sendExpectInt([_Cmd.APPEND, keyBytes(key), value]);

  Future<List<int>> substr(String key, int fromIndex, int toIndex) =>
      conn.sendExpectData([_Cmd.SUBSTR, keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> getrange(String key, int fromIndex, int toIndex) =>
      conn.sendExpectData([_Cmd.GETRANGE, keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> setrange(String key, int offset, List<int> value) =>
      conn.sendExpectData([_Cmd.SETRANGE, keyBytes(key), toBytes(offset), value]);

  Future<int> getbit(String key, int offset) => conn.sendExpectInt([_Cmd.GETBIT, keyBytes(key), toBytes(offset)]);

  Future<int> setbit(String key, int offset, int value) =>
      conn.sendExpectInt([_Cmd.SETBIT, keyBytes(key), toBytes(offset), toBytes(value)]);

  Future<List<int>> randomkey() => conn.sendExpectData([_Cmd.RANDOMKEY]);

  Future rename(String oldKey, String newKey) =>
      conn.sendExpectSuccess([_Cmd.RENAME, keyBytes(oldKey), keyBytes(newKey)]);

  Future<bool> renamenx(String oldKey, String newKey) =>
      conn.sendExpectIntSuccess([_Cmd.RENAMENX, keyBytes(oldKey), keyBytes(newKey)]);

  Future<bool> expire(String key, int expireInSecs) =>
      conn.sendExpectIntSuccess([_Cmd.EXPIRE, keyBytes(key), toBytes(expireInSecs)]);

  Future<bool> pexpire(String key, int expireInMs) =>
      conn.sendExpectIntSuccess([_Cmd.EXPIRE, keyBytes(key), toBytes(expireInMs)]);

  Future<bool> expireat(String key, int unixTimeSecs) =>
      conn.sendExpectIntSuccess([_Cmd.EXPIREAT, keyBytes(key), toBytes(unixTimeSecs)]);

  Future<bool> pexpireat(String key, int unixTimeMs) =>
      conn.sendExpectIntSuccess([_Cmd.PEXPIREAT, keyBytes(key), toBytes(unixTimeMs)]);

  Future<int> ttl(String key) => conn.sendExpectInt([_Cmd.TTL, keyBytes(key)]);

  Future<int> pttl(String key) => conn.sendExpectInt([_Cmd.PTTL, keyBytes(key)]);

  //SET
  Future<List<int>> smembers(String setId) => conn.sendExpectData([_Cmd.SMEMBERS, keyBytes(setId)]);

  Future<int> sadd(String setId, List<int> value) => conn.sendExpectInt([_Cmd.SADD, keyBytes(setId), value]);

  Future<int> srem(String setId, List<int> value) => conn.sendExpectInt([_Cmd.SREM, keyBytes(setId), value]);

  Future<List<int>> spop(String setId) => conn.sendExpectData([_Cmd.SPOP, keyBytes(setId)]);

  Future smove(String fromSetId, String toSetId, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.SMOVE, keyBytes(fromSetId), keyBytes(toSetId), value]);

  Future<int> scard(String setId) => conn.sendExpectInt([_Cmd.SCARD, keyBytes(setId)]);

  Future<bool> sismember(String setId, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.SISMEMBER, keyBytes(setId), value]);

  Future<List<List<int>>> sinter(List<String> setIds) =>
      conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.SINTER, setIds));

  Future sinterstore(String intoSetId, List<String> setIds) =>
      conn.sendExpectSuccess(_Utils.mergeCommandWithStringArgs(_Cmd.SINTERSTORE, $(setIds).insert(0, intoSetId)));

  Future<List<List<int>>> sunion(List<String> setIds) =>
      conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.SUNION, setIds));

  Future sunionstore(String intoSetId, List<String> setIds) =>
      conn.sendExpectSuccess(_Utils.mergeCommandWithStringArgs(_Cmd.SUNIONSTORE, $(setIds).insert(0, intoSetId)));

  Future<List<List<int>>> sdiff(String fromSetId, List<String> withSetIds) =>
      conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.SDIFF, $(withSetIds).insert(0, fromSetId)));

  Future sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds){
    withSetIds.insertRange(0, 1, fromSetId);
    withSetIds.insertRange(0, 1, intoSetId);
    return conn.sendExpectSuccess(_Utils.mergeCommandWithStringArgs(_Cmd.SDIFFSTORE, withSetIds));
  }

  Future<List<int>> srandmember(String setId) => conn.sendExpectData([_Cmd.SRANDMEMBER, keyBytes(setId)]);

  //SORT SET/LIST
  Future<List<List<int>>> sort(String listOrSetId,
    [String sortPattern, int skip, int take, String getPattern, bool sortAlpha=false, bool sortDesc=false, String storeAtKey]){

    List<List<int>> cmdWithArgs = [_Cmd.SORT, keyBytes(listOrSetId)];

    if (sortPattern != null) {
      cmdWithArgs.add(_Cmd.BY);
      cmdWithArgs.add(toBytes(sortPattern));
    }

    if (skip != null || take != null){
      cmdWithArgs.add(_Cmd.LIMIT);
      cmdWithArgs.add(toBytes(skip == null ? 0 : skip));
      cmdWithArgs.add(toBytes(take == null ? 0 : take));
    }

    if (getPattern != null) {
      cmdWithArgs.add(_Cmd.GET);
      cmdWithArgs.add(toBytes(getPattern));
    }

    if (sortDesc) cmdWithArgs.add(_Cmd.DESC);

    if (sortAlpha) cmdWithArgs.add(_Cmd.ALPHA);

    if (storeAtKey != null) {
      cmdWithArgs.add(_Cmd.STORE);
      cmdWithArgs.add(toBytes(storeAtKey));
    }

    return conn.sendExpectMultiData(cmdWithArgs);
  }

  //LIST
  Future<List<List<int>>> lrange(String listId, int startingFrom, int endingAt) =>
      conn.sendExpectMultiData([_Cmd.LRANGE, keyBytes(listId), toBytes(startingFrom), toBytes(endingAt)]);

  Future<int> lpush(String listId, List<int> value) =>
      conn.sendExpectInt([_Cmd.LPUSH, keyBytes(listId), value]);

  Future<int> lpushx(String listId, List<int> value) =>
      conn.sendExpectInt([_Cmd.LPUSHX, keyBytes(listId), value]);

  Future<int> rpush(String listId, List<int> value) =>
      conn.sendExpectInt([_Cmd.RPUSH, keyBytes(listId), value]);

  Future<int> rpushx(String listId, List<int> value) =>
      conn.sendExpectInt([_Cmd.RPUSHX, keyBytes(listId), value]);

  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt) =>
      conn.sendExpectSuccess([_Cmd.LTRIM, keyBytes(listId), toBytes(keepStartingFrom), toBytes(keepEndingAt)]);

  Future<int> lrem(String listId, int removeNoOfMatches, List<int> value) =>
      conn.sendExpectInt([_Cmd.LREM, keyBytes(listId), toBytes(removeNoOfMatches), value]);

  Future<int> llen(String listId) => conn.sendExpectInt([_Cmd.LLEN, keyBytes(listId)]);

  Future<List<int>> lindex(String listId, int listIndex) =>
      conn.sendExpectData([_Cmd.LINDEX, keyBytes(listId), toBytes(listIndex)]);

  Future lset(String listId, int listIndex, List<int> value) =>
      conn.sendExpectInt([_Cmd.LSET, keyBytes(listId), toBytes(listIndex), value]);

  Future<List<int>> lpop(String listId) => conn.sendExpectData([_Cmd.LPOP, keyBytes(listId)]);

  Future<List<int>> rpop(String listId) => conn.sendExpectData([_Cmd.RPOP, keyBytes(listId)]);

  Future<List<int>> rpoplpush(String fromListId, String toListId) =>
      conn.sendExpectData([_Cmd.RPOPLPUSH, keyBytes(fromListId), keyBytes(toListId)]);

  //SORTED SETS
  Future<int> zadd(String setId, num score, List<int> value) =>
      conn.sendExpectInt([_Cmd.ZADD, keyBytes(setId), toBytes(score), value]);

  Future<int> zrem(String setId, List<int> value) =>
      conn.sendExpectInt([_Cmd.ZREM, keyBytes(setId), value]);

  Future<double> zincrby(String setId, num incrBy, List<int> value) =>
      conn.sendExpectDouble([_Cmd.ZINCRBY, keyBytes(setId), toBytes(incrBy), value]);

  Future<int> zrank(String setId, List<int> value) => conn.sendExpectInt([_Cmd.ZRANK, keyBytes(setId), value]);

  Future<int> zrevrank(String setId, List<int> value) => conn.sendExpectInt([_Cmd.ZREVRANK, keyBytes(setId), value]);

  Future<List<List<int>>> _zrange(List<int> cmdBytes, String setId, int min, int max, [bool withScores=false]){
    List<List<int>> cmdWithArgs = [cmdBytes, keyBytes(setId), toBytes(min), toBytes(max)];
    if (withScores) cmdWithArgs.add(_Cmd.WITHSCORES);
    conn.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrange(String setId, int min, int max) =>
      _zrange(_Cmd.ZRANGE, setId, min, max);

  Future<List<List<int>>> zrangeWithScores(String setId, int min, int max) =>
      _zrange(_Cmd.ZRANGE, setId, min, max, withScores:true);

  Future<List<List<int>>> zrevrange(String setId, int min, int max) =>
      _zrange(_Cmd.ZREVRANGE, setId, min, max);

  Future<List<List<int>>> zrevrangeWithScores(String setId, int min, int max) =>
      _zrange(_Cmd.ZREVRANGE, setId, min, max, withScores:true);

  Future<List<List<int>>> _zrangeByScore(List<int> cmdBytes, String setId, num min, num max, [int skip, int take, bool withScores=false]){
    List<List<int>> cmdWithArgs = [cmdBytes, keyBytes(setId), toBytes(min), toBytes(max)];
    if (skip != null || take != null){
      cmdWithArgs.add(_Cmd.LIMIT);
      cmdWithArgs.add(toBytes(skip == null ? 0 : skip));
      cmdWithArgs.add(toBytes(take == null ? 0 : take));
    }
    if (withScores) cmdWithArgs.add(_Cmd.WITHSCORES);
    conn.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrangebyscore(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZRANGEBYSCORE, setId, min, max, skip, take, withScores:true);

  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take, withScores:true);

  Future<int> zremrangebyrank(String setId, int min, int max) =>
      conn.sendExpectInt([_Cmd.ZREMRANGEBYRANK, keyBytes(setId), toBytes(min), toBytes(max)]);

  Future<int> zremrangebyscore(String setId, num min, num max) =>
      conn.sendExpectInt([_Cmd.ZREMRANGEBYSCORE, keyBytes(setId), toBytes(min), toBytes(max)]);

  Future<int> zcard(String setId) => conn.sendExpectInt([_Cmd.ZCARD, keyBytes(setId)]);

  Future<double> zscore(String setId, List<int> value) => conn.sendExpectDouble([_Cmd.ZSCORE, value]);

  Future<int> zunionstore(String intoSetId, List<String> setIds){
    setIds.insertRange(0, 1, setIds.length.toString());
    setIds.insertRange(0, 1, intoSetId);
    return conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.ZUNIONSTORE, setIds));
  }

  Future<int> zinterstore(String intoSetId, List<String> setIds){
    setIds.insertRange(0, 1, setIds.length.toString());
    setIds.insertRange(0, 1, intoSetId);
    return conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.ZINTERSTORE, setIds));
  }

  //HASH
  Future<int> hset(String hashId, String key, List<int> value) =>
      conn.sendExpectInt([_Cmd.HSET, keyBytes(hashId), keyBytes(key), toBytes(value)]);

  Future<int> hsetnx(String hashId, String key, List<int> value) =>
      conn.sendExpectInt([_Cmd.HSETNX, keyBytes(hashId), keyBytes(key), toBytes(value)]);

  Future hmset(String hashId, List<List<int>> keys, List<List<int>> values) =>
    conn.sendExpectSuccess(_Utils.mergeParamsWithKeysAndValues([_Cmd.HMSET, keyBytes(hashId)], keys, values));

  Future<int> hincrby(String hashId, String key, int incrBy) =>
      conn.sendExpectInt([_Cmd.HINRYBY, keyBytes(hashId), keyBytes(key), toBytes(incrBy)]);

  Future<double> hincrbyfloat(String hashId, String key, double incrBy) =>
      conn.sendExpectDouble([_Cmd.HINRYBYFLOAT, keyBytes(hashId), keyBytes(key), toBytes(incrBy)]);

  Future<List<int>> hget(String hashId, String key) =>
      conn.sendExpectData([_Cmd.HGET, keyBytes(hashId), keyBytes(key)]);

  Future<List<List<int>>> hmget(String hashId, List<String> keys) =>
      conn.sendExpectMultiData(_Utils.mergeCommandWithKeyAndStringArgs(_Cmd.HMGET, hashId, keys));

  Future<int> hdel(String hashId, String key) =>
      conn.sendExpectInt([_Cmd.HDEL, keyBytes(hashId), keyBytes(key)]);

  Future<bool> hexists(String hashId, String key) =>
      conn.sendExpectIntSuccess([_Cmd.HEXISTS, keyBytes(hashId), keyBytes(key)]);

  Future<int> hlen(String hashId) =>
      conn.sendExpectInt([_Cmd.HLEN, keyBytes(hashId)]);

  Future<List<String>> hkeys(String hashId) =>
      conn.sendExpectMultiData([_Cmd.HKEYS, keyBytes(hashId)]).transform((bytes) => bytes.map((x) => new String.fromCharCodes(x)));

  Future<List<List<int>>> hvals(String hashId) =>
      conn.sendExpectMultiData([_Cmd.HVALS, keyBytes(hashId)]);

  Future<List<List<int>>> hgetall(String hashId) =>
      conn.sendExpectMultiData([_Cmd.HGETALL, keyBytes(hashId)]);

  Map get stats() => conn.stats;

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

  //Sort Set/List
  static get SORT() => "SORT".charCodes(); //BY LIMIT GET DESC ALPHA STORE
  static get BY() => "BY".charCodes();
  static get DESC() => "DESC".charCodes();
  static get ALPHA() => "ALPHA".charCodes();
  static get STORE() => "STORE".charCodes();

  //List
  static get LRANGE() => "LRANGE".charCodes();
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

  static List<List<int>> mergeCommandWithKeyAndStringArgs(List<int> cmd, String key, List<String> args){
    args.insertRange(0, 1, key);
    return mergeCommandWithArgs(cmd, args.map((x) => x.charCodes()));
  }

  static List<List<int>> mergeCommandWithArgs(List<int> cmd, List<List<int>> args){
    List<List<int>> mergedBytes = new List<List<int>>();
    mergedBytes.add(cmd);
    for (var i = 0; i < args.length; i++){
      mergedBytes.add(args[i]);
    }
    return mergedBytes;
  }

}