part of redis_client;



/**
 * The [RedisClient] is a high level class to access your redis server.
 *
 * You create a [RedisClient] like this:
 *
 *     var connectionString = "localhost:6379";
 *     RedisClient.connect(connectionString)
 *         .then((RedisClient client) {
 *           // Use your client here. Eg.:
 *           client.set("test", "value").then((_) => print("success"));
 *         });
 *
 * [RedisClient] creates a [RedisConnection] internally, and just forwards the
 * `connectionString` to it. So please refer to the [RedisConnection]
 * doc for a list of valid connection strings.
 *
 * If you need to access the lower level functions for some reason, you can
 * access the [RawRedisCommands] with [RedisClient.raw].
 *
 * To see how the binary redis socket works and detailed list of available
 * commands, please visit [redis documentation](http://redis.io/commands).
 */
class RedisClient {

  String connectionString;

  /// The [RedisConnection] used to communicate with the Redis server.
  RedisConnection connection;

  /// The future that gets resolved as soon as the connection is available.
  Future<RedisConnection> connectionFuture;


  /// Instance of [RawRedisCommands] which [RedisClient] wraps to provide a more
  /// high-level API.
  RawRedisCommands raw;


  /// Used to serialize and deserialize the values stored inside Redis.
  RedisSerializer serializer = new RedisSerializer();




  /// Returns a [Future] for a [RedisClient].
  static Future<RedisClient> connect([ String connectionString ]) {
    var redisClient = new RedisClient._(connectionString);
    return redisClient.connectionFuture.then((_) => redisClient);
  }


  /// Creates the [RedisConnection] and an instance of [RawRedisCommands].
  RedisClient._(String this.connectionString) {
    connectionFuture = RedisConnection.connect(connectionString)
        .then((conn) => connection = conn);

    raw = new RawRedisCommands(this);
  }





  _Tuple<List<List<int>>> keyValueBytes(Map map) {
    List<List<int>> keys = new List<List<int>>();
    List<List<int>> values = new List<List<int>>();
    for(String key in map.keys) {
      keys.add(key.runes);
      values.add(serializer.serialize(map[key]));
    }
    return new _Tuple(keys,values);
  }



  /// Converts bytes to a Map
  Map<String,Object> toMap(List<List<int>> multiData) {
    Map<String,Object> map = new Map<String,Object>();
    for (int i = 0; i < multiData.length; i += 2) {
      String key = toStr(multiData[i]);
      map[key] = serializer.deserialize(multiData[i + 1]);
    }
    return map;
  }


  Map<Object,double> toScoreMap(List<List<int>> multiData) {
    Map<Object,double> map = new Map<String,double>();
    for (int i = 0; i < multiData.length; i += 2) {
      Object key = serializer.deserialize(multiData[i]);
      map[key] = double.parse(toStr(multiData[i + 1]));
    }
    return map;
  }

  /// Converts a list of bytes to a string
  static String toStr(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes);


  /// Converts a String to a list of UTF8 bytes.
  static List<int> keyBytes(String key) {
    if (key == null || key.isEmpty) throw new Exception("key is null");
    return encodeUtf8(key);
  }

  /// Wrapper for [RedisConnection.db]
  int get db => connection.db;

  Map get stats => connection.stats;

  Future close() => connection.close();



  /// Admin
  /// =====


  /// Select a database.
  ///
  /// Wrapper for [RedisConnection.select]
  Future select(int db) => connection.select(db);

  Future<int> get dbsize => connection.sendExpectInt([Cmd.DBSIZE]);

  /// Wrapper for [RawRedisCommands.lastsave].
  Future<DateTime> get lastsave => raw.lastsave.then((int unixTs) => new DateTime.fromMillisecondsSinceEpoch(unixTs * 1000, isUtc:true));

  Future flushdb() => connection.sendExpectSuccess([Cmd.FLUSHDB]);

  Future flushall() => connection.sendExpectSuccess([Cmd.FLUSHALL]);

  Future save() => connection.sendExpectSuccess([Cmd.SAVE]);

  Future bgsave() => connection.sendExpectSuccess([Cmd.BGSAVE]);

  Future shutdown() => connection.sendExpectSuccess([Cmd.SHUTDOWN]);

  Future bgrewriteaof() => connection.sendExpectSuccess([Cmd.BGREWRITEAOF]);

  Future quit() => connection.sendExpectSuccess([Cmd.QUIT]);

  Future<Map> get info{
    return connection.sendExpectString([Cmd.INFO])
        .then((String lines) {
           Map info = {};
           for(String line in lines.split("\r\n")) {
             List<String> kvp = $(line).splitOnFirst(":");
             info[kvp[0]] = kvp.length == 2 ? kvp[1] : null;
           }
           return info;
        });
  }

  Future<bool> ping() => connection.sendExpectCode([Cmd.PING]).then((String r) => r == "PONG");

  /// Wrapper for [RawRedisCommands.echo].
  Future<Object> echo(Object value) => raw.echo(serializer.serialize(value)).then(serializer.deserialize);


  /// Keys
  /// ====

  Future<String> type(String key) => connection.sendExpectCode([Cmd.TYPE, keyBytes(key)]);

  Future<List<String>> keys(String pattern) => connection.sendExpectMultiData([Cmd.KEYS, keyBytes(pattern)]).then((x) => x.map((k) => new String.fromCharCodes(k)));

  /// Wrapper for [RawRedisCommands.get].
  Future<Object> get(String key) => raw.get(key).then((replyData) => serializer.deserialize(replyData));

  /// Wrapper for [RawRedisCommands.mget].
  Future<List<Object>> mget(List<String> keys) => raw.mget(keys).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.getset].
  Future<Object> getset(String key, Object value) => raw.getset(key, serializer.serialize(value)).then(serializer.deserialize);

  /// Wrapper for [RawRedisCommands.set].
  Future set(String key, Object value) => raw.set(key, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.setex].
  Future setex(String key, int expireInSecs, Object value) => raw.setex(key, expireInSecs, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.psetex].
  Future psetex(String key, int expireInMs, Object value) => raw.psetex(key, expireInMs, serializer.serialize(value));

  Future<bool> persist(String key) => connection.sendExpectIntSuccess([Cmd.PERSIST, keyBytes(key)]);

   /// Wrapper for [RawRedisCommands.mset].
  Future mset(Map map) {
    _Tuple<List<List<int>>> kvps = keyValueBytes(map, serializer);
    return raw.mset(kvps.item1, kvps.item2);
  }

  /// Wrapper for [RawRedisCommands.msetnx].
  Future<bool> msetnx(Map map) {
    _Tuple<List<List<int>>> kvps = keyValueBytes(map, serializer);
    return raw.msetnx(kvps.item1, kvps.item2);
  }

  Future<bool> exists(String key) => connection.sendExpectIntSuccess([Cmd.EXISTS, keyBytes(key)]);

  Future<int> del(String key) => connection.sendExpectInt([Cmd.DEL, keyBytes(key)]);

  Future<int> mdel(List<String> keys) => keys.isEmpty ? new Future(null) : connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(Cmd.DEL, keys));

  Future<int> incr(String key) => connection.sendExpectInt([Cmd.INCR, keyBytes(key)]);

  Future<int> incrby(String key, int count) => connection.sendExpectInt([Cmd.INCRBY, keyBytes(key), serializer.serialize(count)]);

  Future<double> incrbyfloat(String key, double count) => connection.sendExpectDouble([Cmd.INCRBYFLOAT, keyBytes(key), serializer.serialize(count)]);

  Future<int> decr(String key) => connection.sendExpectInt([Cmd.DECR, keyBytes(key)]);

  Future<int> decrby(String key, int count) => connection.sendExpectInt([Cmd.DECRBY, keyBytes(key), serializer.serialize(count)]);

  Future<int> strlen(String key) => connection.sendExpectInt([Cmd.STRLEN, keyBytes(key)]);

  /// Wrapper for [RawRedisCommands.append].
  Future<int> append(String key, String value) => raw.append(key, serializer.serialize(value));


  /// Wrapper for [RawRedisCommands.substr].
  Future<String> substr(String key, int fromIndex, int toIndex) => raw.substr(key, fromIndex, toIndex).then(toStr);

  /// Wrapper for [RawRedisCommands.getrange].
  Future<String> getrange(String key, int fromIndex, int toIndex) => raw.getrange(key, fromIndex, toIndex).then(toStr);

  /// Wrapper for [RawRedisCommands.setrange].
  Future<String> setrange(String key, int offset, String value) => raw.setrange(key, offset, serializer.serialize(value)).then(toStr);

  Future<int> getbit(String key, int offset) => connection.sendExpectInt([Cmd.GETBIT, keyBytes(key), serializer.serialize(offset)]);

  Future<int> setbit(String key, int offset, int value) => connection.sendExpectInt([Cmd.SETBIT, keyBytes(key), serializer.serialize(offset), serializer.serialize(value)]);

  /// Wrapper for [RawRedisCommands.randomkey].
  Future<String> randomkey() => raw.randomkey().then(toStr);

  Future rename(String oldKey, String newKey) => connection.sendExpectSuccess([Cmd.RENAME, keyBytes(oldKey), keyBytes(newKey)]);

  Future<bool> renamenx(String oldKey, String newKey) => connection.sendExpectIntSuccess([Cmd.RENAMENX, keyBytes(oldKey), keyBytes(newKey)]);

  Future<bool> expire(String key, int expireInSecs) => connection.sendExpectIntSuccess([Cmd.EXPIRE, keyBytes(key), serializer.serialize(expireInSecs)]);

  Future<bool> pexpire(String key, int expireInMs) => connection.sendExpectIntSuccess([Cmd.PEXPIRE, keyBytes(key), serializer.serialize(expireInMs)]);

  /// Wrapper for [RawRedisCommands.expireat].
  Future<bool> expireat(String key, DateTime date) => raw.expireat(key, date.toUtc().millisecondsSinceEpoch ~/ 1000);

  /// Wrapper for [RawRedisCommands.pexpireat].
  Future<bool> pexpireat(String key, DateTime date) => raw.pexpireat(key, date.toUtc().millisecondsSinceEpoch);

  Future<int> ttl(String key) => connection.sendExpectInt([Cmd.TTL, keyBytes(key)]);

  Future<int> pttl(String key) => connection.sendExpectInt([Cmd.PTTL, keyBytes(key)]);



  /// SET
  /// ===

  /// Wrapper for [RawRedisCommands.smembers].
  Future<List<Object>> smembers(String setId) => raw.smembers(setId).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.sadd].
  Future<int> sadd(String setId, Object value) => raw.sadd(setId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.smadd].
  Future<int> smadd(String setId, List<Object> values) => raw.smadd(setId, values.map((x) => serializer.serialize(x)));

  /// Wrapper for [RawRedisCommands.srem].
  Future<int> srem(String setId, Object value) => raw.srem(setId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.spop].
  Future<Object> spop(String setId) => raw.spop(setId).then(serializer.deserialize);

  /// Wrapper for [RawRedisCommands.smove].
  Future<bool> smove(String fromSetId, String toSetId, Object value) => raw.smove(fromSetId, toSetId, serializer.serialize(value));

  Future<int> scard(String setId) => connection.sendExpectInt([Cmd.SCARD, keyBytes(setId)]);

  /// Wrapper for [RawRedisCommands.sismember].
  Future<bool> sismember(String setId, Object value) => raw.sismember(setId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.sinter].
  Future<List<Object>> sinter(List<String> setIds) => raw.sinter(setIds).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.sinterstore].
  Future<int> sinterstore(String intoSetId, List<String> setIds) => raw.sinterstore(intoSetId, setIds);

  /// Wrapper for [RawRedisCommands.sunion].
  Future<List<Object>> sunion(List<String> setIds) => raw.sunion(setIds).then((x) => x.map(serializer.deserialize));

  Future<int> sunionstore(String intoSetId, List<String> setIds) =>
      connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(Cmd.SUNIONSTORE, $(setIds).insert(0, intoSetId)));

  /// Wrapper for [RawRedisCommands.sdiff].
  Future<List<Object>> sdiff(String fromSetId, List<String> withSetIds) => raw.sdiff(fromSetId, withSetIds).then((x) => x.map(serializer.deserialize));

  Future<int> sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds) {
    withSetIds.insert(0, fromSetId);
    withSetIds.insert(0, intoSetId);
    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(Cmd.SDIFFSTORE, withSetIds));
  }

  /// Wrapper for [RawRedisCommands.srandmember].
  Future<Object> srandmember(String setId) => raw.srandmember(setId).then(serializer.deserialize);




  /// SORT SET/LIST
  /// =============

  Future<List<List<int>>> sort(String listOrSetId,
    [String sortPattern, int skip, int take, String getPattern, bool sortAlpha=false, bool sortDesc=false, String storeAtKey]) {

    List<List<int>> cmdWithArgs = [Cmd.SORT, keyBytes(listOrSetId)];

    if (sortPattern != null) {
      cmdWithArgs.add(Cmd.BY);
      cmdWithArgs.add(serializer.serialize(sortPattern));
    }

    if (skip != null || take != null) {
      cmdWithArgs.add(Cmd.LIMIT);
      cmdWithArgs.add(serializer.serialize(skip == null ? 0 : skip));
      cmdWithArgs.add(serializer.serialize(take == null ? 0 : take));
    }

    if (getPattern != null) {
      cmdWithArgs.add(Cmd.GET);
      cmdWithArgs.add(serializer.serialize(getPattern));
    }

    if (sortDesc) cmdWithArgs.add(Cmd.DESC);

    if (sortAlpha) cmdWithArgs.add(Cmd.ALPHA);

    if (storeAtKey != null) {
      cmdWithArgs.add(Cmd.STORE);
      cmdWithArgs.add(serializer.serialize(storeAtKey));
    }

    return connection.sendExpectMultiData(cmdWithArgs);
  }

  //LIST


  /// Wrapper for [RawRedisCommands.lrange].
  Future<List<Object>> lrange(String listId, [int startingFrom=0, int endingAt=-1]) => raw.lrange(listId, startingFrom, endingAt).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.lpush].
  Future<int> lpush(String listId, Object value) => raw.lpush(listId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.mlpush].
  Future<int> mlpush(String listId, List<Object> values) => raw.mlpush(listId, values.map((x) => serializer.serialize(x)));

  /// Wrapper for [RawRedisCommands.lpushx].
  Future<int> lpushx(String listId, Object value) => raw.lpushx(listId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.mlpushx].
  Future<int> mlpushx(String listId, List<Object> values) => raw.mlpushx(listId, values.map((x) => serializer.serialize(x)));

  /// Wrapper for [RawRedisCommands.rpush].
  Future<int> rpush(String listId, Object value) => raw.rpush(listId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.mrpush].
  Future<int> mrpush(String listId, List<Object> values) => raw.mrpush(listId, values.map((x) => serializer.serialize(x)));

  /// Wrapper for [RawRedisCommands.rpushx].
  Future<int> rpushx(String listId, Object value) => raw.rpushx(listId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.mrpushx].
  Future<int> mrpushx(String listId, List<Object> values) => raw.mrpushx(listId, values.map((x) => serializer.serialize(x)));

  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt) => connection.sendExpectSuccess([Cmd.LTRIM, keyBytes(listId), serializer.serialize(keepStartingFrom), serializer.serialize(keepEndingAt)]);

  /// Wrapper for [RawRedisCommands.lrem].
  Future<int> lrem(String listId, int removeNoOfMatches, Object value) => raw.lrem(listId, removeNoOfMatches, serializer.serialize(value));

  Future<int> llen(String listId) => connection.sendExpectInt([Cmd.LLEN, keyBytes(listId)]);

  /// Wrapper for [RawRedisCommands.lindex].
  Future<Object> lindex(String listId, int listIndex) => raw.lindex(listId, listIndex).then(serializer.deserialize);

  /// Wrapper for [RawRedisCommands.lset].
  Future lset(String listId, int listIndex, Object value) => raw.lset(listId, listIndex, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.lpop].
  Future<Object> lpop(String listId) => raw.lpop(listId).then(serializer.deserialize);

  /// Wrapper for [RawRedisCommands.rpop].
  Future<Object> rpop(String listId) => raw.rpop(listId).then(serializer.deserialize);

  /// Wrapper for [RawRedisCommands.rpoplpush].
  Future<Object> rpoplpush(String fromListId, String toListId) => raw.rpoplpush(fromListId, toListId).then(serializer.deserialize);



  /// SORTED SETS
  /// ===========


  /// Wrapper for [RawRedisCommands.zadd].
  Future<int> zadd(String setId, num score, Object value) => raw.zadd(setId, score, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.zmadd].
  Future<int> zmadd(String setId, Map<Object,num> scoresMap) {
    List<List<int>> args = new List<List<int>>();
    scoresMap.forEach((k,v) {
      args.add(serializer.serialize(v));
      args.add(serializer.serialize(k));
    });
    return raw.zmadd(setId, args);
  }

  /// Wrapper for [RawRedisCommands.zrem].
  Future<int> zrem(String setId, Object value) => raw.zrem(setId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.zmrem].
  Future<int> zmrem(String setId, List<Object> values) => raw.zmrem(setId, values.map((x) => serializer.serialize(x)));

  /// Wrapper for [RawRedisCommands.zincrby].
  Future<double> zincrby(String setId, num incrBy, Object value) => raw.zincrby(setId, incrBy, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.zrank].
  Future<int> zrank(String setId, Object value) => raw.zrank(setId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.zrevrank].
  Future<int> zrevrank(String setId, Object value) => raw.zrevrank(setId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.zrange].
  Future<List<Object>> zrange(String setId, int min, int max) => raw.zrange(setId, min, max).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.zrangeWithScores].
  Future<Map<Object,double>> zrangeWithScores(String setId, int min, int max) => raw.zrangeWithScores(setId, min, max).then(toScoreMap);

  /// Wrapper for [RawRedisCommands.zrevrange].
  Future<List<Object>> zrevrange(String setId, int min, int max) => raw.zrevrange(setId, min, max).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.zrevrangeWithScores].
  Future<Map<Object,double>> zrevrangeWithScores(String setId, int min, int max) => raw.zrevrangeWithScores(setId, min, max).then(toScoreMap);

  /// Wrapper for [RawRedisCommands.zrangebyscore].
  Future<List<Object>> zrangebyscore(String setId, num min, num max, [int skip, int take]) => raw.zrangebyscore(setId, min, max, skip, take).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.zrangebyscoreWithScores].
  Future<Map<Object,double>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => raw.zrangebyscoreWithScores(setId, min, max, skip, take).then(toScoreMap);

  /// Wrapper for [RawRedisCommands.zrevrangebyscore].
  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]) => raw.zrevrangebyscore(setId, min, max, skip, take);

  /// Wrapper for [RawRedisCommands.zrevrangebyscoreWithScores].
  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => raw.zrevrangebyscoreWithScores(setId, min, max, skip, take);

  Future<int> zremrangebyrank(String setId, int min, int max) => connection.sendExpectInt([Cmd.ZREMRANGEBYRANK, keyBytes(setId), serializer.serialize(min), serializer.serialize(max)]);

  Future<int> zremrangebyscore(String setId, num min, num max) => connection.sendExpectInt([Cmd.ZREMRANGEBYSCORE, keyBytes(setId), serializer.serialize(min), serializer.serialize(max)]);

  Future<int> zcard(String setId) => connection.sendExpectInt([Cmd.ZCARD, keyBytes(setId)]);

  /// Wrapper for [RawRedisCommands.zscore].
  Future<double> zscore(String setId, Object value) => raw.zscore(setId, serializer.serialize(value));

  Future<int> zunionstore(String intoSetId, List<String> setIds) {
    setIds.insert(0, setIds.length.toString());
    setIds.insert(0, intoSetId);
    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(Cmd.ZUNIONSTORE, setIds));
  }

  Future<int> zinterstore(String intoSetId, List<String> setIds) {
    setIds.insert(0, setIds.length.toString());
    setIds.insert(0, intoSetId);
    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(Cmd.ZINTERSTORE, setIds));
  }




  /// HASH
  /// ====


  /// Wrapper for [RawRedisCommands.hset].
  Future<bool> hset(String hashId, String key, Object value) => raw.hset(hashId, key, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.hsetnx].
  Future<bool> hsetnx(String hashId, String key, Object value) => raw.hsetnx(hashId, key, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.hmset].
  Future hmset(String hashId, Map<String,Object> map) => raw.hmset(hashId, map.keys.map(serializer.serialize), map.values.map(serializer.serialize));

  Future<int> hincrby(String hashId, String key, int incrBy) => connection.sendExpectInt([Cmd.HINCRBY, keyBytes(hashId), keyBytes(key), serializer.serialize(incrBy)]);

  Future<double> hincrbyfloat(String hashId, String key, double incrBy) => connection.sendExpectDouble([Cmd.HINCRBYFLOAT, keyBytes(hashId), keyBytes(key), serializer.serialize(incrBy)]);

  /// Wrapper for [RawRedisCommands.hget].
  Future<Object> hget(String hashId, String key) => raw.hget(hashId, key).then(serializer.deserialize);

  /// Wrapper for [RawRedisCommands.hmget].
  Future<List<Object>> hmget(String hashId, List<String> keys) => raw.hmget(hashId, keys).then((x) => x.map(serializer.deserialize));

  Future<int> hdel(String hashId, String key) => connection.sendExpectInt([Cmd.HDEL, keyBytes(hashId), keyBytes(key)]);

  Future<bool> hexists(String hashId, String key) => connection.sendExpectIntSuccess([Cmd.HEXISTS, keyBytes(hashId), keyBytes(key)]);

  Future<int> hlen(String hashId) => connection.sendExpectInt([Cmd.HLEN, keyBytes(hashId)]);

  Future<List<String>> hkeys(String hashId) => connection.sendExpectMultiData([Cmd.HKEYS, keyBytes(hashId)]).then((bytes) => bytes.map((x) => new String.fromCharCodes(x)));

  /// Wrapper for [RawRedisCommands.hvals].
  Future<List<Object>> hvals(String hashId) => raw.hvals(hashId).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.hgetall].
  Future<Map<String,Object>> hgetall(String hashId) => raw.hgetall(hashId).then(toMap);



}


class RedisClientException implements Exception {

  String message;

  RedisClientException(this.message);

  String toString() => "RedisClientException: $message";

}


class _Tuple<E> {

  E item1;

  E item2;

  E item3;

  E item4;

  _Tuple(this.item1, this.item2, [this.item3, this.item4]);
}

