import "connection_settings_tests.dart" as connectionSettingsTests;
import "redis_serializer_tests.dart" as redisSerializerTests;
import "redis_client_tests.dart" as redisClientTests;
import "redis_connection_tests.dart" as redisConnectionTests;
import "redis_protocol_transformer_tests.dart" as redisProtocolTransformerTests;


main() {

//  Logger.root.level = Level.FINEST;
//  Logger.root.onRecord.listen((LogRecord record) {
//    print(record.message);
//  });

  connectionSettingsTests.main();

  redisSerializerTests.main();

  redisClientTests.main();

  redisConnectionTests.main();

  redisProtocolTransformerTests.main();

}