library redis_client_tests;

import 'dart:async';
import 'dart:utf';

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import '../lib/redis_client.dart';






main() {

  Logger.root.onRecord.listen((LogRecord record) {
    print(record.message);
  });

  group('Basic hack tests', () {
    test("random stuff", () {
      RedisClient client;

      RedisClient.connect("127.0.0.1:6379").then((RedisClient c) => client = c)
          .then((_) {
            return client.set("testkey", "testvalue")
                .then((_) => client.get("testkey"))
                .then((String value) => expect(value, equals("testvalue")));
          })

          // Making sure that all tests pass asynchronously
          .then(expectAsync1((_) {
            client.close();
          }));
    });
  });

}