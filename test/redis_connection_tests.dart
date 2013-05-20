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
      RedisConnection connection;

      RedisConnection.connect("127.0.0.1:6379")
          .then((RedisConnection conn) => connection = conn)
          .then((_) => connection.send([ "SELECT", "1" ]).receive().then((_) => expect(_.status, equals("OK"))))
          .then((_) => connection.send([ "SELECT", "1" ]).receiveStatus().then((status) => expect(status, equals("OK"))))
          .then((_) => connection.send([ "SADD", "test", "hallo" ]).receiveInteger().then((integer) => expect(integer, equals(0))))
          .then((_) => connection.send([ "SADD", "test", "hallo" ]).receiveInteger().then((integer) => expect(integer, equals(0))))
          .then((_) {
            return connection.send([ "SET", "test1", "value1" ]).receiveStatus().then((status) {
              expect(status, equals("OK"));
              return connection.send([ "GET", "test1" ])
                  .receiveBulkString()
                  .then((response) {
                    expect(response, equals("value1"));
                  });
            });
          })
          .then((_) {
            return connection.rawSend([ "GET".codeUnits, "test1".codeUnits ]).receiveBulkString()
                .then((response) => expect(response, equals("value1")));
          })
          .then((_) => connection.close())
          .then(expectAsync1((_) { }));

    });
  });

}