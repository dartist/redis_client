import "DUnit.dart";
import "RedisConnectionTests.dart";
import "RedisClientTests.dart";
import "JsonEncoderTests.dart";
import "UseCaseTests.dart";

main () {
  
  RedisConnectionTests();
  UseCaseTests();
  JsonEncoderTests();
  RedisClientTests();

  runAllTests(hidePassedTests:false);
}
