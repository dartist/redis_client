part of redis_client;

const exclusive = '(';

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


  //TODO: (Baruch) refactor to serializer
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
  /// SET
  /// ===

  /**
   *  Returns all the elements of the set.
   *  
   *  This has the same effect as running SINTER with one argument key
   */
  Future<Set<Object>> smembers(String setId) => 
      connection.sendCommand(RedisCommand.SMEMBERS, 
          [setId]).receiveMultiBulkSetDeserialized(serializer);
  
  
  /**
   * Returns the number of elements that were added to the set, not including all the 
   * elements already present in the set.
   * 
   * Adds the specified members to the set stored at key. Specified members that are 
   * already a member of this set are ignored. If key does not exist, a new set is 
   * created before adding the specified members. 
   * An error is returned when the value stored at key is not a set.
   */
  Future<int> sadd(String setId, Object value) => 
      connection.sendCommandWithVariadicValues(RedisCommand.SADD, 
          [ setId ], serializer.serializeToList(value) ).receiveInteger();
  
  /**
   * Returns the number of members that were removed from the set, not including 
   * non existing members.
   * 
   * Remove the specified members from the set stored at key. 
   * Specified members that are not a member of this set are ignored. 
   * If key does not exist, it is treated as an empty set and this command returns 0.
   * An error is returned when the value stored at key is not a set.
   */
  Future<int> srem(String setId, Object value) => 
      connection.sendCommandWithVariadicValues(RedisCommand.SREM, 
          [ setId ], serializer.serializeToList(value)).receiveInteger();
  
  /**
   * Returns the removed element, or nil when key does not exist.
   * Removes and returns a random element from the set value stored at key.
   * This operation is similar to SRANDMEMBER, that returns a random element
   * from a set but does not remove it.
   */
  Future<Object> spop(String setId) => 
      connection.sendCommand(RedisCommand.SPOP, [ setId ])
        .receiveBulkDeserialized(serializer);
      
  /**
   * Returns an int, specifically:
   * 1 if the element is moved.
   * 0 if the element is not a member of source and no operation was performed.
   * 
   * Move member from the set at source to the set at destination. This 
   * operation is atomic. In every given moment the element will appear 
   * to be a member of source or destination for other clients.
   * If the source set does not exist or does not contain the specified 
   * element, no operation is performed and 0 is returned. 
   * Otherwise, the element is removed from the source set and added to the 
   * destination set. 
   * When the specified element already exists in the destination set, it is 
   * only removed from the source set. 
   * 
   * An error is returned if source or destination does not hold a set value.
   */  
  Future<bool> smove(String fromSetId, String toSetId, Object value) => 
      connection.sendCommand(RedisCommand.SMOVE, 
          [ fromSetId, toSetId, serializer.serializeToString(value)]).receiveBool();

  /**
   * Returns the cardinality (number of elements) of the set, or 0 if key 
   * does not exist. 
   */
  Future<int> scard(String setId) => 
      connection.sendCommand(RedisCommand.SCARD, [ setId ]).receiveInteger();
  
  /**
   * Returns an int, specifically:
   * 1 if the element is a member of the set.
   * 0 if the element is not a member of the set, or if key does not exist.
   */
  Future<bool> sismember(String setId, Object value) => 
      connection.sendCommand(RedisCommand.SISMEMBER, 
          [ setId, serializer.serializeToString(value) ]).receiveBool();
    
  /**
   * Returns the members of the set resulting from the intersection of all 
   * the given sets. For example:
   * 
   *     key1 = {a,b,c,d}
   *     key2 = {c}
   *     key3 = {a,c,e}
   *     SINTER key1 key2 key3 = {c}
   *     
   * Keys that do not exist are considered to be empty sets. With one of the 
   * keys being an empty set, the resulting set is also empty (since set 
   * intersection with an empty set always results in an empty set).
   */
  Future<Set<Object>> sinter(List<String> setIds) =>
      connection.sendCommand(RedisCommand.SINTER, 
          serializer.serializeToList(setIds))
            .receiveMultiBulkSetDeserialized(serializer);

  /**
   * Returns the number of elements in the resulting set.
   * 
   * This command is equal to SINTER, but instead of returning the resulting 
   * set, it is stored in [destination]. If destination already exists, it 
   * is overwritten.
   */
  Future<int> sinterstore(String destination, List<String> setIds) => 
      connection.sendCommandWithVariadicValues(RedisCommand.SINTERSTORE, 
          [ destination ], serializer.serializeToList(setIds)).receiveInteger();
      
  /**
   * Returns the members of the set resulting from the union of all the given sets.
   * For example: 
   * 
   *     key1 = {a,b,c,d}
   *     key2 = {c}
   *     key3 = {a,c,e}
   *     SUNION key1 key2 key3 = {a,b,c,d,e}
   * 
   * Keys that do not exist are considered to be empty sets.
   */
  Future<Set<Object>> sunion(List<String> setIds) => 
      connection.sendCommand(RedisCommand.SUNION,
          serializer.serializeToList(setIds))
            .receiveMultiBulkSetDeserialized(serializer);


  /**
   * Returns the number of elements in the resulting set.
   * 
   * This command is equal to SUNION, but instead of returning the resulting set, it is stored in [destination].
   * If destination already exists, it is overwritten.
   */  
  Future<int> sunionstore(String destination, List<String> setIds) =>
      connection.sendCommandWithVariadicValues(RedisCommand.SUNIONSTORE, 
          [ destination ], serializer.serializeToList(setIds)).receiveInteger();

  /**
   * Returns the members of the set resulting from the difference between the
   * first set and all the successive sets. For example:
   * 
   *     key1 = {a,b,c,d}    
   *     key2 = {c}
   *     key3 = {a,c,e}
   *     SDIFF key1 key2 key3 = {b,d}
   *     
   * Keys that do not exist are considered to be empty sets.
   */
  Future<Set<Object>> sdiff(String fromSetId, List<String> withSetIds) => 
      connection.sendCommandWithVariadicValues(RedisCommand.SDIFF, 
          [ fromSetId ], serializer.serializeToList(withSetIds)).receiveMultiBulkSetDeserialized(serializer);

  /**
   * Returns the number of elements in the resulting set.
   * 
   * This command is equal to SDIFF, but instead of returning the resulting 
   * set, it is stored in destination. 
   * 
   * If destination already exists, it is overwritten.
   */
  
  Future<int> sdiffstore(String destination, List<String> setIds) =>
      connection.sendCommandWithVariadicValues(RedisCommand.SDIFFSTORE, 
          [ destination ], serializer.serializeToList(setIds)).receiveInteger();

  /**
   * Returns without the additional count argument the command returns a 
<<<<<<< HEAD
   * Bulk Reply wit`h the randomly selected element, or nil when key does
=======
   * Bulk Reply with the randomly selected element, or nil when key does
>>>>>>> 9d565a7f1b4258af5d9354a5ce8dda23916f95f8
   * not exist. Multi-bulk reply: when the additional count argument is 
   * passed the command returns an array of elements, or an empty array 
   * when key does not exist.
   * 
   * When called with just the key argument, return a random element from the 
   * set value stored at key.
   * 
   * More at: http://redis.io/commands/srandmember
   */
  Future<Object> srandmember(String setId, [int count]) { 
    if(count == null) return connection.sendCommand(RedisCommand.SRANDMEMBER, 
        [ setId ]).receiveBulkDeserialized(serializer);
    return connection.sendCommand(RedisCommand.SRANDMEMBER, 
        [ setId, serializer.serializeToString(count)])
          .receiveMultiBulkSetDeserialized(serializer);
  }
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
  /// SORTED SETS
  /// ===========

  /**
   * Returns the number of elements added to the sorted sets, not including 
   * elements already existing for which the score was updated.
   * 
   * Adds all the specified members with the specified scores to the sorted 
   * set stored at key. It is possible to specify multiple score/member pairs. 
   * If a specified member is already a member of the sorted set, the score is 
   * updated and the element reinserted at the right position to ensure the 
   * correct ordering. If key does not exist, a new sorted set with the 
   * specified members as sole members is created, like if the sorted set was 
   * empty. If the key exists but does not hold a sorted set, an error is 
   * returned.
   */
  Future<int> zadd(Object setId, Iterable<ZSetEntry> zset) => 
      connection.sendCommandWithVariadicValues(RedisCommand.ZADD, 
          [ serializer.serializeToString(setId) ], serializer.serializeFromZSet(zset)).receiveInteger();
  
  /**
   * Returns the number of elements added to the sorted sets, not including 
   * elements already existing for which the score was updated.
   * 
   * Single add variant of zadd.
   */
  Future<int> zsadd(Object setId, num score, Object value) => 
      connection.sendCommand(RedisCommand.ZADD, 
          [ serializer.serializeToString(setId), serializer.serializeToString(score), 
            serializer.serializeToString(value)] ).receiveInteger();


  /**
   * Returns the number of members removed from the sorted set, not including 
   * non existing members. 
   */
  Future<int> zsrem(Object setId, Object value) => 
      connection.sendCommand(RedisCommand.ZREM, 
          [ serializer.serializeToString(setId), serializer.serializeToString(value) ]).receiveInteger();
  
  /**
   * Returns the number of members removed from the sorted set, not including 
   * non existing members. 
   * 
   * 
   */
  Future<int> zmrem(Object setId, Iterable value) => 
      connection.sendCommandWithVariadicValues(RedisCommand.ZREM, 
          [ serializer.serializeToString(setId)], serializer.serializeToList(value) ).receiveInteger();
  
    
  /**
   *  Returns the new score of member (a double precision floating point number).
   *  
   *  Increments the score of member in the sorted set stored at key by 
   *  [increment]. If member does not exist in the sorted set, it is added 
   *  with increment as its score (as if its previous score was 0.0). If key 
   *  does not exist, a new sorted set with the specified member as its sole 
   *  member is created.
   *  
   *  An error is returned when key exists but does not hold a sorted set. 
   *  The score value should be the string representation of a numeric value, 
   *  and accepts double precision floating point numbers. It is possible to 
   *  provide a negative value to decrement the score.
   */  
  Future<double> zincrby(String setId, num increment, Object value) => 
      connection.sendCommand(RedisCommand.ZINCRBY, 
          [ setId, increment.toString(), serializer.serializeToString(value) ])
            .receiveDouble();

  /**
   * Returns the rank of member in the sorted set stored at key, with the 
   * scores ordered from low to high. The rank (or index) is 0-based, which 
   * means that the member with the lowest score has rank 0. 
   * 
   * Use ZREVRANK to get the rank of an element with the scores ordered from 
   * high to low.
   */  
  Future<int> zrank(String setId, Object value) => 
      connection.sendCommand(RedisCommand.ZRANK, 
          [ setId, serializer.serializeToString(value) ]).receiveInteger();
  
  /**
   * Returns the rank of member in the sorted set stored at key, with the 
   * scores ordered from high to low. The rank (or index) is 0-based, which 
   * means that the member with the highest score has rank 0. 
   * 
   * Use ZREVRANK to get the rank of an element with the scores ordered from 
   * high to low.
   */  
  Future<int> zrevrank(String setId, Object value) => 
      connection.sendCommand(RedisCommand.ZREVRANK, 
          [ setId, serializer.serializeToString(value) ]).receiveInteger();
  
  /**
   * Returns either a list of elements in the specified range or a map of elements with their 
   * scores. Depending on whether the [withScores] flag was set to true.
   *   
   * The elements are considered to be ordered from the lowest to the highest 
   * score. Lexicographical order is used for elements with equal score. 
   * 
   * Read more at: http://redis.io/commands/zrange
   */
  Future<dynamic> zrange(Object setId, int min, int max, { bool withScores: false }) { 
      return withScores
          ? connection.sendCommand(RedisCommand.ZRANGE, 
              [ serializer.serializeToString(setId), min.toString(), max.toString(), 'WITHSCORES' ])
                .receiveMultiBulkMapDeserialized(serializer)
          : connection.sendCommand(RedisCommand.ZRANGE, 
              [ serializer.serializeToString(setId), min.toString(), max.toString() ])
                .receiveMultiBulkSetDeserialized(serializer);
  }
  
  /**
   * Returns either a list of elements in the specified range or a map of 
   * elements with their scores. Depending on whether the [withScores] flag 
   * was set to true.
   *   
   * The elements are considered to be ordered from the lowest to the highest 
   * score. Lexicographical order is used for elements with equal score. 
   * 
   * Read more at: http://redis.io/commands/zrange
   */
  Future<dynamic> zrevrange(String setId, int min, int max, 
      { bool withScores: false }) { 
    return withScores 
        ? connection.sendCommand(RedisCommand.ZREVRANGE, 
            [ setId, min.toString(), max.toString(), 'WITHSCORES' ])
              .receiveMultiBulkMapDeserialized(serializer)
        : connection.sendCommand(RedisCommand.ZREVRANGE, 
            [ setId, min.toString(), max.toString() ])
              .receiveMultiBulkSetDeserialized(serializer);
  }
  
  /**
   * Returns all the elements in the sorted set at key with a score between min
   * and max (including elements with score equal to min or max). The elements 
   * are considered to be ordered from low to high scores.
   * 
   * 
   * More at: http://redis.io/commands/zrangebyscore
   */
  Future<dynamic> zrangebyscore(String setId, { num min, num max, 
    bool minExclusive: false, bool maxExclusive: false, 
    bool withScores: false, int skip, int take}) {
    var hasLimit = false, offsetString, countString;

    if (take != null) hasLimit = true;
    
    if (hasLimit) {
      skip == null ? offsetString == 0.toString() : offsetString = skip.toString();
      countString = take.toString(); 
    }
    
    if (withScores && hasLimit) {      
      return connection.sendCommand(RedisCommand.ZRANGEBYSCORE, 
          [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive),
            'WITHSCORES', 'LIMIT', offsetString, countString ])
            .receiveMultiBulkMapDeserialized(serializer);
    }
    if (hasLimit) {
      return connection.sendCommand(RedisCommand.ZRANGEBYSCORE, 
          [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive),
            'LIMIT', offsetString, countString ])
            .receiveMultiBulkSetDeserialized(serializer);
    }
    if (withScores) {
      return connection.sendCommand(RedisCommand.ZRANGEBYSCORE, 
        [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive), 'WITHSCORES' ])
          .receiveMultiBulkMapDeserialized(serializer);
    }
    return connection.sendCommand(RedisCommand.ZRANGEBYSCORE, 
        [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive) ])
          .receiveMultiBulkSetDeserialized(serializer);
  }

  /**
   * Returns all the elements in the sorted set at key with a score between 
   * max and min (including elements with score equal to max or min). 
   * In contrary to the default ordering of sorted sets, for this command the 
   * elements are considered to be ordered from high to low scores.
   * 
   * The elements having the same score are returned in reverse lexicographical order.
   * 
   * Apart from the reversed ordering, ZREVRANGEBYSCORE is similar to ZRANGEBYSCORE.
   */
  Future<dynamic> zrevrangebyscore(String setId, { num min, num max, 
    bool minExclusive: false, bool maxExclusive: false, 
    bool withScores: false, int skip, int take}) {
    var hasLimit = false, offsetString, countString;

    if (take != null) hasLimit = true;
    
    if (hasLimit) {
      skip == null ? offsetString == 0.toString() : offsetString = skip.toString();
      countString = take.toString(); 
    }
    
    if (withScores && hasLimit) {      
      return connection.sendCommand(RedisCommand.ZREVRANGEBYSCORE, 
          [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive),
            'WITHSCORES', 'LIMIT', offsetString, countString ])
            .receiveMultiBulkMapDeserialized(serializer);
    }
    if (hasLimit) {
      return connection.sendCommand(RedisCommand.ZREVRANGEBYSCORE, 
          [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive),
            'LIMIT', offsetString, countString ])
            .receiveMultiBulkSetDeserialized(serializer);
    }
    if (withScores) {
      return connection.sendCommand(RedisCommand.ZREVRANGEBYSCORE, 
        [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive), 'WITHSCORES' ])
          .receiveMultiBulkMapDeserialized(serializer);
    }
    return connection.sendCommand(RedisCommand.ZREVRANGEBYSCORE, 
        [ setId, _setMin(min, minExclusive), _setMax(max, maxExclusive) ])
          .receiveMultiBulkSetDeserialized(serializer);
    }

  /**
   * Returns the number of elements removed.
   * 
   * Removes all elements in the sorted set stored at key with rank between 
   * start and stop. Both start and stop are 0 -based indexes with 0 being 
   * the element with the lowest score. These indexes can be negative numbers,
   * where they indicate offsets starting at the element with the highest 
   * score. 
   * 
   * For example: -1 is the element with the highest score, -2 the 
   * element with the second highest score and so forth.
   */
  Future<int> zremrangebyrank(String setId, int min, int max) =>
      connection.sendCommand(RedisCommand.ZREMRANGEBYRANK, 
          [ setId, min.toString(), max.toString()])
            .receiveInteger();
  
  
  /**
   * Returns the number of elements removed
   * 
   * Removes all elements in the sorted set stored at key with a score between 
   * min and max (inclusive). Since version 2.1.6, min and max can be 
   * exclusive, following the syntax of ZRANGEBYSCORE.
   */
  Future<int> zremrangebyscore(String setId, { num min, num max, 
    bool minExclusive: false, bool maxExclusive: false}) {    
    return connection.sendCommand(RedisCommand.ZREMRANGEBYSCORE, [ setId, 
      _setMin(min, minExclusive), _setMax(max, maxExclusive)]).receiveInteger();
  }
  
 /**
  * Returns the cardinality (number of elements) of the sorted set, or 0 if key
  * does not exist. 
  */
  Future<int> zcard(String setId) => 
      connection.sendCommand(RedisCommand.ZCARD, [ setId ] )
        .receiveInteger();
  
  /**
   * Returns the score of member in the sorted set at key. If member does not 
   * exist in the sorted set, or key does not exist, nil is returned.
   */
  Future<double> zscore(String setId, Object value) => 
      connection.sendCommand(RedisCommand.ZSCORE, 
          [ setId, serializer.serializeToString(value) ]).receiveDouble();

  /**
   * Returns the number of elements in the resulting sorted set at destination.
   * 
   * Computes the union of the sets given in [setIds], optionally takes a list 
   * of sequentially added [weights] for each set in the [aggregate] 
   * calculation (default SUM, options SUM|MIN|MAX)
   * 
   * More at: http://redis.io/commands/zunionstore
   */  
  Future<int> zunionstore(String destination, List<String> setIds, { List<int> weights, String aggregate}) {
    var numkeys = setIds.length.toString();
    var values = serializer.serializeToList(setIds);
    
    if(weights != null) {
      values.add('WEIGHTS');
      values.addAll(serializer.serializeToList(weights));
    }
    
    if(aggregate != null) {
      values.add('AGGREGATE');
      values.add('$aggregate');
    }
    
    return connection.sendCommandWithVariadicValues(RedisCommand.ZUNIONSTORE, 
        [ destination, numkeys ],  values).receiveInteger();
  }
  
  /**
   * Returns the number of elements in the resulting sorted set at destination.
   * 
   * Computes the intersection of the sets given in [setIds], optionally takes a list 
   * of sequentially added [weights] for each set in the [aggregate] 
   * calculation (default SUM, options SUM|MIN|MAX)
   * 
   * More at: http://redis.io/commands/zunionstore
   */  
  Future<int> zinterstore(String destination, List<String> setIds, { List<String> weights, String aggregate}) {
    var numkeys = setIds.length.toString();
    var values = serializer.serializeToList(setIds);
    
    if(weights != null) {
      values.add('WEIGHTS');
      values.addAll(serializer.serializeToList(weights));
    }
    
    if(aggregate != null) {
      values.add('AGGREGATE');
      values.add('$aggregate');
    }
    
    return connection.sendCommandWithVariadicValues(RedisCommand.ZINTERSTORE, 
        [ destination, numkeys ],  values).receiveInteger();
  }
  
  String _setMin(num min, bool minExclusive) {
    var minString;
    if (minExclusive) {
      min == null ? minString = '-inf' : minString = exclusive + min.toString();
    } else { 
      min == null ? minString = '-inf' : minString = min.toString(); 
    }
    return minString;
  }
  
  String _setMax(num max, bool maxExclusive) {
    var maxString;
    if(maxExclusive) {
      max == null ? maxString = '+inf' : maxString = exclusive + max.toString();
    } else { 
      max == null ? maxString = '+inf' : maxString = max.toString(); 
    }
    return maxString;
  }
  /// HASH
  /// ====

  /**
   * Returns bool reply.
   * Sets the specified fields to their respective values in the hash stored 
   * at [key]. This command overwrites any existing fields in the hash. If key
   * does not exist, a new key holding a hash is created.
   */
  Future<bool> hset(String hashId, String key, Object value) => 
      connection.sendCommand(RedisCommand.HSET, 
          [ hashId, key, serializer.serializeToString(value) ]).receiveBool();
  /**
   * Returns: true if field is a new field in the hash and value was set. 
   * False if field already exists in the hash and no operation was performed.
   * 
   * Sets field in the hash stored at key to value, only if field does not yet 
   * exist. If key does not exist, a new key holding a hash is created. 
   * 
   * If field already exists, this operation has no effect.
   */
  Future<bool> hsetnx(String hashId, String key, Object value) => 
      connection.sendCommandWithVariadicValues(RedisCommand.HSETNX, [ key ], 
          serializer.serializeToList(value)).receiveBool();
  
  /**
   * Sets the specified fields to their respective values in the hash stored 
   * at key. This command overwrites any existing fields in the hash. 
   * If key does not exist, a new key holding a hash is created.
   * 
   */
  Future hmset(String hashId, Map<String,Object> map) => 
      connection.sendCommandWithVariadicValues(RedisCommand.HMSET, 
          [ hashId ], serializer.serializeToList(map)).receiveStatus('OK');

  /**
   * Returns the value at field after the increment operation.
   * 
   * Increments the number stored at field in the hash stored at key by 
   * increment. If key does not exist, a new key holding a hash is created.
   *  If field does not exist the value is set to 0 before the operation is 
   *  performed. 
   *  
   *  The range of values supported by HINCRBY is limited to 64 bit signed 
   *  integers.
   */
  Future<int> hincrby(String hashId, String key, int incrBy) => 
      connection.sendCommand(RedisCommand.HINCRBY, 
          [ hashId, key, incrBy.toString() ])
            .receiveInteger();
  
  /**
   * Returns the value at field after the increment operation.
   * 
   * Increment the specified field of an hash stored at key, and representing a 
   * floating point number, by the specified increment. If the field does not 
   * exist, it is set to 0 before performing the operation. An error is 
   * returned if one of the following conditions occur:
   * 
   *     - The field contains a value of the wrong type (not a string).
   *     - The current field content or the specified increment are not parsable as
   *     a double precision floating point number.
   */  
  Future<double> hincrbyfloat(String hashId, String key, double incrBy) => 
      connection.sendCommand(RedisCommand.HINCRBYFLOAT, 
          [ hashId, key, incrBy.toString() ]).receiveDouble();

  /**
   * Returns the value associated with field in the hash stored at key or nil 
   * when field is not present in the hash or key does not exist 
   */
  Future<Object> hget(String hashId, String key) => 
      connection.sendCommand(RedisCommand.HGET, [ hashId, key ])
        .receiveBulkDeserialized(serializer);

  /**
   * Returnsthe values associated with the specified fields in the hash stored 
   * at key. For every field that does not exist in the hash, a nil value is 
   * returned. Because a non-existing keys are treated as empty hashes, 
   * running HMGET against a non-existing key will return a list of nil values.
   */
  Future<List<Object>> hmget(String hashId, List<Object> keys) => 
      connection.sendCommandWithVariadicValues(RedisCommand.HMGET, 
          [ hashId ], serializer.serializeToList(keys) )
            .receiveMultiBulkDeserialized(serializer);

  /**
   *  the number of fields that were removed from the hash, not including 
   *  specified but non existing fields.
   *  
   *  Removes the specified fields from the hash stored at key. Specified 
   *  fields that do not exist within this hash are ignored.
   *  If key does not exist, it is treated as an empty hash and this command 
   *  returns 0.
   */
  Future<int> hdel(String hashId, String key) => 
      connection.sendCommand(RedisCommand.HDEL, 
          [ hashId, key ]).receiveInteger();

  /**
   * Returns if [field] is an existing [field] in the hash stored at key.
   * 
   * True if the hash contains [field].
   * False if the hash does not contain [field], or key does not exist.
   */
  Future<bool> hexists(String hashId, String field) => 
      connection.sendCommand(RedisCommand.HEXISTS, 
          [ hashId, field ]).receiveBool();

  /**
   * Returns the number of fields contained in the hash stored at key
   * or 0 when key does not exist.
   */
  Future<int> hlen(String hashId) => 
      connection.sendCommand(RedisCommand.HLEN, [ hashId ]).receiveInteger();

  /**
   * Returns list of fields in the hash, or an empty list when key does not exist.
   */
  Future<List<String>> hkeys(String hashId) => 
      connection.sendCommand(RedisCommand.HKEYS, [ hashId ])
        .receiveMultiBulkDeserialized(serializer);

  /**
   * Returns list of values in the hash, or an empty list when key does not 
   * exist.
   */
  Future<List<Object>> hvals(String hashId) => 
      connection.sendCommand(RedisCommand.HVALS, [ hashId ])
        .receiveMultiBulkDeserialized(serializer);

  /**
   * Returns map of fields and their values stored in the hash, or an empty 
   * map when key does not exist.
   */
  Future<Map<String, Object>> hgetall(String hashId) => 
      connection.sendCommand(RedisCommand.HGETALL, [ hashId ])
        .receiveMultiBulkMapDeserialized(serializer);

}


class RedisClientException implements Exception {

  String message;

  RedisClientException(this.message);

  String toString() => "RedisClientException: $message";

}


