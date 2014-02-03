import "connection_settings_tests.dart" as connectionSettingsTests;
import "redis_serializer_tests.dart" as redisSerializerTests;
import "redis_client_tests.dart" as redisClientTests;
import "redis_connection_tests.dart" as redisConnectionTests;
import "redis_protocol_transformer_tests.dart" as redisProtocolTransformerTests;
import "redis_pubsub_tests.dart" as redisPubSubTests;


main() {

//  Logger.root.level = Level.FINEST;
//  Logger.root.onRecord.listen((LogRecord record) {
//    print(record.message);
//  });

  connectionSettingsTests.main();

  redisSerializerTests.main();

  ///this seems to not work on Linux/64 Redis 2.6.13 
  ///error msg: https://gist.github.com/tomaszkubacki/8783531
  redisClientTests.main();

  redisConnectionTests.main();

  redisProtocolTransformerTests.main();
  
  redisPubSubTests.main();
  

}