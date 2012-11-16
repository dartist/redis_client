#library("RedisConnectionTests");
#import("../packages/DartMixins/DUnit.dart");
#import("../RedisClient.dart");
#import("dart:json");

JsonEncoderTests() {

  module("JsonEncoder");

  JsonEncoder enc = new JsonEncoder();

  test("Encoder: serialize", (){
    equal(enc.stringify(null), "", "can encode nulls");
    equal(enc.stringify(1), "1", "can encode ints");
    equal(enc.stringify(-1), "-1", "can encode negative ints");
    equal(enc.stringify(1.1), "1.1", "can encode doubles");
    equal(enc.stringify(-1.1), "-1.1", "can encode negative doubles");
    equal(enc.stringify(''), "", "can encode empty strings");
    equal(enc.stringify('A'), "A", "can encode strings");
    equal(enc.stringify(true), "true", "can encode bools");
    equal(enc.stringify({}), "{}", "can encode empty Map");
    equal(enc.stringify([]), "[]", "can encode empty List");
    equal(enc.stringify({'A':1}), '{"A":1}', "can encode Map");
    equal(enc.stringify(['A']), '["A"]', "can encode List");
    equal(enc.stringify(new Date(2012,05,09,0,0,0,0)), "/Date(1336536000000)/", "can encode Date");
  });

  test("Encoder: deserialize", (){
    equal(enc.toObject(enc.toBytes(null)), null, "can decode nulls");
    equal(enc.toObject(enc.toBytes(1)), 1, "can decode ints");
    equal(enc.toObject(enc.toBytes(-1)), -1, "can decode negative ints");
    equal(enc.toObject(enc.toBytes(1.1)), 1.1, "can decode doubles");
    equal(enc.toObject(enc.toBytes(-1.1)), -1.1, "can decode negative doubles");
    equal(enc.toObject(enc.toBytes('')), null, "can decode empty strings");
    equal(enc.toObject(enc.toBytes('A')), "A", "can decode strings");
    equal(enc.toObject(enc.toBytes(true)), true, "can decode true");
    equal(enc.toObject(enc.toBytes(false)), false, "can decode false");
    deepEqual(enc.toObject(enc.toBytes({})), {}, "can decode empty Map");
    deepEqual(enc.toObject(enc.toBytes([])), [], "can decode empty List");
    deepEqual(enc.toObject(enc.toBytes({'A':1})), {"A":1}, "can decode Map");
    deepEqual(enc.toObject(enc.toBytes(['A'])), ["A"], "can decode List");
    Date utcDate = new Date(2012,05,09,0,0,0,0, isUtc: true);
    equal(enc.toObject(enc.toBytes(utcDate)), utcDate, "can decode UTC Date");

//TODO support non UTC dates
//    Date localDate = new Date.withTimeZone(2012,05,09,0,0,0,0, new TimeZone.local());
//    equal(enc.toObject(enc.toBytes(localDate)), localDate, "can decode local Date");

  });

}
