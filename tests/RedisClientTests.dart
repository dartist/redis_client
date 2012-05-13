#library("RedisConnectionTests");
#import("../DUnit.dart");
#import("../RedisConnection.dart");
#import("../RedisNativeClient.dart");
#import("../RedisClient.dart");
#import("dart:io");

RedisClientTests (){
  bool runLongRunningTests = false;

  var client = new RedisClient();

  module("RedisClient",
    startup:(Function cb) {
      client.raw.flushall().then(cb);
    });

  asyncTest("KEYS: GET, SET, GETSET", (){
    client.set("key", "value").then((_){
      client.get("key").then((res) {
         equal(res, "value", "GET, SET");
       });

      client.get("unknownKey").then((val) =>
        equal(val,null,"GET unknown key is null"));
    });

    client.getset("getsetkey", "A").then((val) {
        isNull(val, "GETSET: non-existing key returns null");
        client.getset("getsetkey", "B").then((val2) {
          equal(val2, "A", "GETSET: returns previous value");
          start();
        });
      });
  });

  asyncTest("KEYS: MSET, MGET, DEL, MDEL", (){
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
        client.get('MSET-D').then((val) {
          isNull(val, "MDEL delets key");
          start();
        });
      });
    });
  });

  if (runLongRunningTests) {
    asyncTest("KEYS: Expiring keys: SETEX, PSETEX, PERSIST", (){
      client.setex("keyEx", 1, "expires in 1 sec").then((_){
        client.get("keyEx").then((val) => isNotNull(val,"SETEX: doesn't expire immediately"));
        new Timer(1500, (__) => client.get("keyEx").then((val) =>
            isNull(val,"SETEX: expires after 1s")));
      });

      client.psetex("keyExMs", 1000, "expires in 1 sec").then((_){
        client.get("keyExMs").then((val) => isNotNull(val,"PSETEX: doesn't expire immediately"));
        new Timer(2000, (__) => client.get("keyExMs").then((val) =>
            isNull(val,"PSETEX: expires after 1000ms")));
      });

      client.setex("persistKeyEx", 1, "should stay persisted")
      .then((_){
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

    client.raw.incrbyfloat("floatcounter", .5)
      .then((floatcounter) => equal(floatcounter, .5, "INCRBYFLOAT"));

    client.incr("counter").then((counter){
      equal(counter, 1, "INCR increments a non-existant key to 1");

      client.incrby("counter", 10).then((counter2){

        equal(counter2, 1 + 10, "INCRBY increments existing key");

        client.decr("counter").then((counter3){
          equal(counter3, 1 + 10 - 1, "DECR decrements existing key");

          client.raw.decrby("counter", 5).then((counter4){
            equal(counter4, 1 + 10 - 1 - 5, "DECRBY decrements existing key");
            start();
          });
        });
      });
    });
  });


//
//  test("Connected: connected", (){
//    int asyncCalls = 0;
//    Function cb = (ignore) => if (--asyncCalls == 0) start();
//
//    client.set("key", "value")
//      .then((_){
//        print("set key value");
//
//        client.get("key")
//         .then((res) => print("GET key = $res"));
//
//        client.raw.dbsize.then((keysCount) => print("DBSIZE: $keysCount key(s)"));
//
//        client.raw.lastsave.then((int lastSave) => print("LASTSAVE(raw): $lastSave"));
//
//        client.lastsave.then((Date lastSave) => print("LASTSAVE: $lastSave"));
//
//        client.raw.info.then((Map info) => print("INFO: $info"));
//
//        client.raw.ping().then((bool success) => print("PING: $success"));
//
//        client.raw.type("key").then((String type) => print("TYPE: $type"));
//
//        client.raw.strlen("key").then((int len) => print("STRLEN: of 'key' is $len chars"));
//
//      });
//
//    client.get("unknownKey").then((val) => print("GET unknownKey = $val"));
//
//    client.setex("keyEx", 1, "expires in 1 sec")
//    .then((_){
//      client.get("keyEx").then((val) => print("SETEX (0s): keyEx = $val"));
//      new Timer(1500, (__) => client.get("keyEx").then((val) => print("SETEX (1.5s): keyEx = $val")) );
//    });
//
//    client.psetex("keyExMs", 1000, "expires in 1 sec")
//    .then((_){
//      client.get("keyExMs").then((val) => print("PSETEX (0s): keyExMs = $val"));
//      new Timer(1500, (__) => client.get("keyExMs").then((val) => print("PSETEX (1.5s): keyExMs = $val")) );
//    });
//
//    client.setex("persistKeyEx", 1, "should stay persisted")
//    .then((_){
//      client.raw.persist("persistKeyEx").then((val) => print("PERSIST (0s): persistKeyEx = $val"));
//      new Timer(1500, (__) => client.get("persistKeyEx").then((val) => print("PERSIST (1.5s): persistKeyEx = $val")) );
//    });
//
//    var map = {'MSET-A':1,'MSET-B':2,'MSET-C':3,'MSET-D':4,'MSET-E':5};
//    client.mset(map).then((_){
//      client.get('MSET-A').then((val) => print("MSET: MSET-A = $val"));
//      client.get('MSET-B').then((val) => print("MSET: MSET-B = $val"));
//      client.get('MSET-C').then((val) => print("MSET: MSET-C = $val"));
//      client.get('MSET-D').then((val) => print("MSET: MSET-D = $val"));
//      client.get('MSET-E').then((val) => print("MSET: MSET-E = $val"));
//
//      client.raw.del("MSET-A").then((count) =>
//          client.get('MSET-A').then((val) => print("DEL($count): MSET-A = $val")) );
//
//      client.raw.mdel(["MSET-C","MSET-D"]).then((count) {
//        client.get('MSET-C').then((val) => print("MDEL ($count): MSET-C = $val"));
//        client.get('MSET-D').then((val) => print("MDEL ($count): MSET-D = $val"));
//      });
//    });
//
//    client.getset("getsetkey", "A")
//      .then((val) {
//        print("GETSET: getsetkey = $val");
//        client.getset("getsetkey", "B")
//          .then((val2) => print("GETSET: getsetkey = $val2"));
//      });
//
//    client.raw.incr("counter")
//      .then((counter){
//        print("INCR: counter to $counter");
//
//        client.raw.incrby("counter", 10)
//          .then((counter2){
//            print("INCRBY: counter to $counter2");
//
//            client.raw.decr("counter")
//            .then((counter4){
//              print("DECR: counter to $counter4");
//
//              client.raw.decrby("counter", 5)
//                .then((counter5) => print("DECRBY: counter to $counter5"));
//            });
//          });
//      });
//
//    client.raw.incrbyfloat("floatcounter", .5)
//      .then((counter3) => print("INCRBYFLOAT: floatcounter to $counter3"));
//
//  });
//
//  asyncTest("async 1", (){
//    new Timer(1000, (_) {
//      ok(true,"is true");
//      start();
//    });
//  });
//
//  asyncTest("async 2", (){
//    new Timer(1000, (_) {
//      ok(true,"is true");
//      start();
//    });
//  });
//
//  new Timer(5000, (_) {
//    print(client.raw.stats);
//    client.close();
//  });

  new Timer(3000, (_) {
    print("\nRedisClient stats:");
    print(client.raw.stats);
    client.close();
  });
}
