part of redis_client;



/// This is the class that holds the raw commands that access redis.
///
/// That means that it has to be called with binary data, and returns binary
/// data as well (instead of providing Strings or other dart objects).
///
/// You should rarely need to access this functions. If you do, you'll probably
/// want to get the object from [RedisClient.raw].
///
/// [RedisClient] creates an instance of this class in the constructor, and
/// provides high level methods for those methods.
class RawRedisCommands {

  RedisClient client;

  RedisConnection connection;

  RawRedisCommands(RedisClient this.client) : connection = this.client.connection;

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

  Future<int> get lastsave => connection.sendExpectInt([Cmd.LASTSAVE]);

  Future<List<int>> echo(List<int> value) => connection.sendExpectData([Cmd.ECHO, value]);


  /// Keys
  /// ====

  Future<List<int>> get(String key) => connection.sendExpectData([Cmd.GET, RedisClient.keyBytes(key)]);

  Future<List<List<int>>> mget(List<String> keys) => keys.isEmpty ? new Future([ ]) : connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(Cmd.MGET, keys));

  Future<List<int>> getset(String key, List<int> value) => connection.sendExpectData([Cmd.GETSET, RedisClient.keyBytes(key), value]);

  Future set(String key, List<int> value) => connection.sendExpectSuccess([Cmd.SET, RedisClient.keyBytes(key), value]);

  Future setex(String key, int expireInSecs, List<int> value) => connection.sendExpectSuccess([Cmd.SETEX, RedisClient.keyBytes(key), toBytes(expireInSecs), value]);

  Future psetex(String key, int expireInMs, List<int> value) => connection.sendExpectSuccess([Cmd.PSETEX, RedisClient.keyBytes(key), toBytes(expireInMs), value]);

  Future mset(List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? new Future(null) : connection.sendExpectSuccess(_CommandUtils.mergeCommandWithKeysAndValues(Cmd.MSET, keys, values));

  Future<bool> msetnx(List<List<int>> keys, List<List<int>> values) => connection.sendExpectIntSuccess(_CommandUtils.mergeCommandWithKeysAndValues(Cmd.MSETNX, keys, values));

  Future<int> append(String key, List<int> value) => connection.sendExpectInt([Cmd.APPEND, RedisClient.keyBytes(key), value]);

  Future<List<int>> substr(String key, int fromIndex, int toIndex) => connection.sendExpectData([Cmd.SUBSTR, RedisClient.keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> getrange(String key, int fromIndex, int toIndex) => connection.sendExpectData([Cmd.GETRANGE, RedisClient.keyBytes(key), toBytes(fromIndex), toBytes(toIndex)]);

  Future<List<int>> setrange(String key, int offset, List<int> value) => connection.sendExpectData([Cmd.SETRANGE, RedisClient.keyBytes(key), toBytes(offset), value]);

  Future<List<int>> randomkey() => connection.sendExpectData([Cmd.RANDOMKEY]);

  Future<bool> expireat(String key, int unixTimeSecs) => connection.sendExpectIntSuccess([Cmd.EXPIREAT, RedisClient.keyBytes(key), toBytes(unixTimeSecs)]);

  Future<bool> pexpireat(String key, int unixTimeMs) => connection.sendExpectIntSuccess([Cmd.PEXPIREAT, RedisClient.keyBytes(key), toBytes(unixTimeMs)]);


  /// SET
  /// ===

  Future<List<List<int>>> smembers(String setId) => connection.sendExpectMultiData([Cmd.SMEMBERS, RedisClient.keyBytes(setId)]);

  Future<int> sadd(String setId, List<int> value) => connection.sendExpectInt([Cmd.SADD, RedisClient.keyBytes(setId), value]);

  Future<int> smadd(String setId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(Cmd.SADD, setId, values));

  Future<int> srem(String setId, List<int> value) => connection.sendExpectInt([Cmd.SREM, RedisClient.keyBytes(setId), value]);

  Future<List<int>> spop(String setId) => connection.sendExpectData([Cmd.SPOP, RedisClient.keyBytes(setId)]);

  Future<bool> smove(String fromSetId, String toSetId, List<int> value) => connection.sendExpectIntSuccess([Cmd.SMOVE, RedisClient.keyBytes(fromSetId), RedisClient.keyBytes(toSetId), value]);

  Future<bool> sismember(String setId, List<int> value) => connection.sendExpectIntSuccess([Cmd.SISMEMBER, RedisClient.keyBytes(setId), value]);

  Future<List<List<int>>> sinter(List<String> setIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(Cmd.SINTER, setIds));

  Future<int> sinterstore(String intoSetId, List<String> setIds) => connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(Cmd.SINTERSTORE, $(setIds).insert(0, intoSetId)));

  Future<List<List<int>>> sunion(List<String> setIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(Cmd.SUNION, setIds));

  Future<List<List<int>>> sdiff(String fromSetId, List<String> withSetIds) => connection.sendExpectMultiData(_CommandUtils.mergeCommandWithStringArgs(Cmd.SDIFF, $(withSetIds).insert(0, fromSetId)));

  Future<List<int>> srandmember(String setId) => connection.sendExpectData([Cmd.SRANDMEMBER, RedisClient.keyBytes(setId)]);


  /// LIST
  /// ====


  Future<List<List<int>>> lrange(String listId, int startingFrom, int endingAt) => connection.sendExpectMultiData([Cmd.LRANGE, RedisClient.keyBytes(listId), toBytes(startingFrom), toBytes(endingAt)]);

  Future<int> lpush(String listId, List<int> value) => connection.sendExpectInt([Cmd.LPUSH, RedisClient.keyBytes(listId), value]);

  Future<int> mlpush(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(Cmd.LPUSH, listId, values));

  Future<int> lpushx(String listId, List<int> value) => connection.sendExpectInt([Cmd.LPUSHX, RedisClient.keyBytes(listId), value]);

  Future<int> mlpushx(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(Cmd.LPUSHX, listId, values));

  Future<int> rpush(String listId, List<int> value) => connection.sendExpectInt([Cmd.RPUSH, RedisClient.keyBytes(listId), value]);

  Future<int> mrpush(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(Cmd.RPUSH, listId, values));

  Future<int> rpushx(String listId, List<int> value) => connection.sendExpectInt([Cmd.RPUSHX, RedisClient.keyBytes(listId), value]);

  Future<int> mrpushx(String listId, List<List<int>> values) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(Cmd.RPUSHX, listId, values));

  Future<int> lrem(String listId, int removeNoOfMatches, List<int> value) => connection.sendExpectInt([Cmd.LREM, RedisClient.keyBytes(listId), toBytes(removeNoOfMatches), value]);

  Future<List<int>> lindex(String listId, int listIndex) => connection.sendExpectData([Cmd.LINDEX, RedisClient.keyBytes(listId), toBytes(listIndex)]);

  Future lset(String listId, int listIndex, List<int> value) => connection.sendExpectSuccess([Cmd.LSET, RedisClient.keyBytes(listId), toBytes(listIndex), value]);

  Future<List<int>> lpop(String listId) => connection.sendExpectData([Cmd.LPOP, RedisClient.keyBytes(listId)]);

  Future<List<int>> rpop(String listId) => connection.sendExpectData([Cmd.RPOP, RedisClient.keyBytes(listId)]);

  Future<List<int>> rpoplpush(String fromListId, String toListId) => connection.sendExpectData([Cmd.RPOPLPUSH, RedisClient.keyBytes(fromListId), RedisClient.keyBytes(toListId)]);



  /// SORTED SETS
  /// ===========

  Future<int> zadd(String setId, num score, List<int> value) => connection.sendExpectInt([Cmd.ZADD, RedisClient.keyBytes(setId), toBytes(score), value]);

  Future<int> zmadd(String setId, List<List<int>> scoresAndValues) => connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(Cmd.ZADD, setId, scoresAndValues));

  Future<int> zrem(String setId, List<int> value) =>
      connection.sendExpectInt([Cmd.ZREM, RedisClient.keyBytes(setId), value]);

  Future<int> zmrem(String setId, List<List<int>> values) =>
      connection.sendExpectInt(_CommandUtils.mergeCommandWithKeyAndArgs(Cmd.ZREM, setId, values));

  Future<double> zincrby(String setId, num incrBy, List<int> value) =>
      connection.sendExpectDouble([Cmd.ZINCRBY, RedisClient.keyBytes(setId), toBytes(incrBy), value]);

  Future<int> zrank(String setId, List<int> value) => connection.sendExpectInt([Cmd.ZRANK, RedisClient.keyBytes(setId), value]);

  Future<int> zrevrank(String setId, List<int> value) => connection.sendExpectInt([Cmd.ZREVRANK, RedisClient.keyBytes(setId), value]);


  /// Helper function
  Future<List<List<int>>> _zrange(List<int> cmdBytes, String setId, int min, int max, {bool withScores: false}){
    List<List<int>> cmdWithArgs = [cmdBytes, RedisClient.keyBytes(setId), toBytes(min), toBytes(max)];
    if (withScores) cmdWithArgs.add(Cmd.WITHSCORES);
    return connection.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrange(String setId, int min, int max) => _zrange(Cmd.ZRANGE, setId, min, max);

  Future<List<List<int>>> zrangeWithScores(String setId, int min, int max) => _zrange(Cmd.ZRANGE, setId, min, max, withScores:true);

  Future<List<List<int>>> zrevrange(String setId, int min, int max) => _zrange(Cmd.ZREVRANGE, setId, min, max);

  Future<List<List<int>>> zrevrangeWithScores(String setId, int min, int max) => _zrange(Cmd.ZREVRANGE, setId, min, max, withScores:true);


  /// Helper function
  Future<List<List<int>>> _zrangeByScore(List<int> cmdBytes, String setId, num min, num max, [int skip, int take, bool withScores=false]){
    List<List<int>> cmdWithArgs = [cmdBytes, RedisClient.keyBytes(setId), toBytes(min), toBytes(max)];
    if (skip != null || take != null){
      cmdWithArgs.add(Cmd.LIMIT);
      cmdWithArgs.add(toBytes(skip == null ? 0 : skip));
      cmdWithArgs.add(toBytes(take == null ? 0 : take));
    }
    if (withScores) cmdWithArgs.add(Cmd.WITHSCORES);
    return connection.sendExpectMultiData(cmdWithArgs);
  }

  Future<List<List<int>>> zrangebyscore(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(Cmd.ZRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(Cmd.ZRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take);

  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => _zrangeByScore(Cmd.ZREVRANGEBYSCORE, setId, min, max, skip, take, true);

  Future<double> zscore(String setId, List<int> value) => connection.sendExpectDouble([Cmd.ZSCORE, RedisClient.keyBytes(setId), value]);



  /// HASH
  /// ====

  Future<bool> hset(String hashId, String key, List<int> value) => connection.sendExpectIntSuccess([Cmd.HSET, RedisClient.keyBytes(hashId), RedisClient.keyBytes(key), value]);

  Future<bool> hsetnx(String hashId, String key, List<int> value) => connection.sendExpectIntSuccess([Cmd.HSETNX, RedisClient.keyBytes(hashId), RedisClient.keyBytes(key), value]);

  Future hmset(String hashId, List<List<int>> keys, List<List<int>> values) => keys.isEmpty ? new Future(null) : connection.sendExpectSuccess(_CommandUtils.mergeParamsWithKeysAndValues([Cmd.HMSET, RedisClient.keyBytes(hashId)], keys, values));

  Future<List<int>> hget(String hashId, String key) => connection.sendExpectData([Cmd.HGET, RedisClient.keyBytes(hashId), RedisClient.keyBytes(key)]);

  Future<List<List<int>>> hmget(String hashId, List<String> keys) => keys.isEmpty ? new Future([ ]) : connection.sendExpectMultiData(_CommandUtils.mergeCommandWithKeyAndStringArgs(Cmd.HMGET, hashId, keys));

  Future<List<List<int>>> hvals(String hashId) => connection.sendExpectMultiData([Cmd.HVALS, RedisClient.keyBytes(hashId)]);

  Future<List<List<int>>> hgetall(String hashId) => connection.sendExpectMultiData([Cmd.HGETALL, RedisClient.keyBytes(hashId)]);

}
