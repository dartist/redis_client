import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:redis_client/redis_client.dart';
import 'package:redis_client/redis_protocol_transformer.dart';
import 'dart:async';

class PublishBenchmark extends BenchmarkBase {

  PublishBenchmark() : super('PublishBenchmark');

  void run() {
    final datum = '''
{
    "id": 1,
    "name": "A green door",
    "price": 12.50,
    "tags": ["home", "green"]
}''';

    final count = 100;
    List<Future> futures = [];

    final f = RedisClient
      .connect('localhost:6379')
      .then((RedisClient redisClient) {
        for(int i=0; i<10000; i++) {
          redisClient
          .publish('CHAN', '$i=>$datum')
          .then((_) => null);
        }
        redisClient.close();
      });

    Future
      .wait([f])
      .then((_) => null);

  }
}

main() {
  new PublishBenchmark().run();
}