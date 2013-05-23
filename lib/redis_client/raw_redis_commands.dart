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

  Future<int> get lastsave => connection.sendExpectInt([RedisCommand.LASTSAVE]);

  Future<List<int>> echo(List<int> value) => connection.sendExpectData([RedisCommand.ECHO, value]);


  /// Keys
  /// ====

//  Future<List<int>> get(String key) => connection.rawSend([ RedisCommand.GET, RedisClient._keyBytes(key) ]).receiveBulkData();

//  Future<List<List<int>>> mget(List<String> keys) => keys.isEmpty ? new Future([ ]) : connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.MGET, keys));

//  Future<List<int>> getset(String key, List<int> value) => connection.rawSend([RedisCommand.GETSET, RedisClient._keyBytes(key), value]).receiveBulkData();

//  Future set(String key, List<int> value) => connection.rawSend([ RedisCommand.SET, RedisClient._keyBytes(key), value ]).receiveStatus("OK");

  Future setex(String key, int expireInSecs, List<int> value) => connection.sendExpectSuccess([RedisCommand.SETEX, RedisClient._keyBytes(key), toBytes(expireInSecs), value]);

  Future psetex(String key, int expireInMs, List<int> value) => connection.sendExpectSuccess([RedisCommand.PSETEX, RedisClient._keyBytes(key), toBytes(expireInMs), value]);

  Future mset(List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? new Future(null) : connection.sendExpectSuccess(_CommandUtils.mergeCommandWithKeysAndValues(RedisCommand.MSET, keys, values));

  Future<bool> msetnx(List<List<int>> keys, List<List<int>> values) => connection.sendExpectIntSuccess(_CommandUtils.mergeCommandWithKeysAndValues(RedisCommand.MSETNX, keys, values));

  Future<int> append(String key, List<int> value) => connection.sendExpectInt([RedisCommand.APPEND, RedisClient._keyBytes(key), value]);

  Future<List<int>> substr(String key, int fromIndex, int toIndex) => connection.sendExpectData([RedisCommand.SUBSTR, RedisClient._keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> getrange(String key, int fromIndex, int toIndex) => connection.sendExpectData([RedisCommand.GETRANGE, RedisClient._keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> setrange(String key, int offset, List<int> value) => connection.sendExpectData([RedisCommand.SETRANGE, RedisClient._keyBytes(key), toBytes(offset), value]);

  Future<List<int>> randomkey() => connection.sendExpectData([RedisCommand.RANDOMKEY]);

  Future<bool> expireat(String key, int unixTimeSecs) => connection.sendExpectIntSuccess([RedisCommand.EXPIREAT, RedisClient._keyBytes(key), toBytes(unixTimeSecs)]);

  Future<bool> pexpireat(String key, int unixTimeMs) => connection.sendExpectIntSuccess([RedisCommand.PEXPIREAT, RedisClient._keyBytes(key), toBytes(unixTimeMs)]);


  /// SET
  /// ===

  Future<List<List<int>>> smembers(String setId) => connection.sendExpectMultiData([RedisCommand.SMEMBERS, RedisClient._keyBytes(setId)]);

  Future<int> sadd(String setId, List<int> value) => connection.sendExpectInt([RedisCommand.SADD, RedisClient._keyBytes(setId), value]);

  Future<int> smadd(String setId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(RedisCommand.SADD, setId, values));

  Future<int> srem(String setId, List<int> value) => connection.sendExpectInt([RedisCommand.SREM, RedisClient._keyBytes(setId), value]);

  Future<List<int>> spop(String setId) => connection.sendExpectData([RedisCommand.SPOP, RedisClient._keyBytes(setId)]);

  Future<bool> smove(String fromSetId, String toSetId, List<int> value) => connection.sendExpectIntSuccess([RedisCommand.SMOVE, RedisClient._keyBytes(fromSetId), RedisClient._keyBytes(toSetId), value]);

  Future<bool> sismember(String setId, List<int> value) => connection.sendExpectIntSuccess([RedisCommand.SISMEMBER, RedisClient._keyBytes(setId), value]);

  Future<List<List<int>>> sinter(List<String> setIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SINTER, setIds));

  Future<int> sinterstore(String intoSetId, List<String> setIds) => connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SINTERSTORE, $(setIds).insert(0, intoSetId)));

  Future<List<List<int>>> sunion(List<String> setIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SUNION, setIds));

  Future<List<List<int>>> sdiff(String fromSetId, List<String> withSetIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SDIFF, $(withSetIds).insert(0, fromSetId)));

  Future<List<int>> srandmember(String setId) => connection.sendExpectData([RedisCommand.SRANDMEMBER, RedisClient._keyBytes(setId)]);


  /// LIST
  /// ====

  Future<List<List<int>>> lrange(String listId, int startingFrom, int endingAt) => connection.sendExpectMultiData([RedisCommand.LRANGE, RedisClient._keyBytes(listId), toBytes(startingFrom), toBytes(endingAt)]);

  Future<int> lpush(String listId, List<int> value) => connection.sendExpectInt([RedisCommand.LPUSH, RedisClient._keyBytes(listId), value]);

  Future<int> mlpush(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(RedisCommand.LPUSH, listId, values));

  Future<int> lpushx(String listId, List<int> value) => connection.sendExpectInt([RedisCommand.LPUSHX, RedisClient._keyBytes(listId), value]);

  Future<int> mlpushx(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(RedisCommand.LPUSHX, listId, values));

  Future<int> rpush(String listId, List<int> value) => connection.sendExpectInt([RedisCommand.RPUSH, RedisClient._keyBytes(listId), value]);

  Future<int> mrpush(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(RedisCommand.RPUSH, listId, values));

  Future<int> rpushx(String listId, List<int> value) => connection.sendExpectInt([RedisCommand.RPUSHX, RedisClient._keyBytes(listId), value]);

  Future<int> mrpushx(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(RedisCommand.RPUSHX, listId, values));

  Future<int> lrem(String listId, int removeNoOfMatches, List<int> value) => connection.sendExpectInt([RedisCommand.LREM, RedisClient._keyBytes(listId), toBytes(removeNoOfMatches), value]);

  Future<List<int>> lindex(String listId, int listIndex) => connection.sendExpectData([RedisCommand.LINDEX, RedisClient._keyBytes(listId), toBytes(listIndex)]);

  Future lset(String listId, int listIndex, List<int> value) => connection.sendExpectSuccess([RedisCommand.LSET, RedisClient._keyBytes(listId), toBytes(listIndex), value]);

  Future<List<int>> lpop(String listId) => connection.sendExpectData([RedisCommand.LPOP, RedisClient._keyBytes(listId)]);

  Future<List<int>> rpop(String listId) => connection.sendExpectData([RedisCommand.RPOP, RedisClient._keyBytes(listId)]);

  Future<List<int>> rpoplpush(String fromListId, String toListId) => connection.sendExpectData([RedisCommand.RPOPLPUSH, RedisClient._keyBytes(fromListId), RedisClient._keyBytes(toListId)]);



  /// SORTED SETS
  /// ===========

  Future<int> zadd(String setId, num score, List<int> value) => connection.sendExpectInt([RedisCommand.ZADD, RedisClient._keyBytes(setId), toBytes(score), value]);

  Future<int> zmadd(String setId, List<List<int>> scoresAndValues) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(RedisCommand.ZADD, setId, scoresAndValues));

  Future<int> zrem(String setId, List<int> value) =>
      connection.sendExpectInt([RedisCommand.ZREM, RedisClient._keyBytes(setId), value]);

  Future<int> zmrem(String setId, List<List<int>> values) =>
      connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(RedisCommand.ZREM, setId, values));

  Future<double> zincrby(String setId, num incrBy, List<int> value) =>
      connection.sendExpectDouble([RedisCommand.ZINCRBY, RedisClient._keyBytes(setId), toBytes(incrBy), value]);

  Future<int> zrank(String setId, List<int> value) => connection.sendExpectInt([RedisCommand.ZRANK, RedisClient._keyBytes(setId), value]);

  Future<int> zrevrank(String setId, List<int> value) => connection.sendExpectInt([RedisCommand.ZREVRANK, RedisClient._keyBytes(setId), value]);


  /// Helper function
  Future<List<List<int>>> _zrange(List<int> cmdBytes, String setId, int min, int max, {bool withScores: false}){
    List<List<int>> cmdWithArgs = [cmdBytes, RedisClient._keyBytes(setId), toBytes(min), toBytes(max)];
    if (withScores) cmdWithArgs.add(RedisCommand.WITHSCORES);
    return connection.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrange(String setId, int min, int max) => _zrange(RedisCommand.ZRANGE, setId, min, max);

  Future<List<List<int>>> zrangeWithScores(String setId, int min, int max) => _zrange(RedisCommand.ZRANGE, setId, min, max, withScores:true);

  Future<List<List<int>>> zrevrange(String setId, int min, int max) => _zrange(RedisCommand.ZREVRANGE, setId, min, max);

  Future<List<List<int>>> zrevrangeWithScores(String setId, int min, int max) => _zrange(RedisCommand.ZREVRANGE, setId, min, max, withScores:true);


  /// Helper function
  Future<List<List<int>>> _zrangeByScore(List<int> cmdBytes, String setId, num min, num max, [int skip, int take, bool withScores=false]){
    List<List<int>> cmdWithArgs = [cmdBytes, RedisClient._keyBytes(setId), toBytes(min), toBytes(max)];
    if (skip != null || take != null){
      cmdWithArgs.add(RedisCommand.LIMIT);
      cmdWithArgs.add(toBytes(skip == null ? 0 : skip));
      cmdWithArgs.add(toBytes(take == null ? 0 : take));
    }
    if (withScores) cmdWithArgs.add(RedisCommand.WITHSCORES);
    return connection.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrangebyscore(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(RedisCommand.ZRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(RedisCommand.ZRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(RedisCommand.ZREVRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(RedisCommand.ZREVRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<double> zscore(String setId, List<int> value) => connection.sendExpectDouble([RedisCommand.ZSCORE, RedisClient._keyBytes(setId), value]);



  /// HASH
  /// ====

  Future<bool> hset(String hashId, String key, List<int> value) => connection.sendExpectIntSuccess([RedisCommand.HSET, RedisClient._keyBytes(hashId), RedisClient._keyBytes(key), value]);

  Future<bool> hsetnx(String hashId, String key, List<int> value) => connection.sendExpectIntSuccess([RedisCommand.HSETNX, RedisClient._keyBytes(hashId), RedisClient._keyBytes(key), value]);

  Future hmset(String hashId, List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? new Future(null) : connection.sendExpectSuccess(_CommandUtils.mergeParamsWithKeysAndValues([RedisCommand.HMSET, RedisClient._keyBytes(hashId)], keys, values));

  Future<List<int>> hget(String hashId, String key) => connection.sendExpectData([RedisCommand.HGET, RedisClient._keyBytes(hashId), RedisClient._keyBytes(key)]);

  Future<List<List<int>>> hmget(String hashId, List<String> keys) => keys.isEmpty ? new Future([ ]) : connection.sendExpectMultiData(_CommandUtils.mergeCommandWithKeyAndStringArgs(RedisCommand.HMGET, hashId, keys));

  Future<List<List<int>>> hvals(String hashId) => connection.sendExpectMultiData([RedisCommand.HVALS, RedisClient._keyBytes(hashId)]);

  Future<List<List<int>>> hgetall(String hashId) => connection.sendExpectMultiData([RedisCommand.HGETALL, RedisClient._keyBytes(hashId)]);

}
