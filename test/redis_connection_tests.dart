library redis_client_tests;

import 'dart:async';
import 'dart:utf';

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import '../lib/redis_client.dart';






main() {

  Logger.root.level = Level.WARNING;
  group('Basic hack tests', () {
    test("random stuff", () {
      RedisConnection.connect("127.0.0.1:6379").then(expectAsync1((RedisConnection conn) {
        conn.send([ "SELECT", "1" ]).receive().then(expectAsync1((_) => expect(_.status, equals("OK"))));
        conn.send([ "SELECT", "1" ]).receiveStatus().then((status) => expect(status, equals("OK")));
        conn.send([ "SADD", "test", "hallo" ]).receiveInteger().then((integer) => expect(integer, equals(0)));
        conn.send([ "SADD", "test", "hallo" ]).receiveInteger().then((integer) => expect(integer, equals(0)));
        conn.send([ "SET", "test1", "value1" ]).receiveStatus().then((status) {
          expect(status, equals("OK"));
          conn.send([ "GET", "test1" ])
              .receiveBulkString()
              .then((response) {
                expect(response, equals("value1"));
              })
              .then((_) {
                conn.close();
              });
        });
      }));
    });
  });

}