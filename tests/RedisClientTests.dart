#library("RedisConnectionTests");
#import("../DUnit.dart");
#import("../RedisConnection.dart");
#import("../RedisNativeClient.dart");
#import("../RedisClient.dart");
#import("dart:io");

RedisClientTests (){

  module("RedisClient");

  var client = new RedisClient();
  client.raw.flushall();
  
  test("Connected: connected", (){
    client.set("key", "value")
      .then((_){
        print("set key value");

        client.get("key")
         .then((res) => print("GET key = $res"));
        
        client.raw.dbsize.then((keysCount) => print("DBSIZE: $keysCount key(s)"));
        
        client.raw.lastsave.then((int lastSave) => print("LASTSAVE(raw): $lastSave"));
        
        client.lastsave.then((Date lastSave) => print("LASTSAVE: $lastSave"));
        
        client.raw.info.then((Map info) => print("INFO: $info"));

        client.raw.ping.then((bool success) => print("PING: $success"));
        
        client.raw.type("key").then((String type) => print("TYPE: $type"));
        
        client.raw.strlen("key").then((int len) => print("STRLEN: of 'key' is $len chars"));
        
      });
    
    client.get("unknownKey").then((val) => print("GET unknownKey = $val"));
    
    client.setex("keyEx", 1, "expires in 1 sec")
    .then((_){
      client.get("keyEx").then((val) => print("SETEX (0s): keyEx = $val"));
      new Timer(1500, (__) => client.get("keyEx").then((val) => print("SETEX (1.5s): keyEx = $val")) );        
    });
  
    client.psetex("keyExMs", 1000, "expires in 1 sec")
    .then((_){
      client.get("keyExMs").then((val) => print("PSETEX (0s): keyExMs = $val"));
      new Timer(1500, (__) => client.get("keyExMs").then((val) => print("PSETEX (1.5s): keyExMs = $val")) );        
    });
  
    client.setex("persistKeyEx", 1, "should stay persisted")
    .then((_){
      client.raw.persist("persistKeyEx").then((val) => print("PERSIST (0s): persistKeyEx = $val"));
      new Timer(1500, (__) => client.get("persistKeyEx").then((val) => print("PERSIST (1.5s): persistKeyEx = $val")) );        
    });
    
    var map = {'MSET-A':1,'MSET-B':2,'MSET-C':3,'MSET-D':4,'MSET-E':5};
    client.mset(map).then((_){
      client.get('MSET-A').then((val) => print("MSET: MSET-A = $val"));
      client.get('MSET-B').then((val) => print("MSET: MSET-B = $val"));
      client.get('MSET-C').then((val) => print("MSET: MSET-C = $val"));
      client.get('MSET-D').then((val) => print("MSET: MSET-D = $val"));
      client.get('MSET-E').then((val) => print("MSET: MSET-E = $val"));
      
      client.raw.del("MSET-A").then((count) => 
          client.get('MSET-A').then((val) => print("DEL($count): MSET-A = $val")) );
      
      client.raw.mdel(["MSET-C","MSET-D"]).then((count) {
        client.get('MSET-C').then((val) => print("MDEL ($count): MSET-C = $val"));
        client.get('MSET-D').then((val) => print("MDEL ($count): MSET-D = $val"));
      });
    });
    
    client.getset("getsetkey", "A")
      .then((val) {
        print("GETSET: getsetkey = $val");
        client.getset("getsetkey", "B")
          .then((val2) => print("GETSET: getsetkey = $val2"));
      });
    
    client.raw.incr("counter")
      .then((counter){
        print("INCR: counter to $counter");
        
        client.raw.incrby("counter", 10)
          .then((counter2){
            print("INCRBY: counter to $counter2");
                        
            client.raw.decr("counter")
            .then((counter4){
              print("DECR: counter to $counter4");
              
              client.raw.decrby("counter", 5)
                .then((counter5) => print("DECRBY: counter to $counter5"));
            });
          });
      });

    client.raw.incrbyfloat("floatcounter", .5) 
      .then((counter3) => print("INCRBYFLOAT: floatcounter to $counter3"));            
    
  });
  
  new Timer(5000, (_) => client.close() );
  
}
