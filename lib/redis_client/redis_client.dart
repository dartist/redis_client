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






  /// Converts bytes to a Map
  Map<String,Object> toMap(List<List<int>> multiData) {
    Map<String,Object> map = new Map<String,Object>();
    for (int i = 0; i < multiData.length; i += 2) {
      String key = _toStr(multiData[i]);
      map[key] = serializer.deserialize(multiData[i + 1]);
    }
    return map;
  }


  Map<Object,double> toScoreMap(List<List<int>> multiData) {
    Map<Object,double> map = new Map<String,double>();
    for (int i = 0; i < multiData.length; i += 2) {
      Object key = serializer.deserialize(multiData[i]);
      map[key] = double.parse(_toStr(multiData[i + 1]));
    }
    return map;
  }

  /// Converts a list of bytes to a string
  static String _toStr(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes);


  /// Converts a String to a list of UTF8 bytes.
  static List<int> _keyBytes(String key) {
    if (key == null || key.isEmpty) throw new Exception("Key can not be null.");
    return encodeUtf8(key);
  }

  /// Converts any given value to it's binary representation of the string.
  static List<int> _toBytes(Object value) {
    if (value == null) return new List<int>();
    else return encodeUtf8(value.toString());
  }

  /// Converts an integer to it's binary string representation.
  static List<int> _intToBytes(int value) {
    if (value == null) throw new Exception("Integer can not be null.");
    return encodeUtf8(value.toString());
  }

  /// Takes a command and a map and returns a list of all binary values.
  List<List<int>> _keyValueMapToList(List<int> command, Map map) {

    List<List<int>> completeList = new List<List<int>>(map.length * 2 + 1);
    completeList[0] = command;

    var i = 1;
    map.forEach((key, value) {
      completeList[i++] = _keyBytes(key);
      completeList[i++] = serializer.serialize(value);
    });

    return completeList;
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

  Future<int> get dbsize => connection.sendExpectInt([RedisCommand.DBSIZE]);

  /// Wrapper for [RawRedisCommands.lastsave].
  Future<DateTime> get lastsave => raw.lastsave.then((int unixTs) => new DateTime.fromMillisecondsSinceEpoch(unixTs * 1000, isUtc:true));

  Future flushdb() => connection.sendExpectSuccess([RedisCommand.FLUSHDB]);

  Future flushall() => connection.rawSend([ RedisCommand.FLUSHALL ]).receiveStatus("OK");

  Future save() => connection.sendExpectSuccess([RedisCommand.SAVE]);

  Future bgsave() => connection.sendExpectSuccess([RedisCommand.BGSAVE]);

  Future shutdown() => connection.sendExpectSuccess([RedisCommand.SHUTDOWN]);

  Future bgrewriteaof() => connection.sendExpectSuccess([RedisCommand.BGREWRITEAOF]);

  Future quit() => connection.sendExpectSuccess([RedisCommand.QUIT]);

  Future<Map> get info{
    return connection.sendExpectString([RedisCommand.INFO])
        .then((String lines) {
           Map info = {};
           for(String line in lines.split("\r\n")) {
             List<String> kvp = $(line).splitOnFirst(":");
             info[kvp[0]] = kvp.length == 2 ? kvp[1] : null;
           }
           return info;
        });
  }

  Future<bool> ping() => connection.sendExpectCode([RedisCommand.PING]).then((String r) => r == "PONG");

  /// Wrapper for [RawRedisCommands.echo].
  Future<Object> echo(Object value) => raw.echo(serializer.serialize(value)).then(serializer.deserialize);

  Future<String> type(String key) => connection.sendExpectCode([ RedisCommand.TYPE, _keyBytes(key) ]);


  /// Keys
  /// ====


  /**
   * Returns all keys matching pattern.
   *
   * While the time complexity for this operation is O(N), the constant times are fairly low. For example, Redis running on an entry level laptop can scan a 1 million key database in 40 milliseconds.
   *
   * Supported glob-style patterns:
   *
   * - `h?llo` matches `hello`, `hallo` and `hxllo`
   * - `h*llo` matches `hllo` and `heeeello`
   * - `h[ae]llo` matches `hello` and `hallo`, but not `hillo`
   *
   * Use `\` to escape special characters if you want to match them verbatim.
   *
   * **Warning**: consider [keys] as a command that should only be used in production environments with extreme care. It may ruin performance when it is executed against large databases. This command is intended for debugging and special operations, such as changing your keyspace layout. Don't use [keys] in your regular application code. If you're looking for a way to find keys in a subset of your keyspace, consider using sets.
   */
  Future<List<String>> keys(String pattern) => connection.rawSend([ RedisCommand.KEYS, _keyBytes(pattern) ]).receiveMultiBulkStrings();

  /// Returns the stored value of given key.
  Future<Object> get(String key) => connection.rawSend([ RedisCommand.GET, _keyBytes(key) ]).receiveBulkDeserialized(serializer);

  /// Returns all the stored values of given keys.
  Future<List<Object>> mget(List<String> keys) => keys.isEmpty ? new Future([ ]) : connection.rawSend(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.MGET, keys)).receiveMultiBulkDeserialized(serializer);

  /// Sets the value of given key, and returns the value that was stored previously.
  Future<Object> getset(String key, Object value) => connection.rawSend([RedisCommand.GETSET, _keyBytes(key), serializer.serialize(value)]).receiveBulkData().then(serializer.deserialize);

  /// Sets the value of given key.
  Future set(String key, Object value) => connection.rawSend([ RedisCommand.SET, _keyBytes(key), serializer.serialize(value) ]).receiveStatus("OK");

  /**
   * Sets a value and the expiration in one step.
   *
   * This is the same as:
   *
   *     client
   *         ..set(mykey, value)
   *         ..expire(mykey, seconds);
   */
  Future setex(String key, int expireInSecs, Object value) => connection.rawSend([ RedisCommand.SETEX, _keyBytes(key), _intToBytes(expireInSecs), serializer.serialize(value) ]).receiveStatus("OK");

  /// [psetex] works exactly like [setex] with the sole difference that the expire time is specified in milliseconds instead of seconds.
  Future psetex(String key, int expireInMs, Object value) => connection.rawSend([ RedisCommand.PSETEX, _keyBytes(key), _intToBytes(expireInMs), serializer.serialize(value) ]).receiveStatus("OK");

  /**
   * Remove the existing timeout on key.
   *
   * Turns the key from volatile (a key with an expire set) to persistent (a key that will never expire as no timeout is associated).
   *
   * Returns `true` if the timeout was removed, `0` if key does not exist or does not have an associated timeout.
   */
  Future<bool> persist(String key) => connection.rawSend([ RedisCommand.PERSIST, _keyBytes(key) ]).receiveBool();

  /**
   * Sets all values in the given map.
   *
   * [mset] replaces existing values with new values, just as regular [set].
   *
   * See [msetnx] if you don't want to overwrite existing values.
   */
  Future mset(Map map) => connection.rawSend(_keyValueMapToList(RedisCommand.MSET, map)).receiveStatus("OK");

  /**
   * Sets the given keys to their respective values. **[msetnx] will not perform any operation at all even if just a single key already exists.**
   *
   * Because of this semantic [msetnx] can be used in order to set different keys representing different fields of an unique logic object in a way that ensures that either all the fields or none at all are set.
   *
   * [msetnx] is atomic, so all given keys are set at once. It is not possible for clients to see that some of the keys were updated while others are unchanged.
   */
  Future<bool> msetnx(Map map) => connection.rawSend(_keyValueMapToList(RedisCommand.MSETNX, map)).receiveBool();

  /// Returns `true` if key exists, `false` otherwise.
  Future<bool> exists(String key) => connection.rawSend([ RedisCommand.EXISTS, _keyBytes(key) ]).receiveBool();

  /**
   * Deletes a single key.
   *
   * Returns true if the key existed, false otherwise.
   *
   * Contrary to redis `DEL` command this method takes only one key for
   * convenience. Use [mdel] if you want to delete multiple keys.
   */
  Future<bool> del(String key) => mdel([ key ]).then((deleteCount) => deleteCount == 1);

  /**
   * Deletes multiple keys and returns the number of deleted keys.
   *
   * This command is called `DEL` in redis.
   */
  Future<int> mdel(List<String> keys) => keys.isEmpty ? new Future(0) : connection.rawSend(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.DEL, keys)).receiveInteger();

  Future<int> incr(String key) => connection.sendExpectInt([RedisCommand.INCR, _keyBytes(key)]);

  Future<int> incrby(String key, int count) => connection.sendExpectInt([RedisCommand.INCRBY, _keyBytes(key), serializer.serialize(count)]);

  Future<double> incrbyfloat(String key, double count) => connection.sendExpectDouble([RedisCommand.INCRBYFLOAT, _keyBytes(key), serializer.serialize(count)]);

  Future<int> decr(String key) => connection.sendExpectInt([RedisCommand.DECR, _keyBytes(key)]);

  Future<int> decrby(String key, int count) => connection.sendExpectInt([RedisCommand.DECRBY, _keyBytes(key), serializer.serialize(count)]);

  Future<int> strlen(String key) => connection.sendExpectInt([RedisCommand.STRLEN, _keyBytes(key)]);

  /// Wrapper for [RawRedisCommands.append].
  Future<int> append(String key, String value) => raw.append(key, serializer.serialize(value));


  /// Wrapper for [RawRedisCommands.substr].
  Future<String> substr(String key, int fromIndex, int toIndex) => raw.substr(key, fromIndex, toIndex).then(_toStr);

  /// Wrapper for [RawRedisCommands.getrange].
  Future<String> getrange(String key, int fromIndex, int toIndex) => raw.getrange(key, fromIndex, toIndex).then(_toStr);

  /// Wrapper for [RawRedisCommands.setrange].
  Future<String> setrange(String key, int offset, String value) => raw.setrange(key, offset, serializer.serialize(value)).then(_toStr);

  Future<int> getbit(String key, int offset) => connection.sendExpectInt([RedisCommand.GETBIT, _keyBytes(key), serializer.serialize(offset)]);

  Future<int> setbit(String key, int offset, int value) => connection.sendExpectInt([RedisCommand.SETBIT, _keyBytes(key), serializer.serialize(offset), serializer.serialize(value)]);

  /// Wrapper for [RawRedisCommands.randomkey].
  Future<String> randomkey() => raw.randomkey().then(_toStr);

  Future rename(String oldKey, String newKey) => connection.sendExpectSuccess([RedisCommand.RENAME, _keyBytes(oldKey), _keyBytes(newKey)]);

  Future<bool> renamenx(String oldKey, String newKey) => connection.sendExpectIntSuccess([RedisCommand.RENAMENX, _keyBytes(oldKey), _keyBytes(newKey)]);

  Future<bool> expire(String key, int expireInSecs) => connection.sendExpectIntSuccess([RedisCommand.EXPIRE, _keyBytes(key), serializer.serialize(expireInSecs)]);

  Future<bool> pexpire(String key, int expireInMs) => connection.sendExpectIntSuccess([RedisCommand.PEXPIRE, _keyBytes(key), serializer.serialize(expireInMs)]);

  /// Wrapper for [RawRedisCommands.expireat].
  Future<bool> expireat(String key, DateTime date) => raw.expireat(key, date.toUtc().millisecondsSinceEpoch ~/ 1000);

  /// Wrapper for [RawRedisCommands.pexpireat].
  Future<bool> pexpireat(String key, DateTime date) => raw.pexpireat(key, date.toUtc().millisecondsSinceEpoch);

  /**
   * Returns the remaining time to live of a key that has a timeout.
   *
   * This introspection capability allows a Redis client to check how many seconds a given key will continue to be part of the dataset.
   */
  Future<int> ttl(String key) => connection.rawSend([ RedisCommand.TTL, _keyBytes(key) ]).receiveInteger();

  Future<int> pttl(String key) => connection.sendExpectInt([RedisCommand.PTTL, _keyBytes(key)]);



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

  Future<int> scard(String setId) => connection.sendExpectInt([RedisCommand.SCARD, _keyBytes(setId)]);

  /// Wrapper for [RawRedisCommands.sismember].
  Future<bool> sismember(String setId, Object value) => raw.sismember(setId, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.sinter].
  Future<List<Object>> sinter(List<String> setIds) => raw.sinter(setIds).then((x) => x.map(serializer.deserialize));

  /// Wrapper for [RawRedisCommands.sinterstore].
  Future<int> sinterstore(String intoSetId, List<String> setIds) => raw.sinterstore(intoSetId, setIds);

  /// Wrapper for [RawRedisCommands.sunion].
  Future<List<Object>> sunion(List<String> setIds) => raw.sunion(setIds).then((x) => x.map(serializer.deserialize));

  Future<int> sunionstore(String intoSetId, List<String> setIds) =>
      connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SUNIONSTORE, $(setIds).insert(0, intoSetId)));

  /// Wrapper for [RawRedisCommands.sdiff].
  Future<List<Object>> sdiff(String fromSetId, List<String> withSetIds) => raw.sdiff(fromSetId, withSetIds).then((x) => x.map(serializer.deserialize));

  Future<int> sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds) {
    withSetIds.insert(0, fromSetId);
    withSetIds.insert(0, intoSetId);
    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SDIFFSTORE, withSetIds));
  }

  /// Wrapper for [RawRedisCommands.srandmember].
  Future<Object> srandmember(String setId) => raw.srandmember(setId).then(serializer.deserialize);




  /// SORT SET/LIST
  /// =============

  Future<List<List<int>>> sort(String listOrSetId,
    [String sortPattern, int skip, int take, String getPattern, bool sortAlpha=false, bool sortDesc=false, String storeAtKey]) {

    List<List<int>> cmdWithArgs = [RedisCommand.SORT, _keyBytes(listOrSetId)];

    if (sortPattern != null) {
      cmdWithArgs.add(RedisCommand.BY);
      cmdWithArgs.add(serializer.serialize(sortPattern));
    }

    if (skip != null || take != null) {
      cmdWithArgs.add(RedisCommand.LIMIT);
      cmdWithArgs.add(serializer.serialize(skip == null ? 0 : skip));
      cmdWithArgs.add(serializer.serialize(take == null ? 0 : take));
    }

    if (getPattern != null) {
      cmdWithArgs.add(RedisCommand.GET);
      cmdWithArgs.add(serializer.serialize(getPattern));
    }

    if (sortDesc) cmdWithArgs.add(RedisCommand.DESC);

    if (sortAlpha) cmdWithArgs.add(RedisCommand.ALPHA);

    if (storeAtKey != null) {
      cmdWithArgs.add(RedisCommand.STORE);
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

  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt) => connection.sendExpectSuccess([RedisCommand.LTRIM, _keyBytes(listId), serializer.serialize(keepStartingFrom), serializer.serialize(keepEndingAt)]);

  /// Wrapper for [RawRedisCommands.lrem].
  Future<int> lrem(String listId, int removeNoOfMatches, Object value) => raw.lrem(listId, removeNoOfMatches, serializer.serialize(value));

  Future<int> llen(String listId) => connection.sendExpectInt([RedisCommand.LLEN, _keyBytes(listId)]);

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

  Future<int> zremrangebyrank(String setId, int min, int max) => connection.sendExpectInt([RedisCommand.ZREMRANGEBYRANK, _keyBytes(setId), serializer.serialize(min), serializer.serialize(max)]);

  Future<int> zremrangebyscore(String setId, num min, num max) => connection.sendExpectInt([RedisCommand.ZREMRANGEBYSCORE, _keyBytes(setId), serializer.serialize(min), serializer.serialize(max)]);

  Future<int> zcard(String setId) => connection.sendExpectInt([RedisCommand.ZCARD, _keyBytes(setId)]);

  /// Wrapper for [RawRedisCommands.zscore].
  Future<double> zscore(String setId, Object value) => raw.zscore(setId, serializer.serialize(value));

  Future<int> zunionstore(String intoSetId, List<String> setIds) {
    setIds.insert(0, setIds.length.toString());
    setIds.insert(0, intoSetId);
    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.ZUNIONSTORE, setIds));
  }

  Future<int> zinterstore(String intoSetId, List<String> setIds) {
    setIds.insert(0, setIds.length.toString());
    setIds.insert(0, intoSetId);
    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.ZINTERSTORE, setIds));
  }




  /// HASH
  /// ====


  /// Wrapper for [RawRedisCommands.hset].
  Future<bool> hset(String hashId, String key, Object value) => raw.hset(hashId, key, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.hsetnx].
  Future<bool> hsetnx(String hashId, String key, Object value) => raw.hsetnx(hashId, key, serializer.serialize(value));

  /// Wrapper for [RawRedisCommands.hmset].
  Future hmset(String hashId, Map<String,Object> map) => raw.hmset(hashId, map.keys.map(serializer.serialize), map.values.map(serializer.serialize));

  Future<int> hincrby(String hashId, String key, int incrBy) => connection.sendExpectInt([RedisCommand.HINCRBY, _keyBytes(hashId), _keyBytes(key), serializer.serialize(incrBy)]);

  Future<double> hincrbyfloat(String hashId, String key, double incrBy) => connection.sendExpectDouble([RedisCommand.HINCRBYFLOAT, _keyBytes(hashId), _keyBytes(key), serializer.serialize(incrBy)]);

  /// Wrapper for [RawRedisCommands.hget].
  Future<Object> hget(String hashId, String key) => raw.hget(hashId, key).then(serializer.deserialize);

  /// Wrapper for [RawRedisCommands.hmget].
  Future<List<Object>> hmget(String hashId, List<String> keys) => raw.hmget(hashId, keys).then((x) => x.map(serializer.deserialize));

  Future<int> hdel(String hashId, String key) => connection.sendExpectInt([RedisCommand.HDEL, _keyBytes(hashId), _keyBytes(key)]);

  Future<bool> hexists(String hashId, String key) => connection.sendExpectIntSuccess([RedisCommand.HEXISTS, _keyBytes(hashId), _keyBytes(key)]);

  Future<int> hlen(String hashId) => connection.sendExpectInt([RedisCommand.HLEN, _keyBytes(hashId)]);

  Future<List<String>> hkeys(String hashId) => connection.sendExpectMultiData([RedisCommand.HKEYS, _keyBytes(hashId)]).then((bytes) => bytes.map((x) => new String.fromCharCodes(x)));

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

