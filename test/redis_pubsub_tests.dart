library redis_pubsub_tests;

import 'dart:async';
import 'package:unittest/unittest.dart';
import 'package:redis_client/redis_client.dart';
import 'helper.dart';
 
main() {

  group('PubSub tests', () {

    RedisClient client;
    
    RedisClient client1;

    setUp(() {
      return RedisClient.connect("127.0.0.1:6379")
          .then((c) {
            client = c;
            client.flushall();
          }).then((a){
             return RedisClient.connect("127.0.0.1:6379").then((c1){
               client1 = c1;
             });
          });
    });

    tearDown(() {
     try {
        client.close();
        client1.close();
       }
      finally {

      }
    });

    test("publish", () {
      async(
      client.publish("redizzz", "izzzkool").then((val){
        expect(val, equals(0));
      }));
    });
    

    test("subscribe & publish", () {
      async(
      client.subscribe(["chan0"],(Receiver message){
        message.receiveMultiBulkStrings().then((List<String> message){
          expect(message[0], equals("message"));
          expect(message[1], equals("chan0"));
          expect(message[2], equals("You okay?"));
          });
        }).then((m){
          client1.publish("chan0","You okay?");
        }));
      });
    

    test("psubscribe & publish", () {
      async(
      client.psubscribe(["chan0.*"],(Receiver message){
        message.receiveMultiBulkStrings().then((List<String> message){
          expect(message[0], equals("pmessage"));
          expect(message[1], equals("chan0.*"));
          expect(message[2], equals("chan0.wow"));
          expect(message[3], equals("You okay?"));
          });
        }).then((m){
          client1.publish("chan0.wow","You okay?");
        }));
      });

    // TODO: Add in following test when support for the API works
    if(false) {
      test("subscribe & publish multiple channels", () {
        async(
            client.subscribe(["chan0","chan1", "chan2"],(Receiver message){
              print('Got subscription message ${message.reply}');
              message.receiveMultiBulkStrings().then((List<String> message){
                print("Message is $message");
                expect(message[0], equals("message"));
                expect(message[1], anyOf(equals("chan0"), equals("chan1")));
                if(message[1] == "chan0") {
                  expect(message[2], equals("You okay?"));
                } else {
                  expect(message[2], equals("How about you?"));
                }
              });
            }).then((m){
                  client1.publish("chan0","You okay?")
                    .then((_) => print('Published you okay?'));
                  client1.publish("chan1","How about you?")
                    .then((_) => print('Published How about you?'));
                }));
      });
    }
    
    test("Can work after unsubscribe", () {
      
      bool gotMessage = false;
      async(
          client.subscribe(["chan0"],(Receiver message){
            return message.receiveMultiBulkStrings().then((List<String> message){
              gotMessage = true;              
            }).then((bb)=>  client.unsubscribe(["chan0"]))
             .then((v) => client.set("key", "val"))
             .then((c1) => client.get("key"))
                 .then((ttt){
                   expect(ttt, equals("val"));
             });
                        
          }).then((a) => client1.publish("chan0","You okay?"))            
      );
      
    });

    test("Can work after punsubscribe", () {
      bool gotMessage = false;
      async(
          client.psubscribe(["chan0.*"],(Receiver message){
            return message.receiveMultiBulkStrings().then((List<String> message){
              gotMessage = true;
            }).then((bb)=>  client.punsubscribe(["chan0.*"]))
             .then((v) => client.set("key", "val"))
             .then((c1) => client.get("key"))
                 .then((ttt){
                   expect(ttt, equals("val"));
             });
          }).then((a) => client1.publish("chan0.wow","You okay?"))
      );
    });
    
    
  });  
  
}