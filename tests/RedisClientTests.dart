#library("RedisConnectionTests");
#import("../DUnit.dart");
#import("../Mixin.dart");
#import("../RedisConnection.dart");
#import("../RedisNativeClient.dart");
#import("../RedisClient.dart");
#import("dart:io");

RedisClientTests (){
  bool runLongRunningTests = true;

  RedisClient client = new RedisClient();

  module("RedisClient",
    startup:(Function cb) {
      client.raw.flushall().then(cb);
    });

  asyncTest("Connection: db SELECT", (){
    var conn = new RedisClient("localhost:6379/0");
    conn.set("dbKey", "db0").then((_){
      conn.select(1).then((_2) {
        conn.set("dbKey", "db1").then((_3) {
          conn.get("dbKey").then((val1) {
            equal(val1, "db1", "SELECT: can get key from db1");
            conn.select(0).then((_4) {
              conn.get("dbKey").then((val2) {
                equal(val2, "db0", "SELECT: can get key from db0");
                //conn.info.then((info) => print("INFO after SELECT : $info"));
                var db1Conn = new RedisClient("localhost:6379/1");
                db1Conn.get("dbKey").then((val3) {
                  equal(val3, "db1", "SELECT: can get key from db1 connection");
                  start();
                });
              });
            });
          });
        });
      });
    });
  });

  asyncTest("KEYS: GET, SET, GETSET RANDOMKEY RENAME RENAMENX TTL PTTL", (){
    client.set("key", "value").then((_){
      client.get("key").then((res) {
         equal(res, "value", "GET, SET");
       });

      client.get("unknownKey").then((val) =>
        equal(val,null,"GET unknown key is null"));

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

      Date in1Sec = new Date.now().add(new Duration(0, 0, 0, 1, 0));
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

  asyncTest("SETS: SMEMBERS, SADD, SREM, SPOP, SMOVE, SCARD, SISMEMBER"
    ", SINTER, SINTERSTORE, SUNION, SUNIONSTORE, SDIFFSTORE, SRANDMEMBER", (){
      List items = ["A","B","C","D"];
      List items2 = ["C","D","E","F"];
      client.smembers("setkey").then((x) => equal(x.length, 0, "SMEMBERS empty set returns 0 results"));
      client.msadd("setkey",items).then((itemsLen) {
        equal(itemsLen, items.length, "MSADD returns set length");
        client.srandmember("setkey").then((x) => ok(items.indexOf(x)>=0, "SRANDMEMBER returns item from existing set"));
        client.scard("setkey").then((len) => equal(len, items.length, "SCARD length of existing set"));
        client.spop("setkey").then((popped) {
          ok(items.indexOf(popped)>=0, "SPOP pops from existing set");
          client.scard("setkey").then((len) => equal(len, items.length-1, "SCARD length of existing set"));
          client.sadd("setkey", popped);
          client.smembers("setkey").then((x) => deepEqual($(x).sort(), items, "SADD adds to existing set"));
          client.sismember("setkey", "F").then((exists) => ok(!exists, "SISMEMBER false for non-member"));
          client.sismember("setkey", "A").then((exists) => ok(exists, "SISMEMBER true for member"));

          client.msadd("setkey2",items2).then((_){
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

  new Timer(3000, (_) {
    print("\nRedisClient stats:");
    print(client.raw.stats);
    client.close();
  });
}
