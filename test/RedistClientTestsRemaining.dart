library RedisClientTests;

import "dart:io";
import "dart:isolate";
import "DUnit.dart";
import "package:dartmixins/mixin.dart";
import "package:redis_client/redis_client.dart";

RedisClientTests (){
  bool runLongRunningTests = true;

  RedisClient client = new RedisClient();

  module("RedisClient",
    setUp:(Function cb) {
      client.raw.flushall().then((_){
        cb();
      });
    },
    tearDownFixture:(){
      print("\nRedisClient stats:");
      print(client.raw.stats);
      client.close();
    });


  asyncTest("KEYS: GET, SET, GETSET RANDOMKEY RENAME RENAMENX TTL PTTL", (){
    client.set("key", "value").then((_){

      client.randomkey().then((key) => ok(["key","getsetkey"].indexOf(key) >= 0, "RANDOMKEY"));

      client.rename("key", "renamedKey");
      client.get("renamedKey").then((val) => equal(val, "value", "RENAME existing key"));
      client.set("key2", "value2");
      client.renamenx("renamedKey", "key2").then((success) => ok(!success, "RENAMENX does not rename non-existant key"));
      client.renamenx("renamedKey", "re-RenamedKey").then((success) =>
        ok(success, "RENAMENX does rename existing key"));

      client.getset("getsetkey", "A").then((val) {
          isNull(val, "GETSET: non-existing key returns null");

          client.getset("getsetkey", "B").then((val2) {
            equal(val2, "A", "GETSET: returns previous value");
            start();
          });
        });
    });
  });

  asyncTest("KEYS: MSET, MSETNX, MGET, DEL, MDEL", (){
    var map = {'MSET-A':1,'MSET-B':2,'MSET-C':3,'MSET-D':4,'MSET-E':5};
    client.mset(map).then((_){
      client.mget(['MSET-A','MSET-B','MSET-C','MSET-D','MSET-E']).then((values) =>
          deepEqual(values, [1,2,3,4,5], "MSET/MGET can set multiple values"));

      client.del("MSET-A").then((count){
        equal(count,1,"DEL returns number of deleted keys");
        client.get('MSET-A').then((val) => isNull(val, "DEL delets key"));
      });

      client.mdel(["MSET-C","MSET-D"]).then((count) {
        equal(count,2,"DEL returns number of multiple deleted keys");
        client.get('MSET-C').then((val) => isNull(val, "MDEL delets key"));
        client.get('MSET-D').then((val) => isNull(val, "MDEL delets key"));

        client.msetnx(map).then((success) => ok(!success, "MSETNX - doesn't set map if some keys exist"));

        Map mapnx = {};
        map.forEach((k,v) => mapnx["NX$k"] = v);
        client.msetnx(mapnx).then((success) {
          ok(success, "MSETNX - sets map when all keys don't exist");
          start();
        });
      });
    });
  });

  if (runLongRunningTests) {
    asyncTest("KEYS: Expiring keys: SETEX, PSETEX, PERSIST EXPIRE PEXPIRE EXPIREAT PEXPIREAT", (){
      client.setex("keyEx", 1, "expires in 1 sec").then((_){
        client.get("keyEx").then((val) => isNotNull(val,"SETEX: doesn't expire immediately"));
        new Timer(1500, (__) => client.get("keyEx").then((val) =>
            isNull(val,"SETEX: expires after 1s")));
      });

      client.set("key", "expires in 1 sec");
      client.expire("key",1).then((_){
        client.get("key").then((val) => isNotNull(val,"EXPIRE: doesn't expire immediately"));
        new Timer(1500, (__) => client.get("key").then((val) =>
            isNull(val,"EXPIRE: expires after 1s")));
      });

      client.set("pkey", "expires in 1 sec");
      client.pexpire("pkey",1000).then((_){
        client.get("pkey").then((val) => isNotNull(val,"PEXPIRE: doesn't expire immediately"));
        new Timer(1500, (__) => client.get("pkey").then((val) =>
            isNull(val,"PEXPIRE: expires after 1s")));
      });

      Date in1Sec = new Date.now().add(new Duration(seconds: 1));
      client.set("keyAt", "expires in 1 sec");
      client.expireat("keyAt", in1Sec).then((_){
        client.get("keyAt").then((val) => isNotNull(val,"EXPIREAT: doesn't expire immediately"));
        new Timer(1500, (__) => client.get("keyAt").then((val) =>
            isNull(val,"EXPIREAT: expires after 1s")));
      });
      client.set("pkeyAt", "expires in 1 sec");
      client.pexpireat("pkeyAt", in1Sec).then((_){
        client.get("pkeyAt").then((val) => isNotNull(val,"PEXPIREAT: doesn't expire immediately"));
        new Timer(1500, (__) => client.get("pkeyAt").then((val) =>
            isNull(val,"EXPIREAT: expires after 1s")));
      });

      client.setex("ttlkey",10,"expire in 10 secs");
      client.ttl("ttlkey").then((ttlSecs) {
        ok(ttlSecs <= 10, "TTL $ttlSecs < 10s");
      });
      client.ttl("ttlkey").then((ttlMs) {
        ok(ttlMs <= 10000, "TTL $ttlMs < 10ms");
      });

      client.psetex("keyExMs", 1000, "expires in 1 sec").then((_){
        client.get("keyExMs").then((val) => isNotNull(val,"PSETEX: doesn't expire immediately"));
        new Timer(1500, (__) => client.get("keyExMs").then((val) =>
            isNull(val,"PSETEX: expires after 1000ms")));
      });

      client.setex("persistKeyEx", 1, "should stay persisted").then((_){
        client.persist("persistKeyEx").then((val) => isNotNull(val,"PERSIST: returns un-expired value"));
        new Timer(1500, (__) => client.get("persistKeyEx").then((val) {
          isNotNull(val,"PERSIST: persist expiry key stays persisted");
          start();
        }));
      });

    });
  }

  asyncTest("ADMIN: ", (){
    client.set("key", "value").then((_){
      client.exists("key").then((exists) => ok(exists, "EXIST"));
      client.exists("nonExistingKey").then((exists) => ok(!exists, "!EXIST"));

      client.get("key").then((res) {

        client.dbsize.then((keysCount) => equal(keysCount, 1, "DBSIZE") );

        client.save().then((__){
          client.lastsave.then((Date lastSave) {
            Date now = new Date.now();
            int timeSinceLastSaveSecs = (now.difference(lastSave)).inSeconds;
            ok(timeSinceLastSaveSecs < 2, "SAVE, LASTSAVE");
          });
        });

        client.info.then( (Map info) => ok(info.length > 0, "INFO") );

        client.ping().then((bool success) => ok(success, "PING"));

        client.echo("hello").then((String val) => equal(val, "hello", "ECHO"));

        client.type("key").then((String type) => equal(type,"string", "TYPE"));

        client.strlen("key").then((int len) => equal(len, "value".length, "STRLEN"));

        client.flushdb().then((__) {
          client.dbsize.then((keysCount) {
            equal(keysCount, 0, "FLUSHDB");
            start();
          });
        });
      });
    });
  });

  asyncTest("KEYS: Increments INCR, INCRBY, DECR, DECRBY, INCRBYFLOAT",(){

    client.incrbyfloat("floatcounter", .5)
      .then((floatcounter) => equal(floatcounter, .5, "INCRBYFLOAT"));

    client.incr("counter").then((counter){
      equal(counter, 1, "INCR increments a non-existant key to 1");

      client.incrby("counter", 10).then((counter2){

        equal(counter2, 1 + 10, "INCRBY increments existing key");

        client.decr("counter").then((counter3){
          equal(counter3, 1 + 10 - 1, "DECR decrements existing key");

          client.decrby("counter", 5).then((counter4){
            equal(counter4, 1 + 10 - 1 - 5, "DECRBY decrements existing key");
            start();
          });
        });
      });
    });
  });

  asyncTest("KEYS: String fns for APPEND SUBSTR GETRANGE SETRANGE GETBIT SETBIT",(){
    client.strlen("alpha").then((len) => equal(len, 0, "STRLEN on non-existing key"));
    client.set("alpha", "ABC");
    client.strlen("alpha").then((len) => equal(len, "ABC".length, "STRLEN existing key"));
    client.append("alpha", "DEF").then((len) => equal(len, "ABCDEF".length, "APPEND existing key"));
    client.substr("alpha", 2,4).then((val) => equal(val, "ABCDEF".substring(2,4+1), "SUBSTR"));
    client.getrange("alpha", 2,4).then((val) => equal(val, "ABCDEF".substring(2,4+1), "GETRANGE"));
    client.setrange("alpha", 2,"00").then((len){
      client.get("alpha").then((val){
        equal(val, "AB00EF", "SETRANGE");
      });
    });
    client.setbit("bits", 5, 1).then((oldBit) {
      equal(oldBit, 0, "SETBIT oldbit on new key == 0");
    });
    client.getbit("bits", 4).then((bit) => equal(bit, 0, "GETBIT preceeding bits are filled with '0'"));
    client.getbit("bits", 5).then((bit){
      equal(bit,1, "GETBIT");
      start();
    });
  });

  asyncTest("SETS: ", (){
      List items = ["A","B","C","D"];
      List items2 = ["C","D","E","F"];
      client.smembers("setkey").then((x) => equal(x.length, 0, "SMEMBERS empty set returns 0 results"));
      client.smadd("setkey",items).then((itemsLen) {
        equal(itemsLen, items.length, "smadd returns set length");
        client.srandmember("setkey").then((x) => ok(items.indexOf(x)>=0, "SRANDMEMBER returns item from existing set"));
        client.scard("setkey").then((len) => equal(len, items.length, "SCARD length of existing set"));
        client.spop("setkey").then((popped) {
          ok(items.indexOf(popped)>=0, "SPOP pops from existing set");
          client.scard("setkey").then((len) => equal(len, items.length-1, "SCARD length of existing set"));
          client.sadd("setkey", popped);
          client.smembers("setkey").then((x) => deepEqual($(x).sort(), items, "SADD adds to existing set"));
          client.sismember("setkey", "F").then((exists) => ok(!exists, "SISMEMBER false for non-member"));
          client.sismember("setkey", "A").then((exists) => ok(exists, "SISMEMBER true for member"));

          client.smadd("setkey2",items2).then((_){
            client.sinter(["setkey","setkey2"]).then((intersect) => deepEqual($(intersect).sort(), ["C","D"], "SINTER"));
            client.sinterstore("inter",["setkey","setkey2"]).then((len) => equal(len, 2, "SINTERSTORE returns length"));
            client.smembers("inter").then((intersect) => deepEqual($(intersect).sort(), ["C","D"], "SINTERSTORE at key"));
            client.sunion(["setkey","setkey2"]).then((union) => deepEqual($(union).sort(), ["A","B","C","D","E","F"], "SUNION"));
            client.sunionstore("union",["setkey","setkey2"]).then((len) => equal(len, 6, "SUNIONSTORE returns length"));
            client.smembers("union").then((intersect) => deepEqual($(intersect).sort(), ["A","B","C","D","E","F"], "SINTERSTORE at key"));
            client.sdiff("setkey", ["setkey2"]).then((diff) => deepEqual($(diff).sort(), ["A","B"], "SDIFF"));
            client.sdiffstore("diff","setkey", ["setkey2"]).then((len) => equal(len, 2, "SDIFFSTORE returns length"));
            client.smembers("diff").then((diff) {
              deepEqual($(diff).sort(), ["A","B"], "SDIFFSTORE at key");
              start();
            });
          });
        });
      });
  });

  asyncTest("LIST: ", (){
    List items = ["A","B","C","D"];
    client.mlpush("llistkey", items);
    client.lrange("llistkey", 0, -1).then((x) => deepEqual(x, $(items).reverse(), "LPUSH adds multiple items"));
    client.mrpush("rlistkey", items);
    client.lrange("rlistkey", 0, -1).then((x) => deepEqual(x, items, "RPUSH adds multiple items"));
    client.lrange("rlistkey", 1, 2).then((x) =>  deepEqual(x, ["B","C"], "LRANGE"));
    client.ltrim("rlistkey", 1, 2);
    client.lrange("rlistkey", 0, -1).then((x) => deepEqual(x, ["B","C"], "LTRIM"));
    client.lpush("rlistkey", "A");
    client.rpush("rlistkey", "D");
    client.lrange("rlistkey", 0, -1).then((x) => deepEqual(x, items, "RPUSH and LPUSH on same list"));
    client.lindex("rlistkey", 3).then((x) => equal(x, items[3], "LINDEX"));
    client.lset("rlistkey", 1, "b");
    client.lrange("rlistkey", 0, -1).then((x) => deepEqual(x, ["A","b","C","D"], "LSET"));
    client.lrem("llistkey", 1, "D").then((x) => equal(x, 1, "LREM returns occurances removed"));
    client.lrange("llistkey", 0, -1).then((x) => deepEqual(x, ["C","B","A"], "LREM returns item from list"));
    client.lpop("llistkey").then((x) => equal(x,"C","LPOP"));
    client.rpop("llistkey").then((x) => equal(x,"A","RPOP"));
    client.rpoplpush("llistkey", "newllistkey");
    client.lrange("newllistkey", 0, -1).then((x) => deepEqual(x, ["B"], "RPOPLPUSH"));

    client.llen("rlistkey").then((len){
      equal(len, items.length, "LLEN");
      start();
    });
  });

  asyncTest("SORTED SET: ", (){
    Map<Object,num> items = {"A":1,"B":2,"C":3,"C#":3.5,"D":4};

    client.zmadd("zsetkey", items).then((len) => equal(len, items.length, "zmadd map with int,double keys and String values"));
    client.zscore("zsetkey", "C#").then((score) => equal(score, 3.5, "ZSCORE"));
    client.zrange("zsetkey", 0, -1).then((values) => deepEqual(values, items.keys, "ZRANGE"));
    client.zrangeWithScores("zsetkey", 0, -1).then((map) => deepEqual(map, items, "ZRANGE with scores"));
    client.zrank("zsetkey", "C#").then((x) => equal(x,3,"ZRANK"));
    client.zrevrank("zsetkey", "C#").then((x) => equal(x,1,"ZREVRANK"));
    client.zmrem("zsetkey", ["B","C"]).then((len) => equal(len,2,"ZREM"));
    client.zrevrange("zsetkey", 0, -1).then((values) => deepEqual(values, ["D","C#","A"], "ZREVRANGE"));
    client.zrevrangeWithScores("zsetkey", 0, -1).then((map) => deepEqual(map, {"A":1,"C#":3.5,"D":4}, "ZREVRANGE with scores"));
    client.zrangebyscore("zsetkey", 2, 10).then((values) => deepEqual(values, ["C#","D"], "ZRANGEBYSCORE"));
    client.zrangebyscoreWithScores("zsetkey", 2, 10).then((values) => deepEqual(values, {"C#":3.5,"D":4}, "ZRANGEBYSCORE with scores"));
    client.zadd("zsetkey", 2, "B");
    client.zadd("zsetkey", 3, "C");
    client.zremrangebyrank("zsetkey", 3, 5).then((len) => equal(len,2,"ZREMRANGEBYRANK count of items removed"));
    client.zrange("zsetkey", 0, -1).then((values) => deepEqual(values, ["A","B","C"], "ZREMRANGEBYRANK remaining set"));
    client.zmadd("zsetkey", {"C#":3.5,"D":4});
    client.zremrangebyscore("zsetkey", 0.5, 2.5).then((len) => equal(len,2,"ZREMRANGEBYSCORE count of items removed"));
    client.zrange("zsetkey", 0, -1).then((values) => deepEqual(values, ["C","C#","D"], "ZREMRANGEBYRANK remaining set"));

    client.zmadd("zsetkey", {"A":1,"B":2,"C":3,"C#":3.5,"D":4});
    client.zmadd("zsetkey2", {"C#":3.5,"D":4,"E":20});
    client.zinterstore("zinter", ["zsetkey","zsetkey2"]).then((len) => equal(len,["C#","D"].length, "ZINTERSTORE returns new set count"));
    client.zrange("zinter", 0, -1).then((values) => deepEqual(values, ["C#","D"], "ZINTERSTORE new set"));
    client.zunionstore("zunion", ["zsetkey","zsetkey2"]).then((len) => equal(len,items.length + 1, "ZUNIONSTORE returns new set count"));
    client.zrange("zunion", 0, -1).then((values) => deepEqual(values, ["A","B","C","C#","D","E"], "ZUNIONSTORE new set"));

    client.zcard("zsetkey").then((len) {
      equal(len, items.length, "ZCARD");
      start();
    });

  });

  asyncTest("HASH: ", (){
    Map<String,int> items = {"A":1,"B":2,"C":3,"D":4};
    client.hmset("hashkey", items);
    client.hkeys("hashkey").then((keys) => deepEqual(keys,items.keys,"HKEYS"));
    client.hvals("hashkey").then((vals) => deepEqual(vals,items.values,"HVALS"));
    client.hgetall("hashkey").then((map) => deepEqual(map,items,"HGETALL"));
    client.hsetnx("hashkey", "D", 5).then((success) => ok(!success, "HSETNX doesn't set existing key"));
    client.hsetnx("hashkey", "E", 10).then((success) => ok(success, "HSETNX updates new key"));
    client.hset("hashkey", "E", 5).then((isNewKey) => ok(!isNewKey, "HSET sets new key"));
    client.hincrby("hashkey", "E", 2).then((x) => equal(x, 5+2, "HINCRBY existing key"));
    client.hincrbyfloat("hashkey", "E", 2.5).then((x) => equal(x, 5+2+2.5, "HINCRBYFLOAT existing key"));
    client.hget("hashkey", "C").then((x) => equal(x, 3, "HGET existing key"));
    client.hget("hashkey", "F").then((x) => isNull(x, "HGET non-existing key"));
    client.hexists("hashkey", "C").then((exists) => ok(exists, "HEXISTS existing key"));
    client.hexists("hashkey", "F").then((exists) => ok(!exists, "HEXISTS non-existing key"));
    client.hdel("hashkey", "E").then((count) => equal(count,1,"HDEL existing key"));

    client.hlen("hashkey").then((len) {
      equal(len,items.length, "HMSET count");
      start();
    });
  });

}
