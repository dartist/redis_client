
import 'dart:async';
import 'package:test/test.dart';


Function async = (Future future) {
  future
      .then(expectAsync((_) { })) // Making sure that all tests pass asynchronously
      .catchError((err) {
        throw err;
        print("Error: $err");
        expect(false, equals(err));
      }); // Catching errors
};
