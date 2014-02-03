Dart Redis Client
=================

A high-performance async/non-blocking Redis client for Dart.

The client is well tested including UTF-8 support.

As all operations are async they return [Futures](http://api.dartlang.org/dart_core/Future.html)
for better handling of asynchronous operations. 

### v0.1 Released

The Redis Client API is now feature complete with support for all ADMIN tasks as
well as all KEYS, LISTS, SETS, SORTED SETS and HASH collections
[including tests for all operations](test/).

Follow [@demisbellot](http://twitter.com/demisbellot) for project updates.

## Adding Dependencies with Pubspec


```yaml 
dependencies:
  redis_client: any
```

 
## Example Usage

```dart
import "package:redis_client/redis_client.dart";

main() {
  var connectionString = "localhost:6379";
  RedisClient.connect(connectionString)
      .then((RedisClient client) {
        // Use your client here. Eg.:
        client.set("test", "value")
            .then((_) => client.get("test"))
            .then((value) => print("success: $value"));
      });
}
```

More examples can be found in the tests in
[redis_client_tests.dart](test/redis_client_tests.dart).


## API

Please look at the [RedisClient API](http://dartist.github.io/redis_client/api/redis_client.html)
for a list of commands and usage.


## Redis Connection Strings

The redis clients above take a single connection string containing the password,
host, port and db in the following formats:

- `pass@host:port/db`
- `pass@host:port`
- `pass@host`
- `host`
- `null` results in the default string `localhost:6379/0`

Valid example:

```dart    
RedisClient.connect("password@localhost:6379/0");
```

## RedisProtocolTransformer

If you're not interested in the high level RedisClient API, you can use the
[RedisProtocolTransformer](lib/redis_protocol_transformer.dart) directly.

Just include it like this:

```dart
import "package:redis_client/redis_protocol_transformer.dart";
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
  - [bbss](https://github.com/bbss) (Baruch Berger)
  - [MaxHorstmann](https://github.com/MaxHorstmann) (Max Horstmann)
  - [tomaszkubacki](https://github.com/tomaszkubacki) (Tomasz Kubacki)

### Feedback 

Feedback and contributions are welcome.

