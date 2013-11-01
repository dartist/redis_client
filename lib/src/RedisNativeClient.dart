//part of redis_client;
library redis_native_client;

import 'dart:async';

import 'package:dartmixins/mixin.dart';

import 'RedisConnection.dart';

abstract class RedisNativeClient {
  factory RedisNativeClient([String connStr]) => new _RedisNativeClient(connStr);

  void set onConnect(void callback());
  void set onClosed(void callback());
  void set onError(void callback(e));

  Map get stats;

  int get db;
  Future select(int db);
  Future<int> get dbsize;
  Future<int> get lastsave;
  Future flushdb();
  Future flushall();
  Future<Map> get info;
  Future<bool> ping();
  Future<List<int>> echo(List<int> value);
  Future save();
  Future bgsave();
  Future shutdown();
  Future bgrewriteaof();
  Future quit();

  //KEYS
  Future<String> type(String key);
  Future<List<String>> keys(String pattern);
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
  Future<List<List<int>>> smembers(String setId);
  Future<int> sadd(String setId, List<int> value);
  Future<int> smadd(String setId, List<List<int>> values);
  Future<int> srem(String setId, List<int> value);
  Future<List<int>> spop(String setId);
  Future<bool> smove(String fromSetId, String toSetId, List<int> value);
  Future<int> scard(String setId);
  Future<bool> sismember(String setId, List<int> value);
  Future<List<List<int>>> sinter(List<String> setIds);
  Future<int> sinterstore(String intoSetId, List<String> setIds);
  Future<List<List<int>>> sunion(List<String> setIds);
  Future<int> sunionstore(String intoSetId, List<String> setIds);
  Future<List<List<int>>> sdiff(String fromSetId, List<String> withSetIds);
  Future<int> sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds);
  Future<List<int>> srandmember(String setId);

  //LIST
  Future<List<List<int>>> lrange(String listId, int startingFrom, int endingAt);
  Future<int> lpush(String listId, List<int> value);
  Future<int> mlpush(String listId, List<List<int>> values);
  Future<int> lpushx(String listId, List<int> value);
  Future<int> mlpushx(String listId, List<List<int>> values);
  Future<int> rpush(String listId, List<int> value);
  Future<int> mrpush(String listId, List<List<int>> values);
  Future<int> rpushx(String listId, List<int> value);
  Future<int> mrpushx(String listId, List<List<int>> values);
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
  Future<int> zmadd(String setId, List<List<int>> scoresAndValues);
  Future<int> zrem(String setId, List<int> value);
  Future<int> zmrem(String setId, List<List<int>> values);
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
  Future<bool> hset(String hashId, String key, List<int> value);
  Future<bool> hsetnx(String hashId, String key, List<int> value);
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
  Function _emptyValue;
  Function _emptyList;
  Function _emptyMap;

  _RedisNativeClient([String this.connStr]) {
    conn = new RedisConnection(connStr);
    conn.onConnect = () { 
      if (_onConnect != null) _onConnect(); 
    };
    conn.onClosed = () { 
      if (_onClosed != null) _onClosed(); 
    };
    conn.onError = (e) { 
      if (_onError != null) _onError(e); 
    };

    _emptyValue = () { Completer<Object> task = new Completer<Object>(); task.complete(null); return task.future; };
    _emptyList = () { Completer<List> task = new Completer<List>(); task.complete(const []); return task.future; };
    _emptyMap = () { Completer<Map> task = new Completer<Map>(); task.complete(const {}); return task.future; };
  }

  static String string(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes);
  static List<int> toBytes(val) => val == null ? new List<int>() : val.toString().codeUnits;
  static List<int> keyBytes(String key){
    if (key == null || key.isEmpty) throw new Exception("key is null");
    return key.codeUnits;
  }

  Function _onConnect;
  void set onConnect(void callback()) {
    _onConnect = callback;
  }
  Function _onClosed;
  void set onClosed(void callback()) {
    _onClosed = callback;
  }
  Function _onError;
  void set onError(void callback(e)) {
    _onError = callback;
  }

  int get db => conn.db;
  Future select(int db) => conn.select(db);

  Future<int> get dbsize => conn.sendExpectInt([_Cmd.DBSIZE]);

  Future<int> get lastsave => conn.sendExpectInt([_Cmd.LASTSAVE]);

  Future flushdb() => conn.sendExpectSuccess([_Cmd.FLUSHDB]);

  Future flushall() => conn.sendExpectSuccess([_Cmd.FLUSHALL]);

  Future save() => conn.sendExpectSuccess([_Cmd.SAVE]);

  Future bgsave() => conn.sendExpectSuccess([_Cmd.BGSAVE]);

  Future shutdown() => conn.sendExpectSuccess([_Cmd.SHUTDOWN]);

  Future bgrewriteaof() => conn.sendExpectSuccess([_Cmd.BGREWRITEAOF]);

  Future quit() => conn.sendExpectSuccess([_Cmd.QUIT]);

  Future<Map> get info{
    return conn.sendExpectString([_Cmd.INFO])
      .then((String lines){
         Map info = {};
         for(String line in lines.split("\r\n")){
           List<String> kvp = $(line).splitOnFirst(":");
           info[kvp[0]] = kvp.length == 2 ? kvp[1] : null;
         }
         return info;
      });
  }

  Future<bool> ping() => conn.sendExpectCode([_Cmd.PING]).then((String r) => r == "PONG");

  Future<List<int>> echo(List<int> value) => conn.sendExpectData([_Cmd.ECHO, value]);

  Future<String> type(String key) => conn.sendExpectCode([_Cmd.TYPE, keyBytes(key)]);

  Future<List<String>> keys(String pattern) =>
      conn.sendExpectMultiData([_Cmd.KEYS, keyBytes(pattern)]).then((x) => x.map((k) => new String.fromCharCodes(k)));

  Future<List<int>> get(String key) =>
      conn.sendExpectData([_Cmd.GET, keyBytes(key)]);

  Future<List<List<int>>> mget(List<String> keys) => keys.isEmpty ? _emptyList() :
    conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.MGET, keys));

  Future<List<int>> getset(String key, List<int> value) =>
      conn.sendExpectData([_Cmd.GETSET, keyBytes(key), value]);

  Future set(String key, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.SET, keyBytes(key), value]);

  Future setex(String key, int expireInSecs, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.SETEX, keyBytes(key), toBytes(expireInSecs), value]);

  Future psetex(String key, int expireInMs, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.PSETEX, keyBytes(key), toBytes(expireInMs), value]);

  Future<bool> persist(String key) => conn.sendExpectIntSuccess([_Cmd.PERSIST, keyBytes(key)]);

  Future mset(List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? _emptyValue() :
    conn.sendExpectSuccess(_Utils.mergeCommandWithKeysAndValues(_Cmd.MSET, keys, values));

  Future<bool> msetnx(List<List<int>> keys, List<List<int>> values) =>
    conn.sendExpectIntSuccess(_Utils.mergeCommandWithKeysAndValues(_Cmd.MSETNX, keys, values));

  Future<bool> exists(String key) => conn.sendExpectIntSuccess([_Cmd.EXISTS, keyBytes(key)]);

  Future<int> del(String key) => conn.sendExpectInt([_Cmd.DEL, keyBytes(key)]);

  Future<int> mdel(List<String> keys) => keys.isEmpty ? _emptyValue() :
      conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.DEL, keys));

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
      conn.sendExpectIntSuccess([_Cmd.PEXPIRE, keyBytes(key), toBytes(expireInMs)]);

  Future<bool> expireat(String key, int unixTimeSecs) =>
      conn.sendExpectIntSuccess([_Cmd.EXPIREAT, keyBytes(key), toBytes(unixTimeSecs)]);

  Future<bool> pexpireat(String key, int unixTimeMs) =>
      conn.sendExpectIntSuccess([_Cmd.PEXPIREAT, keyBytes(key), toBytes(unixTimeMs)]);

  Future<int> ttl(String key) => conn.sendExpectInt([_Cmd.TTL, keyBytes(key)]);

  Future<int> pttl(String key) => conn.sendExpectInt([_Cmd.PTTL, keyBytes(key)]);

  //SET
  Future<List<List<int>>> smembers(String setId) => conn.sendExpectMultiData([_Cmd.SMEMBERS, keyBytes(setId)]);

  Future<int> sadd(String setId, List<int> value) => conn.sendExpectInt([_Cmd.SADD, keyBytes(setId), value]);

  Future<int> smadd(String setId, List<List<int>> values) =>
      conn.sendExpectInt(_Utils.mergeCommandWithKeyAndArgs(_Cmd.SADD, setId, values));

  Future<int> srem(String setId, List<int> value) => conn.sendExpectInt([_Cmd.SREM, keyBytes(setId), value]);

  Future<List<int>> spop(String setId) => conn.sendExpectData([_Cmd.SPOP, keyBytes(setId)]);

  Future<bool> smove(String fromSetId, String toSetId, List<int> value) =>
      conn.sendExpectIntSuccess([_Cmd.SMOVE, keyBytes(fromSetId), keyBytes(toSetId), value]);

  Future<int> scard(String setId) => conn.sendExpectInt([_Cmd.SCARD, keyBytes(setId)]);

  Future<bool> sismember(String setId, List<int> value) =>
      conn.sendExpectIntSuccess([_Cmd.SISMEMBER, keyBytes(setId), value]);

  Future<List<List<int>>> sinter(List<String> setIds) =>
      conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.SINTER, setIds));

  Future<int> sinterstore(String intoSetId, List<String> setIds) =>
      conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.SINTERSTORE, $(setIds).insert(0, intoSetId)));

  Future<List<List<int>>> sunion(List<String> setIds) =>
      conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.SUNION, setIds));

  Future<int> sunionstore(String intoSetId, List<String> setIds) =>
      conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.SUNIONSTORE, $(setIds).insert(0, intoSetId)));

  Future<List<List<int>>> sdiff(String fromSetId, List<String> withSetIds) =>
      conn.sendExpectMultiData(_Utils.mergeCommandWithStringArgs(_Cmd.SDIFF, $(withSetIds).insert(0, fromSetId)));

  Future<int> sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds){
    withSetIds.insertRange(0, 1, fromSetId);
    withSetIds.insertRange(0, 1, intoSetId);
    return conn.sendExpectInt(_Utils.mergeCommandWithStringArgs(_Cmd.SDIFFSTORE, withSetIds));
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

  Future<int> mlpush(String listId, List<List<int>> values) =>
      conn.sendExpectInt(_Utils.mergeCommandWithKeyAndArgs(_Cmd.LPUSH, listId, values));

  Future<int> lpushx(String listId, List<int> value) =>
      conn.sendExpectInt([_Cmd.LPUSHX, keyBytes(listId), value]);

  Future<int> mlpushx(String listId, List<List<int>> values) =>
      conn.sendExpectInt(_Utils.mergeCommandWithKeyAndArgs(_Cmd.LPUSHX, listId, values));

  Future<int> rpush(String listId, List<int> value) =>
      conn.sendExpectInt([_Cmd.RPUSH, keyBytes(listId), value]);

  Future<int> mrpush(String listId, List<List<int>> values) =>
      conn.sendExpectInt(_Utils.mergeCommandWithKeyAndArgs(_Cmd.RPUSH, listId, values));

  Future<int> rpushx(String listId, List<int> value) =>
      conn.sendExpectInt([_Cmd.RPUSHX, keyBytes(listId), value]);

  Future<int> mrpushx(String listId, List<List<int>> values) =>
      conn.sendExpectInt(_Utils.mergeCommandWithKeyAndArgs(_Cmd.RPUSHX, listId, values));

  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt) =>
      conn.sendExpectSuccess([_Cmd.LTRIM, keyBytes(listId), toBytes(keepStartingFrom), toBytes(keepEndingAt)]);

  Future<int> lrem(String listId, int removeNoOfMatches, List<int> value) =>
      conn.sendExpectInt([_Cmd.LREM, keyBytes(listId), toBytes(removeNoOfMatches), value]);

  Future<int> llen(String listId) => conn.sendExpectInt([_Cmd.LLEN, keyBytes(listId)]);

  Future<List<int>> lindex(String listId, int listIndex) =>
      conn.sendExpectData([_Cmd.LINDEX, keyBytes(listId), toBytes(listIndex)]);

  Future lset(String listId, int listIndex, List<int> value) =>
      conn.sendExpectSuccess([_Cmd.LSET, keyBytes(listId), toBytes(listIndex), value]);

  Future<List<int>> lpop(String listId) => conn.sendExpectData([_Cmd.LPOP, keyBytes(listId)]);

  Future<List<int>> rpop(String listId) => conn.sendExpectData([_Cmd.RPOP, keyBytes(listId)]);

  Future<List<int>> rpoplpush(String fromListId, String toListId) =>
      conn.sendExpectData([_Cmd.RPOPLPUSH, keyBytes(fromListId), keyBytes(toListId)]);

  //SORTED SETS
  Future<int> zadd(String setId, num score, List<int> value) =>
      conn.sendExpectInt([_Cmd.ZADD, keyBytes(setId), toBytes(score), value]);

  Future<int> zmadd(String setId, List<List<int>> scoresAndValues) =>
    conn.sendExpectInt(_Utils.mergeCommandWithKeyAndArgs(_Cmd.ZADD, setId, scoresAndValues));

  Future<int> zrem(String setId, List<int> value) =>
      conn.sendExpectInt([_Cmd.ZREM, keyBytes(setId), value]);

  Future<int> zmrem(String setId, List<List<int>> values) =>
      conn.sendExpectInt(_Utils.mergeCommandWithKeyAndArgs(_Cmd.ZREM, setId, values));

  Future<double> zincrby(String setId, num incrBy, List<int> value) =>
      conn.sendExpectDouble([_Cmd.ZINCRBY, keyBytes(setId), toBytes(incrBy), value]);

  Future<int> zrank(String setId, List<int> value) => conn.sendExpectInt([_Cmd.ZRANK, keyBytes(setId), value]);

  Future<int> zrevrank(String setId, List<int> value) => conn.sendExpectInt([_Cmd.ZREVRANK, keyBytes(setId), value]);

  Future<List<List<int>>> _zrange(List<int> cmdBytes, String setId, int min, int max, {bool withScores: false}){
    List<List<int>> cmdWithArgs = [cmdBytes, keyBytes(setId), toBytes(min), toBytes(max)];
    if (withScores) cmdWithArgs.add(_Cmd.WITHSCORES);
    return conn.sendExpectMultiData(cmdWithArgs);
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
    return conn.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrangebyscore(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) =>
      _zrangeByScore(_Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<int> zremrangebyrank(String setId, int min, int max) =>
      conn.sendExpectInt([_Cmd.ZREMRANGEBYRANK, keyBytes(setId), toBytes(min), toBytes(max)]);

  Future<int> zremrangebyscore(String setId, num min, num max) =>
      conn.sendExpectInt([_Cmd.ZREMRANGEBYSCORE, keyBytes(setId), toBytes(min), toBytes(max)]);

  Future<int> zcard(String setId) => conn.sendExpectInt([_Cmd.ZCARD, keyBytes(setId)]);

  Future<double> zscore(String setId, List<int> value) => conn.sendExpectDouble([_Cmd.ZSCORE, keyBytes(setId), value]);

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
  Future<bool> hset(String hashId, String key, List<int> value) =>
      conn.sendExpectIntSuccess([_Cmd.HSET, keyBytes(hashId), keyBytes(key), value]);

  Future<bool> hsetnx(String hashId, String key, List<int> value) =>
      conn.sendExpectIntSuccess([_Cmd.HSETNX, keyBytes(hashId), keyBytes(key), value]);

  Future hmset(String hashId, List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? _emptyValue() :
    conn.sendExpectSuccess(_Utils.mergeParamsWithKeysAndValues([_Cmd.HMSET, keyBytes(hashId)], keys, values));

  Future<int> hincrby(String hashId, String key, int incrBy) =>
      conn.sendExpectInt([_Cmd.HINCRBY, keyBytes(hashId), keyBytes(key), toBytes(incrBy)]);

  Future<double> hincrbyfloat(String hashId, String key, double incrBy) =>
      conn.sendExpectDouble([_Cmd.HINCRBYFLOAT, keyBytes(hashId), keyBytes(key), toBytes(incrBy)]);

  Future<List<int>> hget(String hashId, String key) =>
      conn.sendExpectData([_Cmd.HGET, keyBytes(hashId), keyBytes(key)]);

  Future<List<List<int>>> hmget(String hashId, List<String> keys) => keys.isEmpty ? _emptyList() :
      conn.sendExpectMultiData(_Utils.mergeCommandWithKeyAndStringArgs(_Cmd.HMGET, hashId, keys));

  Future<int> hdel(String hashId, String key) =>
      conn.sendExpectInt([_Cmd.HDEL, keyBytes(hashId), keyBytes(key)]);

  Future<bool> hexists(String hashId, String key) =>
      conn.sendExpectIntSuccess([_Cmd.HEXISTS, keyBytes(hashId), keyBytes(key)]);

  Future<int> hlen(String hashId) =>
      conn.sendExpectInt([_Cmd.HLEN, keyBytes(hashId)]);

  Future<List<String>> hkeys(String hashId) =>
      conn.sendExpectMultiData([_Cmd.HKEYS, keyBytes(hashId)]).then((bytes) => bytes.map((x) => new String.fromCharCodes(x)));

  Future<List<List<int>>> hvals(String hashId) =>
      conn.sendExpectMultiData([_Cmd.HVALS, keyBytes(hashId)]);

  Future<List<List<int>>> hgetall(String hashId) =>
      conn.sendExpectMultiData([_Cmd.HGETALL, keyBytes(hashId)]);

  Map get stats => conn.stats;

  void close() => conn.close();
}

//TODO change to lazy static initializers
class _Cmd {

  //ADMIN
  static get DBSIZE => "DBSIZE".codeUnits;
  static get INFO => "INFO".codeUnits;
  static get LASTSAVE => "LASTSAVE".codeUnits;
  static get PING => "PING".codeUnits;
  static get ECHO => "ECHO".codeUnits;
  static get SLAVEOF => "SLAVEOF".codeUnits;
  static get NO => "NO".codeUnits;
  static get ONE => "ONE".codeUnits;
  static get CONFIG => "CONFIG".codeUnits; //GET SET
  static get RESETSTAT => "RESETSTAT".codeUnits;
  static get TIME => "TIME".codeUnits;
  static get DEBUG => "DEBUG".codeUnits; //OBJECT SEGFAULT
  static get SEGFAULT => "SEGFAULT".codeUnits;
  static get RESTORE => "RESTORE".codeUnits;
  static get MIGRATE => "MIGRATE".codeUnits;
  static get MOVE => "MOVE".codeUnits;
  static get OBJECT => "OBJECT".codeUnits; //REFCOUNT ENCODING IDLETIME
  static get REFCOUNT => "REFCOUNT".codeUnits;
  static get ENCODING => "ENCODING".codeUnits;
  static get IDLETIME => "IDLETIME".codeUnits;
  static get SAVE => "SAVE".codeUnits;
  static get BGSAVE => "BGSAVE".codeUnits;
  static get SHUTDOWN => "SHUTDOWN".codeUnits;
  static get BGREWRITEAOF => "BGREWRITEAOF".codeUnits;
  static get QUIT => "QUIT".codeUnits;
  static get FLUSHDB => "FLUSHDB".codeUnits;
  static get FLUSHALL => "FLUSHALL".codeUnits;
  static get KEYS => "KEYS".codeUnits;
  static get SLOWLOG => "SLOWLOG".codeUnits;

  //Keys
  static get TYPE => "TYPE".codeUnits;
  static get STRLEN => "STRLEN".codeUnits;
  static get SET => "SET".codeUnits;
  static get GET => "GET".codeUnits;
  static get DEL => "DEL".codeUnits;
  static get SETEX => "SETEX".codeUnits;
  static get PSETEX => "PSETEX".codeUnits;
  static get SETNX => "SETNX".codeUnits;
  static get PERSIST => "PERSIST".codeUnits;
  static get MSET => "MSET".codeUnits;
  static get MSETNX => "MSETNX".codeUnits;
  static get GETSET => "GETSET".codeUnits;
  static get EXISTS => "EXISTS".codeUnits;
  static get INCR => "INCR".codeUnits;
  static get INCRBY => "INCRBY".codeUnits;
  static get INCRBYFLOAT => "INCRBYFLOAT".codeUnits;
  static get DECR => "DECR".codeUnits;
  static get DECRBY => "DECRBY".codeUnits;
  static get APPEND => "APPEND".codeUnits;
  static get SUBSTR => "SUBSTR".codeUnits;
  static get GETRANGE => "GETRANGE".codeUnits;
  static get SETRANGE => "SETRANGE".codeUnits;
  static get GETBIT => "GETBIT".codeUnits;
  static get SETBIT => "SETBIT".codeUnits;
  static get RANDOMKEY => "RANDOMKEY".codeUnits;
  static get RENAME => "RENAME".codeUnits;
  static get RENAMENX => "RENAMENX".codeUnits;
  static get EXPIRE => "EXPIRE".codeUnits;
  static get PEXPIRE => "PEXPIRE".codeUnits;
  static get EXPIREAT => "EXPIREAT".codeUnits;
  static get PEXPIREAT => "PEXPIREAT".codeUnits;
  static get TTL => "TTL".codeUnits;
  static get PTTL => "PTTL".codeUnits;

  //Transactions
  static get MGET => "MGET".codeUnits;
  static get WATCH => "WATCH".codeUnits;
  static get UNWATCH => "UNWATCH".codeUnits;
  static get MULTI => "MULTI".codeUnits;
  static get EXEC => "EXEC".codeUnits;
  static get DISCARD => "DISCARD".codeUnits;

  //SET
  static get SMEMBERS => "SMEMBERS".codeUnits;
  static get SADD => "SADD".codeUnits;
  static get SREM => "SREM".codeUnits;
  static get SPOP => "SPOP".codeUnits;
  static get SMOVE => "SMOVE".codeUnits;
  static get SCARD => "SCARD".codeUnits;
  static get SISMEMBER => "SISMEMBER".codeUnits;
  static get SINTER => "SINTER".codeUnits;
  static get SINTERSTORE => "SINTERSTORE".codeUnits;
  static get SUNION => "SUNION".codeUnits;
  static get SUNIONSTORE => "SUNIONSTORE".codeUnits;
  static get SDIFF => "SDIFF".codeUnits;
  static get SDIFFSTORE => "SDIFFSTORE".codeUnits;
  static get SRANDMEMBER => "SRANDMEMBER".codeUnits;

  //Sort Set/List
  static get SORT => "SORT".codeUnits; //BY LIMIT GET DESC ALPHA STORE
  static get BY => "BY".codeUnits;
  static get DESC => "DESC".codeUnits;
  static get ALPHA => "ALPHA".codeUnits;
  static get STORE => "STORE".codeUnits;

  //List
  static get LRANGE => "LRANGE".codeUnits;
  static get RPUSH => "RPUSH".codeUnits;
  static get RPUSHX => "RPUSHX".codeUnits;
  static get LPUSH => "LPUSH".codeUnits;
  static get LPUSHX => "LPUSHX".codeUnits;
  static get LTRIM => "LTRIM".codeUnits;
  static get LREM => "LREM".codeUnits;
  static get LLEN => "LLEN".codeUnits;
  static get LINDEX => "LINDEX".codeUnits;
  static get LINSERT => "LINSERT".codeUnits;
  static get AFTER => "AFTER".codeUnits;
  static get BEFORE => "BEFORE".codeUnits;
  static get LSET => "LSET".codeUnits;
  static get LPOP => "LPOP".codeUnits;
  static get RPOP => "RPOP".codeUnits;
  static get BLPOP => "BLPOP".codeUnits;
  static get BRPOP => "BRPOP".codeUnits;
  static get RPOPLPUSH => "RPOPLPUSH".codeUnits;

  //Sorted Sets
  static get ZADD => "ZADD".codeUnits;
  static get ZREM => "ZREM".codeUnits;
  static get ZINCRBY => "ZINCRBY".codeUnits;
  static get ZRANK => "ZRANK".codeUnits;
  static get ZREVRANK => "ZREVRANK".codeUnits;
  static get ZRANGE => "ZRANGE".codeUnits;
  static get ZREVRANGE => "ZREVRANGE".codeUnits;
  static get WITHSCORES => "WITHSCORES".codeUnits;
  static get LIMIT => "LIMIT".codeUnits;
  static get ZRANGEBYSCORE => "ZRANGEBYSCORE".codeUnits;
  static get ZREVRANGEBYSCORE => "ZREVRANGEBYSCORE".codeUnits;
  static get ZREMRANGEBYRANK => "ZREMRANGEBYRANK".codeUnits;
  static get ZREMRANGEBYSCORE => "ZREMRANGEBYSCORE".codeUnits;
  static get ZCARD => "ZCARD".codeUnits;
  static get ZSCORE => "ZSCORE".codeUnits;
  static get ZUNIONSTORE => "ZUNIONSTORE".codeUnits;
  static get ZINTERSTORE => "ZINTERSTORE".codeUnits;

  //Hash
  static get HSET => "HSET".codeUnits;
  static get HSETNX => "HSETNX".codeUnits;
  static get HMSET => "HMSET".codeUnits;
  static get HINCRBY => "HINCRBY".codeUnits;
  static get HINCRBYFLOAT => "HINCRBYFLOAT".codeUnits;
  static get HGET => "HGET".codeUnits;
  static get HMGET => "HMGET".codeUnits;
  static get HDEL => "HDEL".codeUnits;
  static get HEXISTS => "HEXISTS".codeUnits;
  static get HLEN => "HLEN".codeUnits;
  static get HKEYS => "HKEYS".codeUnits;
  static get HVALS => "HVALS".codeUnits;
  static get HGETALL => "HGETALL".codeUnits;

  //Pub/Sub
  static get PUBLISH => "PUBLISH".codeUnits;
  static get SUBSCRIBE => "SUBSCRIBE".codeUnits;
  static get UNSUBSCRIBE => "UNSUBSCRIBE".codeUnits;
  static get PSUBSCRIBE => "PSUBSCRIBE".codeUnits;
  static get PUNSUBSCRIBE => "PUNSUBSCRIBE".codeUnits;

  //Scripting
  static get EVAL => "EVAL".codeUnits;
  static get SCRIPT => "SCRIPT".codeUnits; //EXISTS FLUSH KILL LOAD
  static get KILL => "KILL".codeUnits;
  static get LOAD => "LOAD".codeUnits;

}

class _Utils {
  static List<List<int>> mergeCommandWithKeysAndValues(List<int> cmd, List<List<int>> keys, List<List<int>> values) =>
    mergeParamsWithKeysAndValues([cmd], keys, values);

  static List<List<int>> mergeParamsWithKeysAndValues(List<List<int>> firstParams, List<List<int>> keys, List<List<int>> values) {
    if (keys == null || keys.length == 0) {
      throw new Exception("keys is null");
    }
    if (values == null || values.length == 0) {
      throw new Exception("values is null");
    }
    if (keys.length != values.length) {
      throw new Exception("keys.length != values.length");
    }

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
    mergeCommandWithArgs(cmd, args.map((x) => x.codeUnits));

  static List<List<int>> mergeCommandWithKeyAndStringArgs(List<int> cmd, String key, List<String> args){
    args.insertRange(0, 1, key);
    return mergeCommandWithArgs(cmd, args.map((x) => x.codeUnits));
  }

  static List<List<int>> mergeCommandWithKeyAndArgs(List<int> cmd, String key, List<List<int>> args){
    args.insertRange(0, 1, key.codeUnits);
    return mergeCommandWithArgs(cmd, args);
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