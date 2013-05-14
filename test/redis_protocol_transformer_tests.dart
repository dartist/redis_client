library redis_client_tests;

import 'dart:async';

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


  group("RedisProtocolTransformer", () {

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

        rpt.handleData("+Status message\r\n".runes.toList(growable: false), sink);
        expect(sink.replies.length, equals(1));
        expect(sink.replies.last.runtimeType, equals(StatusReply));
        StatusReply tested1 = sink.replies.last;
        expect(tested1.status, equals("Status message"));

        rpt.handleData("-Error message\r\n".runes.toList(growable: false), sink);
        expect(sink.replies.length, equals(2));
        expect(sink.replies.last.runtimeType, equals(ErrorReply));
        ErrorReply tested2 = sink.replies.last;
        expect(tested2.error, equals("Error message"));

        rpt.handleData(":12345\r\n".runes.toList(growable: false), sink);
        expect(sink.replies.length, equals(3));
        expect(sink.replies.last.runtimeType, equals(IntegerReply));
        IntegerReply tested3 = sink.replies.last;
        expect(tested3.integer, equals(12345));
      });
      test("should properly handle it if only the symbol is passed", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData("+".runes.toList(growable: false), sink);
        expect(sink.replies.length, equals(0));
        rpt.handleData("Hi there\r\n".runes.toList(growable: false), sink);
        expect(sink.replies.length, equals(1));
        expect(sink.replies[0].runtimeType, equals(StatusReply));
        StatusReply testedStatus = sink.replies[0];
        expect(testedStatus.status, equals("Hi there"));

      });
      test("should properly handle it if all data is passed at once", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData("+Status message\r\n:132\r\n-Error message\r\n".runes.toList(growable: false), sink);
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

        rpt.handleData("+Status m".runes.toList(growable: false), sink);
        expect(sink.replies.length, equals(0));

        rpt.handleData("essage\r".runes.toList(growable: false), sink);
        // Shouldn't be handled yet because of the missing \n
        expect(sink.replies.length, equals(0));

        rpt.handleData("\n:1234\r\n-Start of err".runes.toList(growable: false), sink);

        // Should have handled the status and the integer
        expect(sink.replies.length, equals(2));

        rpt.handleData("or end\r\n".runes.toList(growable: false), sink);

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

        rpt.handleData("\$6\r\nfoobar\r\n".runes.toList(growable: false), sink);

        expect(sink.replies.length, equals(1));
        expect(sink.replies.first.runtimeType, equals(BulkReply));
        BulkReply tested1 = sink.replies.first;
        expect(tested1.bytes, equals("foobar".codeUnits));
        expect(tested1.string, equals("foobar"));
      });
      test("should properly handle multiple bulk replies in one data chunk", () {
        var sink = new MockSink();

        var rpt = new RedisProtocolTransformer();

        rpt.handleData("\$6\r\nfoobar\r\n\$8\r\nfoobars2\r\n".runes.toList(growable: false), sink);

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

        rpt.handleData("\$6\r\nfoo".runes.toList(growable: false), sink);

        expect(sink.replies.length, equals(0));

        rpt.handleData("bar\r".runes.toList(growable: false), sink);

        expect(sink.replies.length, equals(0));

        rpt.handleData("\n\$4\r\ntest\r\n\$".runes.toList(growable: false), sink);

        expect(sink.replies.length, equals(2));

        rpt.handleData("3\r\nend\r\n\$1".runes.toList(growable: false), sink);

        expect(sink.replies.length, equals(3));

        rpt.handleData("1\r\nabcdefghijk\r\n".runes.toList(growable: false), sink);

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

  });

}