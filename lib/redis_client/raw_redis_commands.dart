part of redis_client;



/**
 * This is the class that holds the raw commands that access redis.
 *
 * That means that it has to be called with binary data, and returns binary
 * data as well (instead of providing Strings or other dart objects).
 *
 * You should rarely need to access this functions. If you do, you'll probably
 * want to get the object from [RedisClient.raw].
 *
 * [RedisClient] creates an instance of this class in the constructor, and
 * provides high level methods for those methods.
 */
class RawRedisCommands {

  final RedisClient client;

  RedisConnection get connection => client.connection;

  RawRedisCommands(RedisClient this.client);

  /// Converts an object to the bytes.
  static List<int> toBytes(dynamic val) {
    if (val == null) {
      return new List<int>();
    }
    else {
      return val.toString().runes.toList();
    }
  }


  /// ADMIN
  /// =====

  Future<int> get lastsave => connection.sendExpectInt([_Cmd.LASTSAVE]);

  Future<List<int>> echo(List<int> value) => connection.sendExpectData([_Cmd.ECHO, value]);


  /// Keys
  /// ====

  Future<List<int>> get(String key) => connection.rawSend([ _Cmd.GET, RedisClient.keyBytes(key) ]).receiveBulkData();

  Future<List<List<int>>> mget(List<String> keys) => keys.isEmpty ? new Future([ ]) : connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(_Cmd.MGET, keys));

  Future<List<int>> getset(String key, List<int> value) => connection.sendExpectData([_Cmd.GETSET, RedisClient.keyBytes(key), value]);

  Future set(String key, List<int> value) => connection.rawSend([ _Cmd.SET, RedisClient.keyBytes(key), value ]).receiveStatus("OK");

  Future setex(String key, int expireInSecs, List<int> value) => connection.sendExpectSuccess([_Cmd.SETEX, RedisClient.keyBytes(key), toBytes(expireInSecs), value]);

  Future psetex(String key, int expireInMs, List<int> value) => connection.sendExpectSuccess([_Cmd.PSETEX, RedisClient.keyBytes(key), toBytes(expireInMs), value]);

  Future mset(List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? new Future(null) : connection.sendExpectSuccess(_CommandUtils.mergeCommandWithKeysAndValues(_Cmd.MSET, keys, values));

  Future<bool> msetnx(List<List<int>> keys, List<List<int>> values) => connection.sendExpectIntSuccess(_CommandUtils.mergeCommandWithKeysAndValues(_Cmd.MSETNX, keys, values));

  Future<int> append(String key, List<int> value) => connection.sendExpectInt([_Cmd.APPEND, RedisClient.keyBytes(key), value]);

  Future<List<int>> substr(String key, int fromIndex, int toIndex) => connection.sendExpectData([_Cmd.SUBSTR, RedisClient.keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> getrange(String key, int fromIndex, int toIndex) => connection.sendExpectData([_Cmd.GETRANGE, RedisClient.keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> setrange(String key, int offset, List<int> value) => connection.sendExpectData([_Cmd.SETRANGE, RedisClient.keyBytes(key), toBytes(offset), value]);

  Future<List<int>> randomkey() => connection.sendExpectData([_Cmd.RANDOMKEY]);

  Future<bool> expireat(String key, int unixTimeSecs) => connection.sendExpectIntSuccess([_Cmd.EXPIREAT, RedisClient.keyBytes(key), toBytes(unixTimeSecs)]);

  Future<bool> pexpireat(String key, int unixTimeMs) => connection.sendExpectIntSuccess([_Cmd.PEXPIREAT, RedisClient.keyBytes(key), toBytes(unixTimeMs)]);


  /// SET
  /// ===

  Future<List<List<int>>> smembers(String setId) => connection.sendExpectMultiData([_Cmd.SMEMBERS, RedisClient.keyBytes(setId)]);

  Future<int> sadd(String setId, List<int> value) => connection.sendExpectInt([_Cmd.SADD, RedisClient.keyBytes(setId), value]);

  Future<int> smadd(String setId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(_Cmd.SADD, setId, values));

  Future<int> srem(String setId, List<int> value) => connection.sendExpectInt([_Cmd.SREM, RedisClient.keyBytes(setId), value]);

  Future<List<int>> spop(String setId) => connection.sendExpectData([_Cmd.SPOP, RedisClient.keyBytes(setId)]);

  Future<bool> smove(String fromSetId, String toSetId, List<int> value) => connection.sendExpectIntSuccess([_Cmd.SMOVE, RedisClient.keyBytes(fromSetId), RedisClient.keyBytes(toSetId), value]);

  Future<bool> sismember(String setId, List<int> value) => connection.sendExpectIntSuccess([_Cmd.SISMEMBER, RedisClient.keyBytes(setId), value]);

  Future<List<List<int>>> sinter(List<String> setIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(_Cmd.SINTER, setIds));

  Future<int> sinterstore(String intoSetId, List<String> setIds) => connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(_Cmd.SINTERSTORE, $(setIds).insert(0, intoSetId)));

  Future<List<List<int>>> sunion(List<String> setIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(_Cmd.SUNION, setIds));

  Future<List<List<int>>> sdiff(String fromSetId, List<String> withSetIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(_Cmd.SDIFF, $(withSetIds).insert(0, fromSetId)));

  Future<List<int>> srandmember(String setId) => connection.sendExpectData([_Cmd.SRANDMEMBER, RedisClient.keyBytes(setId)]);


  /// LIST
  /// ====

  Future<List<List<int>>> lrange(String listId, int startingFrom, int endingAt) => connection.sendExpectMultiData([_Cmd.LRANGE, RedisClient.keyBytes(listId), toBytes(startingFrom), toBytes(endingAt)]);

  Future<int> lpush(String listId, List<int> value) => connection.sendExpectInt([_Cmd.LPUSH, RedisClient.keyBytes(listId), value]);

  Future<int> mlpush(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(_Cmd.LPUSH, listId, values));

  Future<int> lpushx(String listId, List<int> value) => connection.sendExpectInt([_Cmd.LPUSHX, RedisClient.keyBytes(listId), value]);

  Future<int> mlpushx(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(_Cmd.LPUSHX, listId, values));

  Future<int> rpush(String listId, List<int> value) => connection.sendExpectInt([_Cmd.RPUSH, RedisClient.keyBytes(listId), value]);

  Future<int> mrpush(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(_Cmd.RPUSH, listId, values));

  Future<int> rpushx(String listId, List<int> value) => connection.sendExpectInt([_Cmd.RPUSHX, RedisClient.keyBytes(listId), value]);

  Future<int> mrpushx(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(_Cmd.RPUSHX, listId, values));

  Future<int> lrem(String listId, int removeNoOfMatches, List<int> value) => connection.sendExpectInt([_Cmd.LREM, RedisClient.keyBytes(listId), toBytes(removeNoOfMatches), value]);

  Future<List<int>> lindex(String listId, int listIndex) => connection.sendExpectData([_Cmd.LINDEX, RedisClient.keyBytes(listId), toBytes(listIndex)]);

  Future lset(String listId, int listIndex, List<int> value) => connection.sendExpectSuccess([_Cmd.LSET, RedisClient.keyBytes(listId), toBytes(listIndex), value]);

  Future<List<int>> lpop(String listId) => connection.sendExpectData([_Cmd.LPOP, RedisClient.keyBytes(listId)]);

  Future<List<int>> rpop(String listId) => connection.sendExpectData([_Cmd.RPOP, RedisClient.keyBytes(listId)]);

  Future<List<int>> rpoplpush(String fromListId, String toListId) => connection.sendExpectData([_Cmd.RPOPLPUSH, RedisClient.keyBytes(fromListId), RedisClient.keyBytes(toListId)]);



  /// SORTED SETS
  /// ===========

  Future<int> zadd(String setId, num score, List<int> value) => connection.sendExpectInt([_Cmd.ZADD, RedisClient.keyBytes(setId), toBytes(score), value]);

  Future<int> zmadd(String setId, List<List<int>> scoresAndValues) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(_Cmd.ZADD, setId, scoresAndValues));

  Future<int> zrem(String setId, List<int> value) =>
      connection.sendExpectInt([_Cmd.ZREM, RedisClient.keyBytes(setId), value]);

  Future<int> zmrem(String setId, List<List<int>> values) =>
      connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(_Cmd.ZREM, setId, values));

  Future<double> zincrby(String setId, num incrBy, List<int> value) =>
      connection.sendExpectDouble([_Cmd.ZINCRBY, RedisClient.keyBytes(setId), toBytes(incrBy), value]);

  Future<int> zrank(String setId, List<int> value) => connection.sendExpectInt([_Cmd.ZRANK, RedisClient.keyBytes(setId), value]);

  Future<int> zrevrank(String setId, List<int> value) => connection.sendExpectInt([_Cmd.ZREVRANK, RedisClient.keyBytes(setId), value]);


  /// Helper function
  Future<List<List<int>>> _zrange(List<int> cmdBytes, String setId, int min, int max, {bool withScores: false}){
    List<List<int>> cmdWithArgs = [cmdBytes, RedisClient.keyBytes(setId), toBytes(min), toBytes(max)];
    if (withScores) cmdWithArgs.add(_Cmd.WITHSCORES);
    return connection.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrange(String setId, int min, int max) => _zrange(_Cmd.ZRANGE, setId, min, max);

  Future<List<List<int>>> zrangeWithScores(String setId, int min, int max) => _zrange(_Cmd.ZRANGE, setId, min, max, withScores:true);

  Future<List<List<int>>> zrevrange(String setId, int min, int max) => _zrange(_Cmd.ZREVRANGE, setId, min, max);

  Future<List<List<int>>> zrevrangeWithScores(String setId, int min, int max) => _zrange(_Cmd.ZREVRANGE, setId, min, max, withScores:true);


  /// Helper function
  Future<List<List<int>>> _zrangeByScore(List<int> cmdBytes, String setId, num min, num max, [int skip, int take, bool withScores=false]){
    List<List<int>> cmdWithArgs = [cmdBytes, RedisClient.keyBytes(setId), toBytes(min), toBytes(max)];
    if (skip != null || take != null){
      cmdWithArgs.add(_Cmd.LIMIT);
      cmdWithArgs.add(toBytes(skip == null ? 0 : skip));
      cmdWithArgs.add(toBytes(take == null ? 0 : take));
    }
    if (withScores) cmdWithArgs.add(_Cmd.WITHSCORES);
    return connection.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrangebyscore(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(_Cmd.ZRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(_Cmd.ZRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(_Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(_Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<double> zscore(String setId, List<int> value) => connection.sendExpectDouble([_Cmd.ZSCORE, RedisClient.keyBytes(setId), value]);



  /// HASH
  /// ====

  Future<bool> hset(String hashId, String key, List<int> value) => connection.sendExpectIntSuccess([_Cmd.HSET, RedisClient.keyBytes(hashId), RedisClient.keyBytes(key), value]);

  Future<bool> hsetnx(String hashId, String key, List<int> value) => connection.sendExpectIntSuccess([_Cmd.HSETNX, RedisClient.keyBytes(hashId), RedisClient.keyBytes(key), value]);

  Future hmset(String hashId, List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? new Future(null) : connection.sendExpectSuccess(_CommandUtils.mergeParamsWithKeysAndValues([_Cmd.HMSET, RedisClient.keyBytes(hashId)], keys, values));

  Future<List<int>> hget(String hashId, String key) => connection.sendExpectData([_Cmd.HGET, RedisClient.keyBytes(hashId), RedisClient.keyBytes(key)]);

  Future<List<List<int>>> hmget(String hashId, List<String> keys) => keys.isEmpty ? new Future([ ]) : connection.sendExpectMultiData(_CommandUtils.mergeCommandWithKeyAndStringArgs(_Cmd.HMGET, hashId, keys));

  Future<List<List<int>>> hvals(String hashId) => connection.sendExpectMultiData([_Cmd.HVALS, RedisClient.keyBytes(hashId)]);

  Future<List<List<int>>> hgetall(String hashId) => connection.sendExpectMultiData([_Cmd.HGETALL, RedisClient.keyBytes(hashId)]);

}
