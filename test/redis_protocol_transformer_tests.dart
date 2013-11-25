library redis_protocol_transformer_tests;

import 'dart:async';
import 'dart:convert';

import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import 'package:redis_client/redis_protocol_transformer.dart';
import 'package:redis_client/redis_client.dart';


class MockSink extends Mock implements EventSink<RedisReply> {

  bool connected = true;

  MockSink();

  close() {}
  addError(errorEvent, [stackTrace]) {}

  List<RedisReply> replies = <RedisReply>[ ];
  void add(RedisReply reply) {
    replies.add(reply);
  }

}

class MockRedisConnection extends Mock implements RedisConnection {

  String connectionString;
   
  String hostname;

  String password;

  int port;

  int db;
  
  RedisReply _currentReply;
  Future close() {}


  Map get stats {}

  Future auth(String _password) { this.password = _password; }

  Future select([ int db ]) {}

  Receiver send(List<String> cmdWithArgs) {}

  Receiver sendCommand(List<int> command, List<String> args) {}

  Receiver sendCommandWithVariadicValues(List<int> command, List<String> args, List<String> values) { }
  
  Receiver sendCommandWithVariadicArguments(List<int> command, List<String> args) { }
  
  Receiver rawSend(List<List<int>> cmdWithArgs) {}

  void handleError(Object error, StackTrace stackTrace, EventSink<RedisReply> sink) {
    sink.addError(error, stackTrace);
  }

  void handleDone(EventSink<RedisReply> output) {

    if (_currentReply != null) {
      var error = new UnexpectedRedisClosureError("Some data has already been sent but was not complete.");
      // Apparently some data has already been sent, but the stream is done.
      handleError(error, error.stackTrace, output);
    }

    output.close();
  }  
  
  void handleData(List<int> data, EventSink<RedisReply> output) {
    // I'm not entirely sure this is necessary, but better be safe.
    if (data.length == 0) return;
  
    if (_currentReply == null) {
      // This is a fresh RedisReply. How exciting!
  
      try {
        _currentReply = new RedisReply.fromType(data.first);
      }
      on RedisProtocolTransformerException catch (e) {
        handleError(e, e.stackTrace, output);
      }
    }
  
    List<int> unconsumedData = _currentReply.consumeData(data);
  
    // Make sure that unconsumedData can't be returned unless the reply is actually done.
    assert(unconsumedData == null || _currentReply.done);
  
    if (_currentReply.done) {
      // Reply is done!
      output.add(_currentReply);
      _currentReply = null;
      if (unconsumedData != null && !unconsumedData.isEmpty) {
        handleData(unconsumedData, output);
      }
    }
  }
}


main() {


  group("RedisProtocolTransformer:", () {

    group("Exceptions", () {
      test("should all be able to be instantiated", () {
        // Had a problem with that at the beginning. Just making sure.
        new InvalidRedisResponseError("test");
        new UnexpectedRedisClosureError("test");
      });
    });

    group("OneLineReplies", () {
      test("should properly return RedisReplies of all kinds", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();
        
        redisConnection.handleData(UTF8.encode("+Status message\r\n"), sink);
        expect(sink.replies.length, equals(1));
        expect(sink.replies.last.runtimeType, equals(StatusReply));
        StatusReply tested1 = sink.replies.last;
        expect(tested1.status, equals("Status message"));

        redisConnection.handleData(UTF8.encode("-Error message\r\n"), sink);
        expect(sink.replies.length, equals(2));
        expect(sink.replies.last.runtimeType, equals(ErrorReply));
        ErrorReply tested2 = sink.replies.last;
        expect(tested2.error, equals("Error message"));

        redisConnection.handleData(UTF8.encode(":12345\r\n"), sink);
        expect(sink.replies.length, equals(3));
        expect(sink.replies.last.runtimeType, equals(IntegerReply));
        IntegerReply tested3 = sink.replies.last;
        expect(tested3.integer, equals(12345));
      });
      test("should properly handle it if only the symbol is passed", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();
        
        redisConnection.handleData(UTF8.encode("+"), sink);
        expect(sink.replies.length, equals(0));
        redisConnection.handleData(UTF8.encode("Hi there\r\n"), sink);
        expect(sink.replies.length, equals(1));
        expect(sink.replies[0].runtimeType, equals(StatusReply));
        StatusReply testedStatus = sink.replies[0];
        expect(testedStatus.status, equals("Hi there"));

      });
      test("should properly handle it if all data is passed at once", () {
        var sink = new MockSink();
        
        var redisConnection = new MockRedisConnection();
        
        redisConnection.handleData(UTF8.encode("+Status message\r\n:132\r\n-Error message\r\n"), sink);
        expect(sink.replies.length, equals(3));
        expect(sink.replies[0].runtimeType, equals(StatusReply));
        expect(sink.replies[1].runtimeType, equals(IntegerReply));
        expect(sink.replies[2].runtimeType, equals(ErrorReply));

        StatusReply testedStatus = sink.replies[0];
        IntegerReply testedInteger = sink.replies[1];
        ErrorReply testedError = sink.replies[2];

        expect(testedStatus.status, equals("Status message"));
        expect(testedInteger.integer, equals(132));
        expect(testedError.error, equals("Error message"));
      });
      test("should properly handle chunked data", () {
        var sink = new MockSink();
        
        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("+Status m"), sink);
        expect(sink.replies.length, equals(0));

        redisConnection.handleData(UTF8.encode("essage\r"), sink);
        // Shouldn't be handled yet because of the missing \n
        expect(sink.replies.length, equals(0));

        redisConnection.handleData(UTF8.encode("\n:1234\r\n-Start of err"), sink);

        // Should have handled the status and the integer
        expect(sink.replies.length, equals(2));

        redisConnection.handleData(UTF8.encode("or end\r\n"), sink);

        expect(sink.replies.length, equals(3));

        expect(sink.replies[0].runtimeType, equals(StatusReply));
        expect(sink.replies[1].runtimeType, equals(IntegerReply));
        expect(sink.replies[2].runtimeType, equals(ErrorReply));

        StatusReply testedStatus = sink.replies[0];
        IntegerReply testedInteger = sink.replies[1];
        ErrorReply testedError = sink.replies[2];

        expect(testedStatus.status, equals("Status message"));
        expect(testedInteger.integer, equals(1234));
        expect(testedError.error, equals("Start of error end"));
      });
    });

    group("BulkReplies", () {
      test("should properly return single bulk replies", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\$6\r\nfoobar\r\n"), sink);

        expect(sink.replies.length, equals(1));
        expect(sink.replies.first.runtimeType, equals(BulkReply));
        BulkReply tested1 = sink.replies.first;
        expect(tested1.bytes, equals("foobar".codeUnits));
        expect(tested1.string, equals("foobar"));
      });
      test("should properly handle multiple bulk replies in one data chunk", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\$6\r\nfoobar\r\n\$8\r\nfoobars2\r\n"), sink);

        expect(sink.replies.length, equals(2));
        expect(sink.replies.first.runtimeType, equals(BulkReply));
        expect(sink.replies.last.runtimeType, equals(BulkReply));
        BulkReply tested1 = sink.replies.first;
        BulkReply tested2 = sink.replies.last;
        expect(tested1.string, equals("foobar"));
        expect(tested2.string, equals("foobars2"));
      });
      test("should properly handle null replies", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\$-"), sink);
        redisConnection.handleData(UTF8.encode("1\r"), sink);
        expect(sink.replies.length, equals(0));
        redisConnection.handleData(UTF8.encode("\n"), sink);
        expect(sink.replies.length, equals(1));

        BulkReply reply = sink.replies.first;
        expect(reply.string, equals(null));
        expect(reply.bytes, equals(null));

      });
      test("should properly handle multiple chopped data chunks", () {
        var sink = new MockSink();
        
        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\$6\r\nfoo"), sink);

        expect(sink.replies.length, equals(0));

        redisConnection.handleData(UTF8.encode("bar\r"), sink);

        expect(sink.replies.length, equals(0));

        redisConnection.handleData(UTF8.encode("\n\$4\r\ntest\r\n\$"), sink);

        expect(sink.replies.length, equals(2));

        redisConnection.handleData(UTF8.encode("3\r\nend\r\n\$1"), sink);

        expect(sink.replies.length, equals(3));

        redisConnection.handleData(UTF8.encode("1\r\nabcdefghijk\r\n"), sink);

        expect(sink.replies.length, equals(4));

        expect(sink.replies[0].runtimeType, equals(BulkReply));
        expect(sink.replies[1].runtimeType, equals(BulkReply));
        expect(sink.replies[2].runtimeType, equals(BulkReply));
        expect(sink.replies[3].runtimeType, equals(BulkReply));

        BulkReply tested1 = sink.replies[0];
        BulkReply tested2 = sink.replies[1];
        BulkReply tested3 = sink.replies[2];
        BulkReply tested4 = sink.replies[3];

        expect(tested1.string, equals("foobar"));
        expect(tested2.string, equals("test"));
        expect(tested3.string, equals("end"));
        expect(tested4.string, equals("abcdefghijk"));
      });
    });

    group("Mixed replies", () {
      test("should properly be handled (one line and bulk replies together)", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\$6\r\nfoo"), sink);
        redisConnection.handleData(UTF8.encode("bar\r\n+Mess"), sink);
        redisConnection.handleData(UTF8.encode("age"), sink);
        redisConnection.handleData(UTF8.encode("\r\n-Error message\r\n:12345\r"), sink);
        redisConnection.handleData(UTF8.encode("\n"), sink);

        expect(sink.replies.length, equals(4));

        BulkReply tested1 = sink.replies[0];
        StatusReply tested2 = sink.replies[1];
        ErrorReply tested3 = sink.replies[2];
        IntegerReply tested4 = sink.replies[3];

        expect(tested1.string, equals("foobar"));
        expect(tested2.status, equals("Message"));
        expect(tested3.error, equals("Error message"));
        expect(tested4.integer, equals(12345));
      });
    });

    group("MultiBulkReplies", () {
      test("should properly handle one MultiBulkReply with mixed Replies.", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\*4\r\n:5\r"), sink);
        redisConnection.handleData(UTF8.encode("\n-Error\r\n+Status\r\n\$6\r"), sink);
        redisConnection.handleData(UTF8.encode("\nfoobar"), sink);

        expect(sink.replies.length, equals(0));

        redisConnection.handleData(UTF8.encode("\r\n"), sink);

        expect(sink.replies.length, equals(1));

        MultiBulkReply mbr = sink.replies.last;

        expect(mbr.replies.length, equals(4));

        expect(mbr.replies[0].runtimeType, equals(IntegerReply));
        expect(mbr.replies[1].runtimeType, equals(ErrorReply));
        expect(mbr.replies[2].runtimeType, equals(StatusReply));
        expect(mbr.replies[3].runtimeType, equals(BulkReply));

        IntegerReply tested1 = mbr.replies[0];
        ErrorReply tested2 = mbr.replies[1];
        StatusReply tested3 = mbr.replies[2];
        BulkReply tested4 = mbr.replies[3];

        expect(tested1.integer, equals(5));
        expect(tested2.error, "Error");
        expect(tested3.status, "Status");
        expect(tested4.string, "foobar");

      });
      test("should handle multi bulk replies with 0 bulk replies", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\*"), sink);
        expect(sink.replies.length, equals(0));
        redisConnection.handleData(UTF8.encode("0\r"), sink);
        expect(sink.replies.length, equals(0));
        redisConnection.handleData(UTF8.encode("\n"), sink);
        expect(sink.replies.length, equals(1));

        MultiBulkReply test = sink.replies.first;
        expect(test.replies.length, equals(0));

      });
    });

    group("UTF8", () {
      test("should properly be handled in bulk and one line replies", () {
        var sink = new MockSink();

        var redisConnection = new MockRedisConnection();

        redisConnection.handleData(UTF8.encode("\$9\r\nfo¢b€r\r\n"), sink);

        BulkReply tested1 = sink.replies[0];
        expect(tested1.string, equals("fo¢b€r"));

     });
    });
  });

}