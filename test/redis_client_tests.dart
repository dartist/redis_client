library redis_client_tests;

import 'dart:async';
import 'dart:utf';

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import '../lib/redis_client.dart';


import 'helper.dart';



main() {

//  Logger.root.level = Level.FINEST;
//  Logger.root.onRecord.listen((LogRecord record) {
//    print(record.message);
//  });

  group("RedisClient", () {

    RedisClient client;

    setUp(() {
      return RedisClient.connect("127.0.0.1:6379")
          .then((c) {
            client = c;
            client.flushall();
          });
    });

    tearDown(() => client.close());

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
    });


  });

}