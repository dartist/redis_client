library redis_client_tests;

import 'dart:async';
import 'dart:utf';

import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import '../lib/redis_protocol_transformer.dart';



class MockSink extends Mock implements EventSink<RedisReply> {

  bool connected = true;

  MockSink();


  List<RedisReply> replies = <RedisReply>[ ];
  void add(RedisReply reply) {
    replies.add(reply);
  }

}



main() {


  group("RedisProtocolTransformer:", () {

    group("Exceptions", () {
      test("should be able to instantiated all exceptions", () {
        // Had a problem with that at the beginning. Just making sure.
        new InvalidRedisResponseError("test");
        new UnexpectedRedisClosureError("test");
      });
    });

    group("OneLineReplies", () {
      test("should properly return RedisReplies of all kinds", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("+Status message\r\n"), sink);
        expect(sink.replies.length, equals(1));
        expect(sink.replies.last.runtimeType, equals(StatusReply));
        StatusReply tested1 = sink.replies.last;
        expect(tested1.status, equals("Status message"));

        rpt.handleData(encodeUtf8("-Error message\r\n"), sink);
        expect(sink.replies.length, equals(2));
        expect(sink.replies.last.runtimeType, equals(ErrorReply));
        ErrorReply tested2 = sink.replies.last;
        expect(tested2.error, equals("Error message"));

        rpt.handleData(encodeUtf8(":12345\r\n"), sink);
        expect(sink.replies.length, equals(3));
        expect(sink.replies.last.runtimeType, equals(IntegerReply));
        IntegerReply tested3 = sink.replies.last;
        expect(tested3.integer, equals(12345));
      });
      test("should properly handle it if only the symbol is passed", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("+"), sink);
        expect(sink.replies.length, equals(0));
        rpt.handleData(encodeUtf8("Hi there\r\n"), sink);
        expect(sink.replies.length, equals(1));
        expect(sink.replies[0].runtimeType, equals(StatusReply));
        StatusReply testedStatus = sink.replies[0];
        expect(testedStatus.status, equals("Hi there"));

      });
      test("should properly handle it if all data is passed at once", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("+Status message\r\n:132\r\n-Error message\r\n"), sink);
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

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("+Status m"), sink);
        expect(sink.replies.length, equals(0));

        rpt.handleData(encodeUtf8("essage\r"), sink);
        // Shouldn't be handled yet because of the missing \n
        expect(sink.replies.length, equals(0));

        rpt.handleData(encodeUtf8("\n:1234\r\n-Start of err"), sink);

        // Should have handled the status and the integer
        expect(sink.replies.length, equals(2));

        rpt.handleData(encodeUtf8("or end\r\n"), sink);

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

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("\$6\r\nfoobar\r\n"), sink);

        expect(sink.replies.length, equals(1));
        expect(sink.replies.first.runtimeType, equals(BulkReply));
        BulkReply tested1 = sink.replies.first;
        expect(tested1.bytes, equals("foobar".codeUnits));
        expect(tested1.string, equals("foobar"));
      });
      test("should properly handle multiple bulk replies in one data chunk", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("\$6\r\nfoobar\r\n\$8\r\nfoobars2\r\n"), sink);

        expect(sink.replies.length, equals(2));
        expect(sink.replies.first.runtimeType, equals(BulkReply));
        expect(sink.replies.last.runtimeType, equals(BulkReply));
        BulkReply tested1 = sink.replies.first;
        BulkReply tested2 = sink.replies.last;
        expect(tested1.string, equals("foobar"));
        expect(tested2.string, equals("foobars2"));
      });
      test("should properly handle multiple chopped data chunks", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("\$6\r\nfoo"), sink);

        expect(sink.replies.length, equals(0));

        rpt.handleData(encodeUtf8("bar\r"), sink);

        expect(sink.replies.length, equals(0));

        rpt.handleData(encodeUtf8("\n\$4\r\ntest\r\n\$"), sink);

        expect(sink.replies.length, equals(2));

        rpt.handleData(encodeUtf8("3\r\nend\r\n\$1"), sink);

        expect(sink.replies.length, equals(3));

        rpt.handleData(encodeUtf8("1\r\nabcdefghijk\r\n"), sink);

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

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("\$6\r\nfoo"), sink);
        rpt.handleData(encodeUtf8("bar\r\n+Mess"), sink);
        rpt.handleData(encodeUtf8("age"), sink);
        rpt.handleData(encodeUtf8("\r\n-Error message\r\n:12345\r"), sink);
        rpt.handleData(encodeUtf8("\n"), sink);

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
    group("UTF8", () {
      test("should properly be handled in bulk and one line replies", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData(encodeUtf8("\$9\r\nfo¢b€r\r\n"), sink);

        BulkReply tested1 = sink.replies[0];
        expect(tested1.string, equals("fo¢b€r"));

     });
    });
  });

}