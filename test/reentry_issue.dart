import "package:dartredisclient/redis_client.dart";

main() {
  print("main():");

  RedisClient client = new RedisClient();
  client.flushall();
  client.info.then((info) {
    client.close();
  });
}