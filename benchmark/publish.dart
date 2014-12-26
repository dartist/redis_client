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

    final count = 5000;
    int matched = count;
    final watch = new Stopwatch()..start();

    bool allAccountedFor() => matched == 0;

    final f = RedisClient
      .connect('localhost:6379')
      .then((RedisClient redisClient) {
        List<Future> futures = [];

        for(int i=0; i<count; i++) {
          futures.add(redisClient
              .publish('CHAN', '$i=>$datum')
              .then((_) => matched--));
        }

        Future
          .wait(futures)
          .then((_) => print('''
Time: ${watch.elapsed}
Total published: $count
All Accounted For: ${allAccountedFor()}
'''));

        redisClient.close();
      });
  }
}

main() {
  new PublishBenchmark().run();
}