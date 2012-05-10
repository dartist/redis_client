DartRedisClient
===============

An Async Redis client for Dart.
This is a close port of the [C# ServiceStack Redis Client](https://github.com/ServiceStack/ServiceStack.Redis/) except all operations return futures and are non-blocking.

In development...

Current interfaces implmented:

## RedisClient
Is a high-level interface providing convenient **String** values for all operations accepting byte values.

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
      
      //Keys
      Future<String> type(String key);
      Future<List<int>> get(String key);
      Future<List<int>> getset(String key, List<int> value);
      Future set(String key, List<int> value);
      Future<int> strlen(String key);
      Future setex(String key, int expireInSecs, List<int> value);
      Future psetex(String key, int expireInMs, List<int> value);
      Future<bool> persist(String key);
      Future mset(List<List<int>> keys, List<List<int>> values);
      Future<bool> msetnx(List<List<int>> keys, List<List<int>> values);
      Future<int> del(String key);
      Future<int> mdel(List<String> keys);
      
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
