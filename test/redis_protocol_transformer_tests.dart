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

  });

}