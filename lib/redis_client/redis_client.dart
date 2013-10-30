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
  }



  /// Takes a command and a map and returns a list of all binary values.
  List<List<int>> _keyValueMapToList(List<int> command, Map<String, String> map) {

    List<List<int>> completeList = new List<List<int>>(map.length * 2 + 1);
    completeList[0] = command;

    var i = 1;
    map.forEach((key, value) {
      completeList[i++] = UTF8.encode(key);
      completeList[i++] = UTF8.encode(value);
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

  /// Return the number of keys in the currently-selected database.
  Future<int> get dbsize => connection.rawSend([ RedisCommand.DBSIZE ]).receiveInteger();

  /// Delete all the keys of the currently selected DB. This command never fails
  Future flushdb() => connection.rawSend([ RedisCommand.FLUSHDB ]).receiveStatus("OK");

  /// Delete all the keys of all the existing databases, not just the currently selected one. This command never fails.
  Future flushall() => connection.rawSend([ RedisCommand.FLUSHALL ]).receiveStatus("OK");


  /// Returns the DateTime of the last DB [save] executed with success.
  Future<DateTime> get lastsave => connection.rawSend([ RedisCommand.LASTSAVE ]).receiveInteger().then((int unixTs) => new DateTime.fromMillisecondsSinceEpoch(unixTs * 1000, isUtc: true));

  /**
   * The [save] command performs a synchronous save of the dataset producing a point
   * in time snapshot of all the data inside the Redis instance, in the form of an RDB file.
   *
   * You almost never want to call [save] in production environments where it will
   * block all the other clients. Instead usually [bgsave] is used. However in case
   * of issues preventing Redis to create the background saving child (for instance
   * errors in the fork(2) system call), the [save] command can be a good last resort
   * to perform the dump of the latest dataset.
   */
  Future save() => connection.rawSend([ RedisCommand.SAVE ]).receiveStatus("OK");

  /**
   * Save the DB in background. The OK code is immediately returned.
   *
   * Redis forks, the parent continues to serve the clients, the child saves the DB on disk then exits.
   *
   * A client my be able to check if the operation succeeded using the [lastsave] command.
   */
  Future bgsave() => connection.rawSend([ RedisCommand.BGSAVE ]).receiveStatus("Background saving started");

  /**
   * The command behavior is the following:
   *
   * - Stop all the clients.
   * - Perform a blocking SAVE if at least one **save point** is configured.
   * - Flush the Append Only File if AOF is enabled.
   * - Quit the server.
   *
   * If persistence is enabled this commands makes sure that Redis is switched off
   * without the lost of any data. This is not guaranteed if the client uses simply
   * SAVE and then QUIT because other clients may alter the DB data between the two commands.
   *
   * Note: A Redis instance that is configured for not persisting on disk (no AOF
   * configured, nor "save" directive) will not dump the RDB file on SHUTDOWN,
   * as usually you don't want Redis instances used only for caching to block on
   * when shutting down.
   */
  Future shutdown() => connection.rawSend([ RedisCommand.SHUTDOWN ]).receive();

  /**
   * Instruct Redis to start an Append Only File rewrite process. The rewrite will
   * create a small optimized version of the current Append Only File.
   *
   * If BGREWRITEAOF fails, no data gets lost as the old AOF will be untouched.
   *
   * The rewrite will be only triggered by Redis if there is not already a background
   * process doing persistence.
   */
  Future bgrewriteaof() => connection.rawSend([ RedisCommand.BGREWRITEAOF ]).receiveStatus("OK");

  /**
   * Ask the server to close the connection.
   *
   * The connection is closed as soon as all pending replies have been written to the client.
   */
  Future quit() => connection.rawSend([ RedisCommand.QUIT ]).receiveStatus("OK");

  /**
   * The INFO command returns information and statistics about the server.
   *
   * This function parses the output properly and returns a map in the form of:
   *
   *     {
   *       "Server": {
   *           "redis_version": "2.5.13",
   *           "redis_git_sha1": "2812b945"
   *           /* etc... */
   *       },
   *       "Clients": {
   *           "connected_clients": "8"
   *           /* etc... */
   *       }
   *       /* etc... */
   *     }
   *
   * Please refer to the [official redis info documentation](http://redis.io/commands/info)
   * for an explanation of the values.
   */
  Future<Map<String, Map<String, String>>> get info {
    return connection.rawSend([ RedisCommand.INFO ]).receiveBulkString().then(parseInfoString);
  }

  /**
   * Parses the string returned by the INFO command.
   */
  Map<String, Map<String, String>> parseInfoString(String lines) {
    Map<String, Map<String, String>> info = { };

    var sectionMap, sectionName;

    for (String line in lines.split(new RegExp(r"(\r\n|\n)"))) {
      if (line.isEmpty) continue;

      if (line.substring(0, 2) == '# ') {
        // New section
        sectionName = line.substring(2);
        sectionMap = new Map<String, String>();
        info[sectionName] = sectionMap;
      }
      else {
        if (sectionMap == null) throw new RedisClientException("Received an info line ($line) without a section.");

        // Section info
        var colonIndex = line.indexOf(":");
        if (colonIndex < 1) throw new RedisClientException("The info line did not contain a colon (:).");

        sectionMap[line.substring(0, colonIndex)] = line.substring(colonIndex + 1);
      }
    }

    return info;
  }

  /**
   * This command is often used to test if a connection is still alive, or to measure latency.
   *
   * Fails if the result is not PONG.
   */
  Future<String> ping() => connection.rawSend([ RedisCommand.PING ]).receiveStatus("PONG");

  /// Returns message.
  Future<Object> echo(String value) => connection.sendCommand(RedisCommand.ECHO, [ value ]).receiveBulkString();

  /**
   * Returns the string representation of the type of the value stored at key.
   *
   * The different types that can be returned are:
   *
   * - string
   * - list
   * - set
   * - zset
   * - hash
   * - none if string didn't exist
   */
  Future<String> type(String key) => connection.sendCommand(RedisCommand.TYPE, [ key ]).receiveStatus();


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
  Future<List<String>> keys(String pattern) => connection.sendCommand(RedisCommand.KEYS, [ pattern ]).receiveMultiBulkStrings();

  /// Returns the stored value of given key.
  Future<String> get(String key) => connection.sendCommand(RedisCommand.GET, [ key ]).receiveBulkString();

  /// Returns all the stored values of given keys.
  Future<List<String>> mget(List<String> keys) => keys.isEmpty ? new Future.value([ ]) : connection.sendCommand(RedisCommand.MGET, keys).receiveMultiBulkStrings();

  /// Sets the value of given key, and returns the value that was stored previously.
  Future<String> getset(String key, String value) => connection.sendCommand(RedisCommand.GETSET, [ key, value ]).receiveBulkString();

  /// Sets the value of given key.
  Future set(String key, String value) => connection.sendCommand(RedisCommand.SET, [ key, value ]).receiveStatus("OK");

  /**
   * Sets a value and the expiration in one step.
   *
   * This is the same as:
   *
   *     client
   *         ..set(mykey, value)
   *         ..expire(mykey, seconds);
   */
  Future setex(String key, int expireInSecs, String value) => connection.sendCommand(RedisCommand.SETEX, [ key, expireInSecs.toString(), value ]).receiveStatus("OK");

  /// [psetex] works exactly like [setex] with the sole difference that the expire time is specified in milliseconds instead of seconds.
  Future psetex(String key, int expireInMs, String value) => connection.sendCommand(RedisCommand.PSETEX, [ key, expireInMs.toString(), value ]).receiveStatus("OK");

  /**
   * Remove the existing timeout on key.
   *
   * Turns the key from volatile (a key with an expire set) to persistent (a key that will never expire as no timeout is associated).
   *
   * Returns `true` if the timeout was removed, `false` if key does not exist or does not have an associated timeout.
   */
  Future<bool> persist(String key) => connection.sendCommand(RedisCommand.PERSIST,  [ key ]).receiveBool();

  /**
   * Sets all values in the given map.
   *
   * [mset] replaces existing values with new values, just as regular [set].
   *
   * See [msetnx] if you don't want to overwrite existing values.
   */
  Future mset(Map<String, String> map) => connection.rawSend(_keyValueMapToList(RedisCommand.MSET, map)).receiveStatus("OK");

  /**
   * Sets the given keys to their respective values. **[msetnx] will not perform any operation at all even if just a single key already exists.**
   *
   * Because of this semantic [msetnx] can be used in order to set different keys representing different fields of an unique logic object in a way that ensures that either all the fields or none at all are set.
   *
   * [msetnx] is atomic, so all given keys are set at once. It is not possible for clients to see that some of the keys were updated while others are unchanged.
   */
  Future<bool> msetnx(Map<String, String> map) => connection.rawSend(_keyValueMapToList(RedisCommand.MSETNX, map)).receiveBool();

  /**
   * Returns `true` if key exists, `false` otherwise.
   */
  Future<bool> exists(String key) => connection.sendCommand(RedisCommand.EXISTS, [ key ]).receiveBool();

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
  Future<int> mdel(List<String> keys) => keys.isEmpty ? new Future.value(0) : connection.sendCommand(RedisCommand.DEL, keys).receiveInteger();

  /**
   * Increments the number stored at key by one returning the value of key after
   * the increment.
   *
   * If the key does not exist, it is set to 0 before performing the operation.
   *
   * An error is returned if the key contains a value of the wrong type or
   * contains a string that can not be represented as integer.
   *
   * This operation is limited to 64 bit signed integers.
   */
  Future<int> incr(String key) => connection.sendCommand(RedisCommand.INCR, [ key ]).receiveInteger();

  /**
   * Increments the number stored at key by increment and returns the value after
   * the increment.
   *
   * If the key does not exist, it is set to 0 before performing the operation.
   *
   * An error is returned if the key contains a value of the wrong type or
   * contains a string that can not be represented as integer.
   *
   * This operation is limited to 64 bit signed integers.
   */
   Future<int> incrby(String key, int count) => connection.sendCommand(RedisCommand.INCRBY, [ key, count.toString() ]).receiveInteger();

   /**
    * Increment the string representing a floating point number stored at key
    * by the specified increment and returns the value after the increment.
    *
    * If the key does not exist, it is set to 0 before performing the operation.
    * An error is returned if one of the following conditions occur:
    *
    * - The key contains a value of the wrong type (not a string).
    * - The current key content or the specified increment are not parsable as a double precision floating point number.
    *
    * See the [official documentation](http://redis.io/commands/incrbyfloat) for
    * more information.
    */
    Future<double> incrbyfloat(String key, double count) => connection.sendCommand(RedisCommand.INCRBYFLOAT, [ key, count.toString() ]).receiveDouble();

    /**
     * Decrements the number stored at key by one and returns the value of the
     * key after the decrement.
     *
     * If the key does not exist, it is set to 0 before performing the operation.
     * An error is returned if the key contains a value of the wrong type or
     * contains a string that can not be represented as integer.
     *
     * This operation is limited to 64 bit signed integers.
     */
    Future<int> decr(String key) => connection.sendCommand(RedisCommand.DECR, [ key ]).receiveInteger();

    /**
     * Decrements the number stored at key by decrement and returns the value of
     * the key after the decrement.
     *
     * If the key does not exist, it is set to 0 before performing the operation.
     * An error is returned if the key contains a value of the wrong type or
     * contains a string that can not be represented as integer.
     *
     * This operation is limited to 64 bit signed integers.
     */
    Future<int> decrby(String key, int count) => connection.sendCommand(RedisCommand.DECRBY, [ key, count.toString() ]).receiveInteger();


    /**
     * Returns the length of the string value stored at key.
     *
     * An error is returned when key holds a non-string value.
     */
    Future<int> strlen(String key) => connection.sendCommand(RedisCommand.STRLEN, [ key ]).receiveInteger();


    /**
     * If key already exists and is a string, this command appends the value at the end of the string.
     * If key does not exist it is created and set as an empty string, so APPEND will be similar to SET in this special case.
     *
     * Returns the length of the string after the append operation.
     */
    Future<int> append(String key, String value) => connection.sendCommand(RedisCommand.APPEND, [ key, value ]).receiveInteger();


    /**
     * Returns the substring of the string value stored at key, determined by the
     * offsets start and end (both are inclusive).
     *
     * Negative offsets can be used in order to provide an offset starting from
     * the end of the string. So -1 means the last character, -2 the penultimate
     * and so forth.
     *
     * The function handles out of range requests by limiting the resulting range
     * to the actual length of the string.
     */
    Future<String> getrange(String key, int fromIndex, int toIndex) => connection.sendCommand(RedisCommand.GETRANGE, [ key, fromIndex.toString(), toIndex.toString() ]).receiveBulkString();


//  /// Wrapper for [RawRedisCommands.getrange].
//  Future<String> getrange(String key, int fromIndex, int toIndex) => raw.getrange(key, fromIndex, toIndex).then(_toStr);
//
//  /// Wrapper for [RawRedisCommands.setrange].
//  Future<String> setrange(String key, int offset, String value) => raw.setrange(key, offset, serializer.serialize(value)).then(_toStr);
//
//  Future<int> getbit(String key, int offset) => connection.sendExpectInt([RedisCommand.GETBIT, _keyBytes(key), serializer.serialize(offset)]);
//
//  Future<int> setbit(String key, int offset, int value) => connection.sendExpectInt([RedisCommand.SETBIT, _keyBytes(key), serializer.serialize(offset), serializer.serialize(value)]);
//
//  /// Wrapper for [RawRedisCommands.randomkey].
//  Future<String> randomkey() => raw.randomkey().then(_toStr);
//
//  Future rename(String oldKey, String newKey) => connection.sendExpectSuccess([RedisCommand.RENAME, _keyBytes(oldKey), _keyBytes(newKey)]);
//
//  Future<bool> renamenx(String oldKey, String newKey) => connection.sendExpectIntSuccess([RedisCommand.RENAMENX, _keyBytes(oldKey), _keyBytes(newKey)]);
//
//  Future<bool> expire(String key, int expireInSecs) => connection.sendExpectIntSuccess([RedisCommand.EXPIRE, _keyBytes(key), serializer.serialize(expireInSecs)]);
//
//  Future<bool> pexpire(String key, int expireInMs) => connection.sendExpectIntSuccess([RedisCommand.PEXPIRE, _keyBytes(key), serializer.serialize(expireInMs)]);
//
//  /// Wrapper for [RawRedisCommands.expireat].
//  Future<bool> expireat(String key, DateTime date) => raw.expireat(key, date.toUtc().millisecondsSinceEpoch ~/ 1000);
//
//  /// Wrapper for [RawRedisCommands.pexpireat].
//  Future<bool> pexpireat(String key, DateTime date) => raw.pexpireat(key, date.toUtc().millisecondsSinceEpoch);

  /**
   * Returns the remaining time to live of a key that has a timeout.
   *
   * This introspection capability allows a Redis client to check how many seconds a given key will continue to be part of the dataset.
   */
  Future<int> ttl(String key) => connection.sendCommand(RedisCommand.TTL, [ key ]).receiveInteger();

//  Future<int> pttl(String key) => connection.sendExpectInt([RedisCommand.PTTL, _keyBytes(key)]);
//
//
//
//  /// SET
//  /// ===
//
//  /// Wrapper for [RawRedisCommands.smembers].
//  Future<List<Object>> smembers(String setId) => raw.smembers(setId).then((x) => x.map(serializer.deserialize));
//
//  /// Wrapper for [RawRedisCommands.sadd].
//  Future<int> sadd(String setId, Object value) => raw.sadd(setId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.smadd].
//  Future<int> smadd(String setId, List<Object> values) => raw.smadd(setId, values.map((x) => serializer.serialize(x)));
//
//  /// Wrapper for [RawRedisCommands.srem].
//  Future<int> srem(String setId, Object value) => raw.srem(setId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.spop].
//  Future<Object> spop(String setId) => raw.spop(setId).then(serializer.deserialize);
//
//  /// Wrapper for [RawRedisCommands.smove].
//  Future<bool> smove(String fromSetId, String toSetId, Object value) => raw.smove(fromSetId, toSetId, serializer.serialize(value));
//
//  Future<int> scard(String setId) => connection.sendExpectInt([RedisCommand.SCARD, _keyBytes(setId)]);
//
//  /// Wrapper for [RawRedisCommands.sismember].
//  Future<bool> sismember(String setId, Object value) => raw.sismember(setId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.sinter].
//  Future<List<Object>> sinter(List<String> setIds) => raw.sinter(setIds).then((x) => x.map(serializer.deserialize));
//
//  /// Wrapper for [RawRedisCommands.sinterstore].
//  Future<int> sinterstore(String intoSetId, List<String> setIds) => raw.sinterstore(intoSetId, setIds);
//
//  /// Wrapper for [RawRedisCommands.sunion].
//  Future<List<Object>> sunion(List<String> setIds) => raw.sunion(setIds).then((x) => x.map(serializer.deserialize));
//
//  Future<int> sunionstore(String intoSetId, List<String> setIds) =>
//      connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SUNIONSTORE, $(setIds).insert(0, intoSetId)));
//
//  /// Wrapper for [RawRedisCommands.sdiff].
//  Future<List<Object>> sdiff(String fromSetId, List<String> withSetIds) => raw.sdiff(fromSetId, withSetIds).then((x) => x.map(serializer.deserialize));
//
//  Future<int> sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds) {
//    withSetIds.insert(0, fromSetId);
//    withSetIds.insert(0, intoSetId);
//    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.SDIFFSTORE, withSetIds));
//  }
//
//  /// Wrapper for [RawRedisCommands.srandmember].
//  Future<Object> srandmember(String setId) => raw.srandmember(setId).then(serializer.deserialize);
//
//
//
//
//  /// SORT SET/LIST
//  /// =============
//
//  Future<List<List<int>>> sort(String listOrSetId,
//    [String sortPattern, int skip, int take, String getPattern, bool sortAlpha=false, bool sortDesc=false, String storeAtKey]) {
//
//    List<List<int>> cmdWithArgs = [RedisCommand.SORT, _keyBytes(listOrSetId)];
//
//    if (sortPattern != null) {
//      cmdWithArgs.add(RedisCommand.BY);
//      cmdWithArgs.add(serializer.serialize(sortPattern));
//    }
//
//    if (skip != null || take != null) {
//      cmdWithArgs.add(RedisCommand.LIMIT);
//      cmdWithArgs.add(serializer.serialize(skip == null ? 0 : skip));
//      cmdWithArgs.add(serializer.serialize(take == null ? 0 : take));
//    }
//
//    if (getPattern != null) {
//      cmdWithArgs.add(RedisCommand.GET);
//      cmdWithArgs.add(serializer.serialize(getPattern));
//    }
//
//    if (sortDesc) cmdWithArgs.add(RedisCommand.DESC);
//
//    if (sortAlpha) cmdWithArgs.add(RedisCommand.ALPHA);
//
//    if (storeAtKey != null) {
//      cmdWithArgs.add(RedisCommand.STORE);
//      cmdWithArgs.add(serializer.serialize(storeAtKey));
//    }
//
//    return connection.sendExpectMultiData(cmdWithArgs);
//  }
//
//  //LIST
//
//
//  /// Wrapper for [RawRedisCommands.lrange].
//  Future<List<Object>> lrange(String listId, [int startingFrom=0, int endingAt=-1]) => raw.lrange(listId, startingFrom, endingAt).then((x) => x.map(serializer.deserialize));
//
//  /// Wrapper for [RawRedisCommands.lpush].
//  Future<int> lpush(String listId, Object value) => raw.lpush(listId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.mlpush].
//  Future<int> mlpush(String listId, List<Object> values) => raw.mlpush(listId, values.map((x) => serializer.serialize(x)));
//
//  /// Wrapper for [RawRedisCommands.lpushx].
//  Future<int> lpushx(String listId, Object value) => raw.lpushx(listId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.mlpushx].
//  Future<int> mlpushx(String listId, List<Object> values) => raw.mlpushx(listId, values.map((x) => serializer.serialize(x)));
//
//  /// Wrapper for [RawRedisCommands.rpush].
//  Future<int> rpush(String listId, Object value) => raw.rpush(listId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.mrpush].
//  Future<int> mrpush(String listId, List<Object> values) => raw.mrpush(listId, values.map((x) => serializer.serialize(x)));
//
//  /// Wrapper for [RawRedisCommands.rpushx].
//  Future<int> rpushx(String listId, Object value) => raw.rpushx(listId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.mrpushx].
//  Future<int> mrpushx(String listId, List<Object> values) => raw.mrpushx(listId, values.map((x) => serializer.serialize(x)));
//
//  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt) => connection.sendExpectSuccess([RedisCommand.LTRIM, _keyBytes(listId), serializer.serialize(keepStartingFrom), serializer.serialize(keepEndingAt)]);
//
//  /// Wrapper for [RawRedisCommands.lrem].
//  Future<int> lrem(String listId, int removeNoOfMatches, Object value) => raw.lrem(listId, removeNoOfMatches, serializer.serialize(value));
//
//  Future<int> llen(String listId) => connection.sendExpectInt([RedisCommand.LLEN, _keyBytes(listId)]);
//
//  /// Wrapper for [RawRedisCommands.lindex].
//  Future<Object> lindex(String listId, int listIndex) => raw.lindex(listId, listIndex).then(serializer.deserialize);
//
//  /// Wrapper for [RawRedisCommands.lset].
//  Future lset(String listId, int listIndex, Object value) => raw.lset(listId, listIndex, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.lpop].
//  Future<Object> lpop(String listId) => raw.lpop(listId).then(serializer.deserialize);
//
//  /// Wrapper for [RawRedisCommands.rpop].
//  Future<Object> rpop(String listId) => raw.rpop(listId).then(serializer.deserialize);
//
//  /// Wrapper for [RawRedisCommands.rpoplpush].
//  Future<Object> rpoplpush(String fromListId, String toListId) => raw.rpoplpush(fromListId, toListId).then(serializer.deserialize);
//
//
//
//  /// SORTED SETS
//  /// ===========
//
//
//  /// Wrapper for [RawRedisCommands.zadd].
//  Future<int> zadd(String setId, num score, Object value) => raw.zadd(setId, score, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.zmadd].
//  Future<int> zmadd(String setId, Map<Object,num> scoresMap) {
//    List<List<int>> args = new List<List<int>>();
//    scoresMap.forEach((k,v) {
//      args.add(serializer.serialize(v));
//      args.add(serializer.serialize(k));
//    });
//    return raw.zmadd(setId, args);
//  }
//
//  /// Wrapper for [RawRedisCommands.zrem].
//  Future<int> zrem(String setId, Object value) => raw.zrem(setId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.zmrem].
//  Future<int> zmrem(String setId, List<Object> values) => raw.zmrem(setId, values.map((x) => serializer.serialize(x)));
//
//  /// Wrapper for [RawRedisCommands.zincrby].
//  Future<double> zincrby(String setId, num incrBy, Object value) => raw.zincrby(setId, incrBy, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.zrank].
//  Future<int> zrank(String setId, Object value) => raw.zrank(setId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.zrevrank].
//  Future<int> zrevrank(String setId, Object value) => raw.zrevrank(setId, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.zrange].
//  Future<List<Object>> zrange(String setId, int min, int max) => raw.zrange(setId, min, max).then((x) => x.map(serializer.deserialize));
//
//  /// Wrapper for [RawRedisCommands.zrangeWithScores].
//  Future<Map<Object,double>> zrangeWithScores(String setId, int min, int max) => raw.zrangeWithScores(setId, min, max).then(toScoreMap);
//
//  /// Wrapper for [RawRedisCommands.zrevrange].
//  Future<List<Object>> zrevrange(String setId, int min, int max) => raw.zrevrange(setId, min, max).then((x) => x.map(serializer.deserialize));
//
//  /// Wrapper for [RawRedisCommands.zrevrangeWithScores].
//  Future<Map<Object,double>> zrevrangeWithScores(String setId, int min, int max) => raw.zrevrangeWithScores(setId, min, max).then(toScoreMap);
//
//  /// Wrapper for [RawRedisCommands.zrangebyscore].
//  Future<List<Object>> zrangebyscore(String setId, num min, num max, [int skip, int take]) => raw.zrangebyscore(setId, min, max, skip, take).then((x) => x.map(serializer.deserialize));
//
//  /// Wrapper for [RawRedisCommands.zrangebyscoreWithScores].
//  Future<Map<Object,double>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => raw.zrangebyscoreWithScores(setId, min, max, skip, take).then(toScoreMap);
//
//  /// Wrapper for [RawRedisCommands.zrevrangebyscore].
//  Future<List<List<int>>> zrevrangebyscore(String setId, num min, num max, [int skip, int take]) => raw.zrevrangebyscore(setId, min, max, skip, take);
//
//  /// Wrapper for [RawRedisCommands.zrevrangebyscoreWithScores].
//  Future<List<List<int>>> zrevrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) => raw.zrevrangebyscoreWithScores(setId, min, max, skip, take);
//
//  Future<int> zremrangebyrank(String setId, int min, int max) => connection.sendExpectInt([RedisCommand.ZREMRANGEBYRANK, _keyBytes(setId), serializer.serialize(min), serializer.serialize(max)]);
//
//  Future<int> zremrangebyscore(String setId, num min, num max) => connection.sendExpectInt([RedisCommand.ZREMRANGEBYSCORE, _keyBytes(setId), serializer.serialize(min), serializer.serialize(max)]);
//
//  Future<int> zcard(String setId) => connection.sendExpectInt([RedisCommand.ZCARD, _keyBytes(setId)]);
//
//  /// Wrapper for [RawRedisCommands.zscore].
//  Future<double> zscore(String setId, Object value) => raw.zscore(setId, serializer.serialize(value));
//
//  Future<int> zunionstore(String intoSetId, List<String> setIds) {
//    setIds.insert(0, setIds.length.toString());
//    setIds.insert(0, intoSetId);
//    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.ZUNIONSTORE, setIds));
//  }
//
//  Future<int> zinterstore(String intoSetId, List<String> setIds) {
//    setIds.insert(0, setIds.length.toString());
//    setIds.insert(0, intoSetId);
//    return connection.sendExpectInt(_CommandUtils.mergeCommandWithStringArgs(RedisCommand.ZINTERSTORE, setIds));
//  }
//
//
//
//
//  /// HASH
//  /// ====
//
//
//  /// Wrapper for [RawRedisCommands.hset].
//  Future<bool> hset(String hashId, String key, Object value) => raw.hset(hashId, key, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.hsetnx].
//  Future<bool> hsetnx(String hashId, String key, Object value) => raw.hsetnx(hashId, key, serializer.serialize(value));
//
//  /// Wrapper for [RawRedisCommands.hmset].
//  Future hmset(String hashId, Map<String,Object> map) => raw.hmset(hashId, map.keys.map(serializer.serialize), map.values.map(serializer.serialize));
//
//  Future<int> hincrby(String hashId, String key, int incrBy) => connection.sendExpectInt([RedisCommand.HINCRBY, _keyBytes(hashId), _keyBytes(key), serializer.serialize(incrBy)]);
//
//  Future<double> hincrbyfloat(String hashId, String key, double incrBy) => connection.sendExpectDouble([RedisCommand.HINCRBYFLOAT, _keyBytes(hashId), _keyBytes(key), serializer.serialize(incrBy)]);
//
//  /// Wrapper for [RawRedisCommands.hget].
//  Future<Object> hget(String hashId, String key) => raw.hget(hashId, key).then(serializer.deserialize);
//
//  /// Wrapper for [RawRedisCommands.hmget].
//  Future<List<Object>> hmget(String hashId, List<String> keys) => raw.hmget(hashId, keys).then((x) => x.map(serializer.deserialize));
//
//  Future<int> hdel(String hashId, String key) => connection.sendExpectInt([RedisCommand.HDEL, _keyBytes(hashId), _keyBytes(key)]);
//
//  Future<bool> hexists(String hashId, String key) => connection.sendExpectIntSuccess([RedisCommand.HEXISTS, _keyBytes(hashId), _keyBytes(key)]);
//
//  Future<int> hlen(String hashId) => connection.sendExpectInt([RedisCommand.HLEN, _keyBytes(hashId)]);
//
//  Future<List<String>> hkeys(String hashId) => connection.sendExpectMultiData([RedisCommand.HKEYS, _keyBytes(hashId)]).then((bytes) => bytes.map((x) => new String.fromCharCodes(x)));
//
//  /// Wrapper for [RawRedisCommands.hvals].
//  Future<List<Object>> hvals(String hashId) => raw.hvals(hashId).then((x) => x.map(serializer.deserialize));
//
//  /// Wrapper for [RawRedisCommands.hgetall].
//  Future<Map<String,Object>> hgetall(String hashId) => raw.hgetall(hashId).then(toMap);
//


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

