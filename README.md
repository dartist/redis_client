Dart Redis Client
=================

A high-performance async/non-blocking Redis client for Dart.

The client is well tested including UTF-8 support.

As all operations are async they return [Futures](http://api.dartlang.org/dart_core/Future.html) for better handling of asynchronous operations. 

### v0.1 Released

The Redis Client API is now feature complete with support for all ADMIN tasks as well as all KEYS, LISTS, SETS, SORTED SETS and HASH collections [including tests for all operations](https://github.com/Dartist/RedisClient/blob/master/test/RedisClientTests.dart).

Follow [@demisbellot](http://twitter.com/demisbellot) for project updates.

## Adding Dependencies with Pubspec


```yaml 
dependencies:
  dartredisclient:
    git: git://github.com/Dartist/RedisClient.git
```

 
## Example Usage


> This example is deprecated. Coming soon!

```dart

  RedisClient client = new RedisClient("password@localhost:6379/0");

  var items = ["B","A","A","C","D","B","E"];
  var itemScores = {"B":2,"A":1,"C":3,"D":4,"E":5};

  client.smadd("setId", items);
  client.smembers("setId").then((members) => print("setId contains: $members"));
  client.mrpush("listId", items);
  client.lrange("listId").then((items) => print("listId contains: $items"));
  client.hmset("hashId", itemScores);
  client.hmget("hashId", ["A","B","C"]).then((values) => print("selected hashId values: $values"));
  client.zmadd("zsetId", itemScores);
  client.zrangeWithScores("zsetId", 1, 3).then((map) => print("ranked zsetId entries: $map"));
  client.zrangebyscoreWithScores("zsetId", 1, 3).then((map) => print("scored zsetId entries: $map"));

  var users = [{"name":"tom","age":29},{"name":"dick","age":30},{"name":"harry","age":31}];
  users.forEach((x) => client.set("user:${x['name']}", x['age']));
  client.keys("user:*").then((keys) => print("keys matching user:* $keys"));

  client.info.then((info) {
      print("Redis Server info: $info");
      print("Redis Client info: ${client.raw.stats}");
      start();
  });

```


Which generates the following output:

```
  setId contains: [A, B, C, D, E]
  listId contains: [B, A, A, C, D, B, E]
  selected hashId values: [1, 2, 3]
  ranked zsetId entries: {C: 3.0, D: 4.0, B: 2.0}
  scored zsetId entries: {A: 1.0, C: 3.0, B: 2.0}
  keys matching user:* [user:tom, user:dick, user:harry]

  Redis Server info: {# Server: null, redis_version: 2.5.9, ... db0: keys=7,expires=0}
  Redis Client info: {rewinds: 0, reads: 246, bytesRead: 3152, bufferWrites: 239, flushes: 14, bytesWritten: 740}
```

More examples can be found in 150+ tests in [RedisClientTests.dart](https://github.com/Dartist/RedisClient/blob/master/tests/RedisClientTests.dart) - [latest testrun](https://gist.github.com/2698702).

## API


The full API will be online soon. Stay tuned.


## Redis Connection Strings

The redis clients above take a single connection string containing the password, host, port and db in the following formats:

    pass@host:port/db
    pass@host:port
    pass@host
    host
    null => localhost:6379/0

Valid example:

```dart    
RedisClient client = new RedisClient("password@localhost:6379/0");
```

## RoadMap

### v0.2.0 release (2-4 weeks)

After the v1.0 release we'll start work on implementing the remaining functionality:
  - Transactions, Pub/Sub, Lua/Scripts

### v0.3.0 release (future)

Adding automatic failover support in v3.0, sharding, fast RPC direct-pipeline using the Redis wire format with node.js/C# processes

## Contributors

  - [mythz](https://github.com/mythz) (Demis Bellot)
  - [financeCoding](https://github.com/financeCoding) (Adam Singer)
  - [enyo](https://github.com/enyo) (Matias Meno)


### Feedback 

Feedback and contributions are welcome.

