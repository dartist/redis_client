library redis_pubsub_tests;

import 'dart:async';
import 'package:test/test.dart';
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

    test("Subscribe multiple channels", () {
      List<List<String>> messages = new List<List<String>>();
      async(
        client.subscribe(["chan0", "chan1"], (Receiver message) {
          message.receiveMultiBulkStrings().then((List<String> message) {
            messages.add(message);
            if (messages.length == 2) {
              expect(messages[0][1], equals('chan1'));
              expect(messages[0][2], equals('Hello'));
              expect(messages[1][1], equals('chan0'));
              expect(messages[1][2], equals('World'));
            }
          });
        })
        .then((_) {
          client1.publish("chan1", "Hello");
          client1.publish("chan0", "World");
        })
      );
    });

    test("partial unsubscribe", () {

      List<List<String>> responses = new List<List<String>>();
      async(
          client.subscribe(["chan0", "chan1", "chan2"], (Receiver message) {
              message.receiveMultiBulkStrings().then((List<String> response) {
                responses.add(response);
                if (responses.length == 1) {
                  client.unsubscribe(["chan0", "chan1"]).then((_) {
                    client1.publish("chan0", "Hello chan0");
                    client1.publish("chan1", "Hello chan1");
                    client1.publish("chan2", "Hello chan2");
                  });
                }
                if (responses.length == 4) {
                  expect(responses[0], equals(["chan0", "Hello chan0"]));
                  expect(responses[1], equals(["chan1", "Hello chan1"]));
                  expect(responses[2], equals(["chan2", "Hello chan2"]));
                  expect(responses[3], equals(["chan2", "Hello chan2"]));
                }
              });

          }).then((_) {
            client1.publish("chan0","Hello chan0");
            client1.publish("chan1","Hello chan1");
            client1.publish("chan2","Hello chan2");
          })
      );

    });

  });  
  
}
