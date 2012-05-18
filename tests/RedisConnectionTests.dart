#library("RedisConnectionTests");
#import("../vendor/Mixins/DUnit.dart");
#import("../RedisConnection.dart");

RedisConnectionTests(){

  module("RedisConnection");

  test("Connection: constructor", (){

    var conn = new RedisConnection("pass@host:133/7");

    equal(conn.password, "pass", "parses password");
    equal(conn.hostName, "host", "parses hostName");
    equal(conn.port, 133, "parses port");
    equal(conn.db, 7, "parses db");

    conn = new RedisConnection("pass@host:133");
    deepEqual([conn.password, conn.hostName, conn.port, conn.db], ["pass","host", 133, 0], "parses without db");

    conn = new RedisConnection("pass@host");
    deepEqual([conn.password, conn.hostName, conn.port, conn.db], ["pass","host", 6379, 0], "parses without port");

    conn = new RedisConnection("host");
    deepEqual([conn.password, conn.hostName, conn.port, conn.db], [null,"host", 6379, 0], "parses without password");

    conn = new RedisConnection();
    deepEqual([conn.password, conn.hostName, conn.port, conn.db], [null,"localhost", 6379, 0], "empty ctor uses defaults");

  });

}