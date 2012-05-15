#import("../DUnit.dart");
#import("RedisConnectionTests.dart");
#import("RedisClientTests.dart");
#import("JsonEncoderTests.dart");
#import("UseCaseTests.dart");
#import("../RedisConnection.dart");
#import("../RedisClient.dart");

main () {
  RedisConnectionTests();
  JsonEncoderTests();
  RedisClientTests();
//  UseCaseTests();

  runAllTests(hidePassedTests:false);
}
