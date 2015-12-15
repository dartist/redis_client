library redis_serializer_tests;

import 'dart:convert';
import 'package:test/test.dart';
import 'package:redis_client/redis_client.dart';

class A {
  String value;
  
  A(this.value);
  
  toJson() {
    var data = {
                'value' : value
    };
    
    return JSON.encode(data);
  }
  
  A.fromJson(json) {
    var data = JSON.decode(json);
    value = data['value'];
  }
}

main() {

    group('JSONRedisSerializer tests', () {
  
      RedisSerializer serializer = new JsonRedisSerializer();
      
      group('can encode-decode:', () {
        test('nulls', () {
          var serializedNull = serializer.serialize(null);
          var deserializedNull = serializer.deserialize(serializedNull);
          expect(serializedNull, equals(deserializedNull));
        });
        
        test('strings', () {
          var serializedString = serializer.serialize('some-string');
          var deserializedString = serializer.deserialize(serializedString);
          expect(deserializedString, equals('some-string'));
        });
        
        test('lists', () {
          var serializedList = serializer.serialize(['some-string', 4]);
          var deserializedList = serializer.deserialize(serializedList);
          expect(deserializedList, equals(['some-string', 4]));
        });
        
        test('sets', () {
          var serializedSet = serializer.serialize(new Set.from(['some-string', 4]));
          var deserializedSet = serializer.deserialize(serializedSet);
          expect(deserializedSet, equals(new Set.from(['some-string', 4])));
        });
       
        test('dates', () {
          DateTime now = new DateTime.now().toUtc();
          var serializedDate = serializer.serialize(now);
          DateTime justNow = serializer.deserialize(serializedDate);
          expect(now, equals(justNow));
        });
        
        //TODO: need some work to support instantiation from deserializer
        test('custom classes', () {
          A a = new A('some-value');
          var serializedA = serializer.serialize(a);
          A deserializedA = new A.fromJson(serializer.deserialize(serializedA));
          expect(deserializedA.value, equals(a.value));
        });

      });
      
    });

}
