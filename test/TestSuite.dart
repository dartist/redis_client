import "DUnit.dart";
import "RedisConnectionTests.dart";
import "RedisClientTests.dart";
import "JsonEncoderTests.dart";
import "UseCaseTests.dart";
import "package:dartredisclient/redis_client.dart";

main () {
  
  RedisConnectionTests();
  JsonEncoderTests();
  RedisClientTests();
  UseCaseTests();

  runAllTests(hidePassedTests:false);
}
