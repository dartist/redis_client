DartRedisClient
===============

An Async Redis client for Dart.

### Currently in development...
The Redis Client is functional, but only a subset of Redis API is implemented - the rest will be added over the next few days.

This is a close port of the [C# ServiceStack Redis Client](https://github.com/ServiceStack/ServiceStack.Redis/) the primary difference is all operations are non-blocking and return Futures.

Current interfaces implemented:

## RedisNativeClient
Is a low-level interface providng raw byte access to Redis operations:

    interface RedisNativeClient default _RedisNativeClient {
      RedisNativeClient([String connStr]);
      
      Future<int> get dbsize();
      Future<int> get lastsave();
      Future flushdb();
      Future flushall();
      Future<Map> get info();
      Future<bool> get ping();  
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
      
      void close();
    }

## RedisClient

Is a high-level interface with pluggable encoders/decoders providing high-level String and JSON-encoded values by default.

    interface RedisClient default _RedisClient {
      RedisClient([String connStr]);
      RedisNativeClient get raw();
      
      Future<Date> get lastsave();

      Future<String> get(String key);
      Future<String> getset(String key, String value);
      Future set(String key, String value);
      Future setex(String key, int expireInSecs, String value);
      Future psetex(String key, int expireInMs, String value);
      Future mset(Map map);
      Future<bool> msetnx(Map map);
     
      void close();
    }

## Example Usage

    RedisClient client = new RedisClient();

    client.set("key", "value")
      .then((_) => client.get("key").then( (val) => print("GET key = $val") );
    
More examples can be found in [RedisClientTests.dart](https://github.com/mythz/DartRedisClient/blob/master/tests/RedisClientTests.dart)

## Redis Connection Strings
The redis clients above take a single connection string containing the password, host, port and db in the following formats:

    pass@host:port/db
    pass@host:port
    pass@host
    host
    null => localhost:6379/0

Valid example:
    
    RedisClient client = new RedisClient("password@localhost:6379/0");
