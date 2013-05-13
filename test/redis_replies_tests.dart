library redis_client_tests;

import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import '../lib/redis_protocol_transformer.dart';

import 'dart:utf';



main() {

  group("RedisReply", () {
    group("OneLineReplies", () {
      test("should properly handle a full dataset", () {
        var statusReply = new StatusReply();

        var data = "+Statusmessage\r\n".runes.toList(growable: false);
        var unconsumedData = statusReply.consumeData(data);

        expect(unconsumedData, equals(null));

        expect(statusReply.status, equals("Statusmessage"));

      });
      test("should throw when a statusReply gets called twice", () {
        var statusReply = new StatusReply();

        var data = "+Statusmessage\r\n".runes.toList(growable: false);
        statusReply.consumeData(data);

        expect(() => statusReply.consumeData(data), throws);
      });
      test("should properly return the unconsumedData", () {
        var statusReply = new StatusReply();

        var data = "+Statusmessage\r\nRest of data".runes.toList(growable: false);
        var unconsumedData = statusReply.consumeData(data);

        expect(decodeUtf8(unconsumedData), equals("Rest of data"));
      });
      test("should properly handle multiple data chunks", () {
        var statusReply = new StatusReply();

        var data1 = "+Some Stat".runes.toList(growable: false);
        var data2 = "usmess".runes.toList(growable: false);
        var data3 = "age\r\nRest of data".runes.toList(growable: false);

        var unconsumedData = statusReply.consumeData(data1);
        expect(unconsumedData, equals(null));
        expect(statusReply.done, equals(false));

        unconsumedData = statusReply.consumeData(data2);
        expect(unconsumedData, equals(null));
        expect(statusReply.done, equals(false));

        unconsumedData = statusReply.consumeData(data3);
        expect(decodeUtf8(unconsumedData), equals('Rest of data'));
        expect(statusReply.done, equals(true));

        expect(statusReply.status, equals('Some Statusmessage'));
      });
   });
  });

}