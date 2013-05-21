
import 'dart:async';
import 'package:unittest/unittest.dart';


Function async = (Future future) {
  future
      .then(expectAsync1((_) { })) // Making sure that all tests pass asynchronously
      .catchError((err) {
        print("Error: $err");
        expect(false, equals(err));
      }); // Catching errors
};
