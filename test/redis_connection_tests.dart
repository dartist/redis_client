library redis_connection_tests;

import 'dart:async';
import 'package:test/test.dart';
import 'package:redis_client/redis_client.dart';
import 'helper.dart';




main() {

  group('Basic hack tests', () {

    RedisConnection connection;

    setUp(() {
      return RedisConnection.connect("127.0.0.1:6379")
          .then((c) {
            connection = c;
            return connection.send([ "FLUSHALL" ]);
          });
    });

    tearDown(() => connection.close());


    test("random stuff", () {

      async(
        connection.send([ "SELECT", "1" ]).receive().then((_) => expect(_.status, equals("OK")))
            .then((_) => connection.send([ "SELECT", "1" ]).receiveStatus().then((status) => expect(status, equals("OK"))))
            .then((_) => connection.send([ "SADD", "test", "hallo" ]).receiveInteger().then((integer) => expect(integer, equals(1))))
            .then((_) => connection.send([ "SADD", "test", "hallo" ]).receiveInteger().then((integer) => expect(integer, equals(0)))) /// Should return 0 because already inserted
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
            .then((_) {
              return connection.sendCommand(RedisCommand.GET, [ "test1" ]).receiveBulkString()
                  .then((response) => expect(response, equals("value1")));
            })
      );

    });
  });

  group('Connection', () {
      

    test('should connect to a different db', () {
      var connectionString = "127.0.0.1:6379/1";
      async(
          RedisConnection.connect(connectionString)
          .then((connectionResult) {
            expect(connectionResult.db, equals(1));
            connectionResult.close();
          })
      );
    });

  }); 
  
  group('Connection', () {
      var connectionString = "127.0.0.1:6379/1";
      RedisConnection connection;
      setUp(() {
        return RedisConnection.connect(connectionString)
          .then((RedisConnection c) {
            connection = c;
        });
      });
      tearDown(() {
        connection.close();
      });

      /* change connection ip in setUp() and requirepass in redis config file (redis.conf)
    test('should connect to a database with authentication', () {
      async(
          connection.auth('foobared')
          .then((_) => connection.sendCommand(RedisCommand.SET, [ 'key', 'value' ]).receiveStatus('OK')
          .then((sendResult) => expect(sendResult, equals('OK'))))
          );
    });
    */

  });
}