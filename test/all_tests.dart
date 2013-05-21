
import "connection_settings_test.dart" as connectionSettingsTests;
import "redis_client_tests.dart" as redisClientTests;
import "redis_connection_tests.dart" as redisConnectionTests;
import "redis_protocol_transformer_tests.dart" as redisProtocolTransformerTests;


main() {

  connectionSettingsTests.main();

  redisClientTests.main();

  redisConnectionTests.main();

  redisProtocolTransformerTests.main();

}