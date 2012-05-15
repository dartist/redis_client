#library("RedisConnectionTests");
#import("../DUnit.dart");
#import("../Mixin.dart");
#import("../RedisConnection.dart");
#import("../RedisNativeClient.dart");
#import("../RedisClient.dart");
#import("dart:io");

UseCaseTests() {

  RedisClient client = new RedisClient();

  module("UseCases");

  asyncTest("Simple Demo",(){
    var items = ["B","A","A","C","D","B","E"];
    var itemScores = {"B":2,"A":1,"C":3,"D":4,"E":5};

    client.smadd("setId", items);
    client.smembers("setId").then((members) => print("setId contains: $members"));
    client.mrpush("listId", items);
    client.lrange("listId").then((items) => print("listId contains: $items"));
    client.hmset("hashId", itemScores);
    client.hmget("hashId", ["A","B","C"]).then((values) => print("selected hashId values: $values"));
    client.zmadd("zsetId", itemScores);
    client.zrangeWithScores("zsetId", 1, 3).then((map) => print("ranked zsetId entries: $map"));
    client.zrangebyscoreWithScores("zsetId", 1, 3).then((map) => print("scored zsetId entries: $map"));

    var users = [{"name":"tom","age":29},{"name":"dick","age":30},{"name":"harry","age":31}];
    users.forEach((x) => client.set("user:${x['name']}", x['age']));
    client.keys("user:*").then((keys) => print("keys matching user:* $keys\n"));

    client.info.then((info) {
      print("Redis Server info: $info");
      print("Redis Client info: ${client.raw.stats}");
      start();
      client.close();
    });
  });

}
