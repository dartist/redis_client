import 'package:benchmark_harness/benchmark_harness.dart';
import '../lib/redis_client.dart';
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

    final count = 50000;
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

Future bechmarkIncr(int n){
  const String key = "key";
  return RedisClient.connect('localhost:6379')
  .then((RedisClient client) {
    client.set(key, "0");
    int start = new DateTime.now().millisecondsSinceEpoch;
    for(int i=1;i<=n;++i){
      client.incr(key).then((v){
        if(v != i)
           throw "incr value is $v instead of $i";
      });
    }
    return client.get(key).then((v){
      if(int.parse(v) != n)
        throw "incr value is $v instead of $n";
      int stop = new DateTime.now().millisecondsSinceEpoch;
      double diff = (stop-start)/1000;
      double perf =  n/diff;
      print("performance of incr is ${perf} operations per sec");
      client.close();
    });
  });
}


Future bechmarkPingPong(int n){
  int count = n;
  return RedisClient.connect('localhost:6379')
  .then((RedisClient client) {
    int start = new DateTime.now().millisecondsSinceEpoch;
    return Future.doWhile((){
      return client.ping().then((_){
        --count;
        return count>0;
      });
    }).then((_){
      int stop = new DateTime.now().millisecondsSinceEpoch;
      double diff = (stop-start)/1000;
      double perf =  n/diff;
      print("performance of pingpong is ${perf} operations per sec");
      client.close();
    });
  });
}

main() {
  bechmarkIncr(100000)
  .then((_){
    return bechmarkPingPong(100000);
  })
  .then((_){
    return new PublishBenchmark().run();
  });
}