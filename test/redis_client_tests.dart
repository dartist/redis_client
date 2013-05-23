library redis_client_tests;

import 'dart:async';
import 'dart:utf';

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import '../lib/redis_client.dart';


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
      client.close();
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
            .then((List<String> keys) => expect(keys, equals([ "twokey", "onekey" ])))
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

//      test("RANDOMKEY", () {
//
//      });
    });


  });

}