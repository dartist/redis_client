library redis_client_tests;

import 'dart:async';
import 'package:unittest/unittest.dart';
import 'package:redis_client/redis_client.dart';
import 'helper.dart';



main() {

  group("RedisClient", () {

    RedisClient client;

    setUp(() {
      return RedisClient.connect("127.0.0.1:6379")
          .then((c) {
            client = c;
            client.flushall();
          });
    });

    tearDown(() {
      try {
        client.close();
      }
      finally {

      }
    });

    group("select", () {
      test("should correctly switch databases", () {
        async(
          client.set("testkey", "database0") // Setting testskey in database 0
              .then((_) => client.select(1)) // Switching to databse 1
              .then((_) => client.set("testkey", "database1"))

              .then((_) => client.select(0)) // Switching back to database 0
              .then((_) => client.get("testkey"))
              .then((value) => expect(value, equals("database0")))

              .then((_) => client.select(1)) // Switching back to database 1
              .then((_) => client.get("testkey"))
              .then((value) => expect(value, equals("database1")))
        );
      });
    });

//    group("Basic commands: GET, SET, GETSET RANDOMKEY RENAME RENAMENX TTL PTTL:", () {

    group("parseInfoString()", () {
      test("should properly parse info strings", () {
        var string =  """
# Server
redis_version:2.6.2
redis_git_sha1:00000000
redis_git_dirty:0
redis_mode:standalone

# Clients
connected_clients:3
client_longest_output_list:0
client_biggest_input_buf:0
blocked_clients:0
""";

        var info = client.parseInfoString(string);
        expect(info["Server"]["redis_version"], equals("2.6.2"));
        expect(info["Clients"]["client_biggest_input_buf"], equals("0"));
      });
      test("should throw exception on invalid info", () {
        var string =  """
invalid_line:invalid            
# Server
redis_version:2.6.2
redis_git_sha1:00000000
""";
        expect(() => client.parseInfoString(string), throwsException);

        string =  """
# Server
invalid_line
""";
        expect(() => client.parseInfoString(string), throwsException);
      });

    });

    group("Admin commands:", () {
      test("DBSIZE", () {
        async(
          client.dbsize
                .then((size) => expect(size, equals(0)))
                .then((_) => client.set("test", "test"))
                .then((_) => client.set("test2", "test"))
                .then((_) => client.dbsize)
                .then((size) => expect(size, equals(2)))
        );
      });
      test("FLUSHDB", () {
        async(
          client.select(0)
              .then((_) => client.set("test", "testvalue"))
              .then((_) => client.get("test"))
              .then((value) => expect(value, equals("testvalue")))
              .then((_) => client.select(1))
              .then((_) => client.get("test"))
              .then((value) => expect(value, equals(null)))
              .then((_) => client.set("test2", "testvalue2"))
              .then((_) => client.get("test2"))
              .then((value) => expect(value, equals("testvalue2")))
              .then((_) => client.flushdb())
              .then((_) => client.get("test2"))
              .then((value) => expect(value, equals(null)))
              .then((_) => client.select(0))
              .then((_) => client.get("test"))
              .then((value) => expect(value, equals("testvalue")))
        );
      });
      test("FLUSHALL", () {
        async(
            client.select(0)
            .then((_) => client.set("test", "testvalue"))
            .then((_) => client.select(1))
            .then((_) => client.set("test2", "testvalue2"))
            .then((_) => client.flushall())
            .then((_) => client.get("test2"))
            .then((value) => expect(value, equals(null)))
            .then((_) => client.select(0))
            .then((_) => client.get("test"))
            .then((value) => expect(value, equals(null)))
        );
      });
      test("SAVE & LASTSAVE", () {
        async(
          client.save()
              .then((_) => client.lastsave)
              .then((DateTime saveTime) {
                expect(saveTime.difference(new DateTime.now()).inMilliseconds, lessThan(10));
              })
        );
      });
      test("BGSAVE", () {
        async(
          client.bgsave()
              .then((_) => client.lastsave)
              .then((DateTime saveTime) {
                expect(saveTime.difference(new DateTime.now()).inMilliseconds, lessThan(10));
              })
        );
      });
      test("INFO", () {
        async(
          client.info
              .then((infoMap) {
                expect(infoMap["Server"]["redis_version"] is String, equals(true));
                expect(infoMap["Clients"]["connected_clients"] is String, equals(true));
              })
        );
      });
      test("PING", () {
        async(
          client.ping().then((pong) => expect(pong, equals("PONG")))
        );
      });
      test("ECHO", () {
        async(
          client.echo("TEST echo")
              .then((response) => expect(response, equals("TEST echo")))
        );
      });
      test("TYPE", () {
        async(
          client.set("test1", "String")
              .then((_) => client.type("test1"))
              .then((response) => expect(response, equals("string")))
              .then((_) => client.type("testxxx"))
              .then((response) => expect(response, equals("none")))
        );
      });

    });

    group("Basic commands:", () {
      test("GET & SET", () {
        async(
          client.set("testkey", "testvalue")
              .then((_) => client.get("testkey"))
              .then((String value) => expect(value, equals("testvalue")))
              .then((_) => client.get("invalidkey"))
              .then((res) => expect(res, equals(null)))
        );
      });

      test("KEYS", () {
        async(
          client.keys("*o*")
              .then((List<String> keys) => expect(keys, equals([])))
              .then((_) => client.set("onekey", "a"))
              .then((_) => client.set("twokey", "a"))
              .then((_) => client.set("threekey", "a"))
              .then((_) => client.keys("*o*"))
              .then((List<String> keys) => expect(keys..sort((String a, b) => a. compareTo(b)), equals([ "onekey", "twokey" ])))
        );
      });

      test("GETSET", () {
        async(
          client.getset("nokeysa", "value")
              .then((String value) => expect(value, equals(null)))
              .then((_) => client.getset("nokeysa", "value2"))
              .then((String value) => expect(value, equals("value")))
         );
      });

      test("MGET", () {
        async(
          client.mget([ "a", "b", "c" ])
              .then((List<Object> objects) {
                expect(objects.length, equals(3));
                expect(objects[0], equals(null));
                expect(objects[1], equals(null));
                expect(objects[2], equals(null));
              })
              .then((_) => client.set("a", "value1"))
              .then((_) => client.set("c", "value2"))
              .then((_) => client.mget([ "a", "b", "c" ]))
              .then((List<Object> objects) {
                expect(objects.length, equals(3));
                expect(objects[0], equals("value1"));
                expect(objects[1], equals(null));
                expect(objects[2], equals("value2"));
              })
        );
      });

      test("SETEX & TTL", () {
        async(
          client.setex("testkey", 10, "value")
              .then((_) => client.ttl("testkey"))
              .then((int time) => expect(time, equals(10)))
         );
      });

      test("PSETEX", () {
        async(
            client.psetex("testkey", 10000, "value")
            .then((_) => client.ttl("testkey"))
            .then((int time) => expect(time, equals(10)))
        );
      });

      test("PERSIST", () {
        async(
            client.setex("testkey", 10, "value")
            .then((_) => client.ttl("testkey"))
            .then((int time) => expect(time, equals(10)))
            .then((_) => client.persist("testkey"))
            .then((status) => expect(status, equals(true)))
            .then((_) => client.ttl("testkey"))
            .then((int time) => expect(time, equals(-1)))
            .then((_) => client.persist("invalidkey"))
            // Should return false when the key didn't exist.
            .then((status) => expect(status, equals(false)))
        );
      });

      test("MSET", () {
        async(
            client.mset({ "key1": "test1", "key2": "true", "key3": "123" })
            .then((_) => client.get("key1"))
            .then((String value) => expect(value, equals("test1")))
            .then((_) => client.get("key2"))
            .then((String value) => expect(value, equals("true")))
            .then((_) => client.get("key3"))
            .then((String value) => expect(value, equals("123")))
        );
      });

      test("MSETNX", () {
        async(
            client.msetnx({ "key1": "test1", "key2": "true", "key3": "123" })
            .then((bool value) => expect(value, equals(true)))
            .then((_) => client.msetnx({ "key2": "test1", "randomkey": "true", "randomkey2": "123" }))
            // Should return false if **one** key already existed.
            .then((bool value) => expect(value, equals(false)))
        );
      });

      test("EXISTS", () {
        async(
            client.exists("keyname")
            .then((bool value) => expect(value, equals(false)))
            .then((_) => client.set("keyname", "test"))
            .then((_) => client.exists("keyname"))
            .then((bool value) => expect(value, equals(true)))
        );
      });

      test("DEL", () {
        async(
          client.del("keyname")
              .then((bool value) => expect(value, equals(false)))
              .then((_) => client.set("keyname", "test"))
              .then((_) => client.del("keyname"))
              .then((bool value) => expect(value, equals(true)))
        );
      });

      test("MDEL", () {
        async(
          client.mdel([ "keyname", "keyname2", "keyname3" ])
              .then((int value) => expect(value, equals(0)))
              .then((_) => client.mset({ "keyname2": "test", "keyname3": "test" }))
              .then((_) => client.mdel([ "keyname", "keyname2", "keyname3" ]))
              .then((int value) => expect(value, equals(2)))
        );
      });

      test("INCR", () {
        async(
          client.set("some-field", "12")
              .then((_) => client.incr("some-field"))
              .then((num inc) => expect(inc, equals(13)))
              .then((_) => client.get("some-field"))
              .then((String value) => expect(value, equals("13")))
        );
      });

      test("INCRBY", () {
        async(
          client.set("some-field", "12")
              .then((_) => client.incrby("some-field", 4))
              .then((num inc) => expect(inc, equals(16)))
              .then((_) => client.get("some-field"))
              .then((String value) => expect(value, equals("16")))
        );
      });

      test("INCRBYFLOAT", () {
        async(
            client.set("some-field", "12.5")
            .then((_) => client.incrbyfloat("some-field", 4.3))
            .then((double inc) => expect(inc, equals(16.8)))
            .then((_) => client.get("some-field"))
            .then((String value) => expect(value, equals("16.800000000000001")))
        );
      });


      test("DECR", () {
        async(
          client.set("some-field", "12")
              .then((_) => client.decr("some-field"))
              .then((num inc) => expect(inc, equals(11)))
              .then((_) => client.get("some-field"))
              .then((String value) => expect(value, equals("11")))
        );
      });

      test("DECRBY", () {
        async(
          client.set("some-field", "12")
              .then((_) => client.decrby("some-field", 4))
              .then((num inc) => expect(inc, equals(8)))
              .then((_) => client.get("some-field"))
              .then((String value) => expect(value, equals("8")))
        );
      });

      test("STRLEN", () {
        async(
            client.set("some-field", "somevalue")
            .then((_) => client.strlen("some-field"))
            .then((num len) => expect(len, equals(9)))
        );
      });

      test("APPEND", () {
        async(
            client.set("some-field", "somevalue")
            .then((_) => client.append("some-field", "additional"))
            .then((num len) => expect(len, equals(19)))
            .then((_) => client.get("some-field"))
            .then((val) => expect(val, equals("somevalueadditional")))
        );
      });

      test("GETRANGE", () {
        async(
            client.set("some-field", "This is a string")
              .then((_) => client.getrange("some-field", 0, 3))
              .then((String sub) => expect(sub, equals("This")))
              .then((_) => client.getrange("some-field", -3, -1))
              .then((String sub) => expect(sub, equals("ing")))
              .then((_) => client.getrange("some-field", 0, -1))
              .then((String sub) => expect(sub, equals("This is a string")))
              .then((_) => client.getrange("some-field", 10, 100))
              .then((String sub) => expect(sub, equals("string")))
        );
      });
      

  });

  group('Set commands:', () {
    test('SMEMBERS', () {
      Set<Object> objectSet = new Set()..addAll(['some-string', 'other-string']);
      
      async(
          client.sadd("setId", objectSet)
            .then((_) => client.smembers("setId")
            .then((result) => expect(result, equals(objectSet))))
      );
    });
    
    test('SADD', () {      
      async(
          client.sadd('setId', new Set()..addAll(['string', 5]))
            .then((addResult) =>
              expect(addResult, equals(2)))
      );
    });
    
    test('SREM', () {
      async(
          client.sadd('setId', 'remove-me')
            .then((_) => client.srem('setId', 'remove-me'))
            .then((remResult) => expect(remResult, equals(1)))
          );
    });
    
    test('SPOP', () {
      var list = ['some-string', 'some-other-string'];
      async(
            client.sadd('setId', list)
            .then((_) => client.spop('setId'))
            .then((popResult) => expect(list.contains(popResult), isTrue))
          );
    });
    
    test('SMOVE', () {
      var list = ['some-string', 'some-other-string'];
      var list2 = ['some-list2-string'];
      async(
            client.sadd('setId', list)
            .then((_) => client.sadd('setId2', list2))
            .then((_) => client.smove('setId', 'setId2', 'some-string'))
            .then((moveResult) => expect(moveResult, isTrue))
            .then((_) => client.smove('setId', 'setId2', 'some-string'))
            .then((moveResult) => expect(moveResult, isFalse))
          );
    }); 
    
    test('SCARD', () {      
      async(
            client.sadd('setId', ['some-string', 'some-other-string'])
            .then((_) => client.scard('setId'))
            .then((cardResult) => expect(cardResult, equals(2)))
          );
    });
    
    test('SISMEMBER', () {
      async(
          client.sadd('setId', ['some-member'])
          .then((_) => client.sismember('setId', 'some-member'))
          .then((isMemberResult) => expect(isMemberResult, isTrue))
      );
    });
    
    test('SINTER', () {
      async(
          client.sadd('setId', ['a', 'b', 'c', 'd'])
          .then((_) => client.sadd('setId2', ['c'])
          .then((_) => client.sadd('setId3', ['a', 'c', 'e'])
          .then((_) => client.sinter(['setId', 'setId2', 'setId3']))
          .then((isInterResult) => expect(isInterResult, equals(['c'])))))
      );
    });
    
    test('SINTERSTORE', () {
      async(
          client.sadd('setId', ['a', 'b', 'c', 'd'])
          .then((_) => client.sadd('setId2', ['b', 'c'])
          .then((_) => client.sinterstore('newSet', [ 'setId', 'setId2']))
          .then((interStoreResult) => expect(interStoreResult, equals(2))))
      );
    });
    
    
    test('SUNION', () {
      Set<String> unionSet = new Set()..addAll(['a', 'b', 'c', 'd', 'e']);
      async(
          client.sadd('setId', ['a', 'b', 'c', 'd'])
          .then((_) => client.sadd('setId2', ['c'])
          .then((_) => client.sadd('setId3', ['a', 'c', 'e'])
          .then((_) => client.sunion(['setId', 'setId2', 'setId3']))
          .then((isInterResult) => expect(isInterResult.containsAll(unionSet), isTrue))))
      );
    });
    
    test('SUNIONSTORE', () {
      async(
          client.sadd('setId', ['a', 'b', 'c', 'd'])
          .then((_) => client.sadd('setId2', ['b'])
          .then((_) => client.sunionstore('newSet', [ 'setId', 'setId2']))
          .then((unionStoreResult) => expect(unionStoreResult, equals(4))))
      );
    });
    
    test('SDIFF', () {
      async(
          client.sadd('setId', ['a', 'b', 'c', 'd'])
          .then((_) => client.sadd('setId2', ['c'])
          .then((_) => client.sadd('setId3', ['a', 'c', 'e'])
          .then((_) => client.sdiff('setId', [ 'setId2', 'setId3' ]))
          .then((diffResult) => expect(diffResult, equals(['b', 'd'])))))
      );
    });
    
    test('SDIFFSTORE', () {
      async(
          client.sadd('setId', ['a', 'b', 'c', 'd'])
          .then((_) => client.sadd('setId2', ['b'])
          .then((_) => client.sdiffstore('newSet', [ 'setId', 'setId2']))
          .then((unionStoreResult) => expect(unionStoreResult, equals(3))))
      );
    });
    
    test('SRANDMEMBER', () {
      var list = ['one', 'two', 'three'];
      async(
            client.sadd('setId', list)
            .then((_) => client.srandmember('setId')
            .then((srandmemberResult) {
              expect(list.contains(srandmemberResult), isTrue);
              client.srandmember('setId', 2)
              .then((srandmemberResult2) => expect(srandmemberResult2.length, equals(2)));
              })
            ));
    });
  });

  group('Hash commands:', () {
    test('HSET', () {
      async(
          client.hset('hashKey', 'key1', 'value')
          .then((hSetResult)  => expect(hSetResult, isTrue))
      );
    });

    test('HSETNX', () {
      async(
          client.hset('hashKey', 'key1', 'value')
          .then((hSetResult)  {            
            client.hset('hashKey', 'key1', 'value')
              .then((hSetResult)  => 
              expect(hSetResult, isFalse));
            expect(hSetResult, isTrue);
          })
      );
    });
    
    test('HMSET', () {
      Map hashMap = new Map();
      hashMap['key1'] = 'value';
      hashMap['key2'] = 'value2';
      async(
          client.hmset('hashKey', hashMap)
          .then((hSetResult)  => expect(hSetResult, equals('OK')))
      );
    });
    
    test('HINCRBY', () {
      async(
          client.hset('hashId', 'field', 5)
          .then((_) => client.hincrby('hashId', 'field', -1)
          .then((hIncrResult) => expect(hIncrResult, equals(4))))
      );
    });
    
    test('HINCRBYFLOAT', () {
      async(
          client.hset('hashId', 'field', 10.50)
          .then((_) => client.hincrbyfloat('hashId', 'field', 0.1)
          .then((incrByFloatResult) => expect(incrByFloatResult, equals(10.6))))
          );      
    });
    
    test('HGET', () {
      Map someMap = {'some-key' : 'some-value'};
      async(
          client.hset('hashId', 'field', someMap)
          .then((_) => client.hget('hashId', 'field')
          .then((hGetResult) => expect(hGetResult, equals(someMap))))
      );
    });
    
    test('HMGET', () {
      int someInt = 4;
      String someString = 'some-string';
      async(
          client.hset('hashId', 'field', someInt)
          .then((_) => client.hset('hashId', 'field2', someString)
          .then((_) => client.hmget('hashId', [ 'field', 'field2' ])
          .then(
              (hMGetResult) { 
                expect(hMGetResult.contains(someString), isTrue);
                expect(hMGetResult.contains(someInt), isTrue);
              })))
      );
    });
    
    test('HDEL', () {
      int someInt = 4;
      String someString = 'some-string';
      async(
            client.hset('hashId', 'field', someInt)
            .then((_) => client.hdel('hashId', 'field')
            .then((hDelResult) => expect(hDelResult, equals(1))))
          );
      });

    test('HEXISTS', () {      
      async(
          client.hset('hashId', 'field', 4)
          .then((_) => client.hexists('hashId', 'field')
          .then((hExistsResult) => expect(hExistsResult, isTrue)))
      );
    });

    test('HLEN', () {
      async(
          client.hset('hashId', 'field', 4)
          .then((_) => client.hset('hashId', 'field2', 'some-string')
          .then((_) => client.hlen('hashId')
          .then((hLenResult) => expect(hLenResult, equals(2)))))
      );
    });
    
    test('HKEYS', () {
      async(
          client.hset('hashId', 'some-key', 'some-value')
          .then((_) => client.hset('hashId', 'some-other-key', 'other-value')
          .then((_) => client.hkeys('hashId')
          .then((hKeysResult) => expect(hKeysResult, equals(['some-key', 'some-other-key'])))))
      );
    });
    
    test('HVALS', () {
      async(
          client.hset('hashId', 'some-key', 'some-value')
            .then((_) => client.hset('hashId', 'some-other-key', 'other-value')
            .then((_) => client.hvals('hashId')
            .then((hValsResult) => expect(hValsResult, equals(['some-value', 'other-value'])))))
      );
    });
    
    test('HGETALL', () {
      Map<String, Object> getAllMap = {
                                       'some-key' : 'some-value',
                                       'some-other-key' : 'other-value'
      };
      async(
          client.hset('hashId', 'some-key', 'some-value')
            .then((_) => client.hset('hashId', 'some-other-key', 'other-value')
            .then((_) => client.hgetall('hashId')
            .then((hGetAllResult) => expect(hGetAllResult, equals(getAllMap)))))
      );
    });
  });
  });

}