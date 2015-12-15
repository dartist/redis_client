library connection_settings_tests;

import 'package:test/test.dart';
import '../lib/redis_client.dart';




main() {

  group('RedisConnectionSettings', () {
/// - `'pass@host:port/db'`
/// - `'pass@host:port'`
/// - `'pass@host'`
/// - `'host'`
/// - `null` defaults to `'localhost:6379/0'`

    group('connectionStrings should be properly parsed:', () {
      test("pass@host:port/db", () {
        var cs = new RedisConnectionSettings("pass@some.host:1234/2");
        expect(cs.password, equals("pass"));
        expect(cs.hostname, equals("some.host"));
        expect(cs.port, equals(1234));
        expect(cs.db, equals(2));
      });
      test("pass@host:port", () {
        var cs = new RedisConnectionSettings("pass@some.host:1234");
        expect(cs.password, equals("pass"));
        expect(cs.hostname, equals("some.host"));
        expect(cs.port, equals(1234));
        expect(cs.db, equals(0));
      });
      test("pass@host", () {
        var cs = new RedisConnectionSettings("pass@some.host");
        expect(cs.password, equals("pass"));
        expect(cs.hostname, equals("some.host"));
        expect(cs.port, equals(6379));
        expect(cs.db, equals(0));
      });
    });
    test("host:1234", () {
      var cs = new RedisConnectionSettings("some.host:1234");
      expect(cs.password, equals(null));
      expect(cs.hostname, equals("some.host"));
      expect(cs.port, equals(1234));
      expect(cs.db, equals(0));
    });
    test("host", () {
      var cs = new RedisConnectionSettings("some.host");
      expect(cs.password, equals(null));
      expect(cs.hostname, equals("some.host"));
      expect(cs.port, equals(6379));
      expect(cs.db, equals(0));
    });
    test("empty string, null and no parameter should result in the default settings", () {
      var settings = [ new RedisConnectionSettings(""), new RedisConnectionSettings(null), new RedisConnectionSettings() ];

      settings.forEach((cs) {
        expect(cs.password, equals(null));
        expect(cs.hostname, equals("localhost"));
        expect(cs.port, equals(6379));
        expect(cs.db, equals(0));
      });
    });
  });

}