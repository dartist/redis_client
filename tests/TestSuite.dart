#import("../DUnit.dart");
#import("RedisConnectionTests.dart");
#import("RedisClientTests.dart");
#import("JsonEncoderTests.dart");
#import("../RedisConnection.dart");
#import("../RedisClient.dart");

main () {
  RedisConnectionTests();
  JsonEncoderTests();
  RedisClientTests();

  runAllTests(hidePassedTests:true);
}
