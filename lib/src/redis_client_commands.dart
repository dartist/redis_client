part of redis_client;

/// All available commands.
///
/// TODO change to lazy static initializers
class Cmd {

  List<int> _chars(String command) => command.runes.toList();

  // ADMIN
  static List<int> get DBSIZE => _chars("DBSIZE");
  static List<int> get INFO => _chars("INFO");
  static List<int> get LASTSAVE => _chars("LASTSAVE");
  static List<int> get PING => _chars("PING");
  static List<int> get ECHO => _chars("ECHO");
  static List<int> get SLAVEOF => _chars("SLAVEOF");
  static List<int> get NO => _chars("NO");
  static List<int> get ONE => _chars("ONE");
  static List<int> get CONFIG => _chars("CONFIG"); //GET SET
  static List<int> get RESETSTAT => _chars("RESETSTAT");
  static List<int> get TIME => _chars("TIME");
  static List<int> get DEBUG => _chars("DEBUG"); //OBJECT SEGFAULT
  static List<int> get SEGFAULT => _chars("SEGFAULT");
  static List<int> get RESTORE => _chars("RESTORE");
  static List<int> get MIGRATE => _chars("MIGRATE");
  static List<int> get MOVE => _chars("MOVE");
  static List<int> get OBJECT => _chars("OBJECT"); //REFCOUNT ENCODING IDLETIME
  static List<int> get REFCOUNT => _chars("REFCOUNT");
  static List<int> get ENCODING => _chars("ENCODING");
  static List<int> get IDLETIME => _chars("IDLETIME");
  static List<int> get SAVE => _chars("SAVE");
  static List<int> get BGSAVE => _chars("BGSAVE");
  static List<int> get SHUTDOWN => _chars("SHUTDOWN");
  static List<int> get BGREWRITEAOF => _chars("BGREWRITEAOF");
  static List<int> get QUIT => _chars("QUIT");
  static List<int> get FLUSHDB => _chars("FLUSHDB");
  static List<int> get FLUSHALL => _chars("FLUSHALL");
  static List<int> get KEYS => _chars("KEYS");
  static List<int> get SLOWLOG => _chars("SLOWLOG");

  // Keys
  static List<int> get TYPE => _chars("TYPE");
  static List<int> get STRLEN => _chars("STRLEN");
  static List<int> get SET => _chars("SET");
  static List<int> get GET => _chars("GET");
  static List<int> get DEL => _chars("DEL");
  static List<int> get SETEX => _chars("SETEX");
  static List<int> get PSETEX => _chars("PSETEX");
  static List<int> get SETNX => _chars("SETNX");
  static List<int> get PERSIST => _chars("PERSIST");
  static List<int> get MSET => _chars("MSET");
  static List<int> get MSETNX => _chars("MSETNX");
  static List<int> get GETSET => _chars("GETSET");
  static List<int> get EXISTS => _chars("EXISTS");
  static List<int> get INCR => _chars("INCR");
  static List<int> get INCRBY => _chars("INCRBY");
  static List<int> get INCRBYFLOAT => _chars("INCRBYFLOAT");
  static List<int> get DECR => _chars("DECR");
  static List<int> get DECRBY => _chars("DECRBY");
  static List<int> get APPEND => _chars("APPEND");
  static List<int> get SUBSTR => _chars("SUBSTR");
  static List<int> get GETRANGE => _chars("GETRANGE");
  static List<int> get SETRANGE => _chars("SETRANGE");
  static List<int> get GETBIT => _chars("GETBIT");
  static List<int> get SETBIT => _chars("SETBIT");
  static List<int> get RANDOMKEY => _chars("RANDOMKEY");
  static List<int> get RENAME => _chars("RENAME");
  static List<int> get RENAMENX => _chars("RENAMENX");
  static List<int> get EXPIRE => _chars("EXPIRE");
  static List<int> get PEXPIRE => _chars("PEXPIRE");
  static List<int> get EXPIREAT => _chars("EXPIREAT");
  static List<int> get PEXPIREAT => _chars("PEXPIREAT");
  static List<int> get TTL => _chars("TTL");
  static List<int> get PTTL => _chars("PTTL");

  // Transactions
  static List<int> get MGET => _chars("MGET");
  static List<int> get WATCH => _chars("WATCH");
  static List<int> get UNWATCH => _chars("UNWATCH");
  static List<int> get MULTI => _chars("MULTI");
  static List<int> get EXEC => _chars("EXEC");
  static List<int> get DISCARD => _chars("DISCARD");

  // SET
  static List<int> get SMEMBERS => _chars("SMEMBERS");
  static List<int> get SADD => _chars("SADD");
  static List<int> get SREM => _chars("SREM");
  static List<int> get SPOP => _chars("SPOP");
  static List<int> get SMOVE => _chars("SMOVE");
  static List<int> get SCARD => _chars("SCARD");
  static List<int> get SISMEMBER => _chars("SISMEMBER");
  static List<int> get SINTER => _chars("SINTER");
  static List<int> get SINTERSTORE => _chars("SINTERSTORE");
  static List<int> get SUNION => _chars("SUNION");
  static List<int> get SUNIONSTORE => _chars("SUNIONSTORE");
  static List<int> get SDIFF => _chars("SDIFF");
  static List<int> get SDIFFSTORE => _chars("SDIFFSTORE");
  static List<int> get SRANDMEMBER => _chars("SRANDMEMBER");

  // Sort Set/List
  static List<int> get SORT => _chars("SORT"); //BY LIMIT GET DESC ALPHA STORE
  static List<int> get BY => _chars("BY");
  static List<int> get DESC => _chars("DESC");
  static List<int> get ALPHA => _chars("ALPHA");
  static List<int> get STORE => _chars("STORE");

  // List
  static List<int> get LRANGE => _chars("LRANGE");
  static List<int> get RPUSH => _chars("RPUSH");
  static List<int> get RPUSHX => _chars("RPUSHX");
  static List<int> get LPUSH => _chars("LPUSH");
  static List<int> get LPUSHX => _chars("LPUSHX");
  static List<int> get LTRIM => _chars("LTRIM");
  static List<int> get LREM => _chars("LREM");
  static List<int> get LLEN => _chars("LLEN");
  static List<int> get LINDEX => _chars("LINDEX");
  static List<int> get LINSERT => _chars("LINSERT");
  static List<int> get AFTER => _chars("AFTER");
  static List<int> get BEFORE => _chars("BEFORE");
  static List<int> get LSET => _chars("LSET");
  static List<int> get LPOP => _chars("LPOP");
  static List<int> get RPOP => _chars("RPOP");
  static List<int> get BLPOP => _chars("BLPOP");
  static List<int> get BRPOP => _chars("BRPOP");
  static List<int> get RPOPLPUSH => _chars("RPOPLPUSH");

  // Sorted Sets
  static List<int> get ZADD => _chars("ZADD");
  static List<int> get ZREM => _chars("ZREM");
  static List<int> get ZINCRBY => _chars("ZINCRBY");
  static List<int> get ZRANK => _chars("ZRANK");
  static List<int> get ZREVRANK => _chars("ZREVRANK");
  static List<int> get ZRANGE => _chars("ZRANGE");
  static List<int> get ZREVRANGE => _chars("ZREVRANGE");
  static List<int> get WITHSCORES => _chars("WITHSCORES");
  static List<int> get LIMIT => _chars("LIMIT");
  static List<int> get ZRANGEBYSCORE => _chars("ZRANGEBYSCORE");
  static List<int> get ZREVRANGEBYSCORE => _chars("ZREVRANGEBYSCORE");
  static List<int> get ZREMRANGEBYRANK => _chars("ZREMRANGEBYRANK");
  static List<int> get ZREMRANGEBYSCORE => _chars("ZREMRANGEBYSCORE");
  static List<int> get ZCARD => _chars("ZCARD");
  static List<int> get ZSCORE => _chars("ZSCORE");
  static List<int> get ZUNIONSTORE => _chars("ZUNIONSTORE");
  static List<int> get ZINTERSTORE => _chars("ZINTERSTORE");

  // Hash
  static List<int> get HSET => _chars("HSET");
  static List<int> get HSETNX => _chars("HSETNX");
  static List<int> get HMSET => _chars("HMSET");
  static List<int> get HINCRBY => _chars("HINCRBY");
  static List<int> get HINCRBYFLOAT => _chars("HINCRBYFLOAT");
  static List<int> get HGET => _chars("HGET");
  static List<int> get HMGET => _chars("HMGET");
  static List<int> get HDEL => _chars("HDEL");
  static List<int> get HEXISTS => _chars("HEXISTS");
  static List<int> get HLEN => _chars("HLEN");
  static List<int> get HKEYS => _chars("HKEYS");
  static List<int> get HVALS => _chars("HVALS");
  static List<int> get HGETALL => _chars("HGETALL");

  // Pub/Sub
  static List<int> get PUBLISH => _chars("PUBLISH");
  static List<int> get SUBSCRIBE => _chars("SUBSCRIBE");
  static List<int> get UNSUBSCRIBE => _chars("UNSUBSCRIBE");
  static List<int> get PSUBSCRIBE => _chars("PSUBSCRIBE");
  static List<int> get PUNSUBSCRIBE => _chars("PUNSUBSCRIBE");

  // Scripting
  static List<int> get EVAL => _chars("EVAL");
  static List<int> get SCRIPT => _chars("SCRIPT"); // EXISTS FLUSH KILL LOAD
  static List<int> get KILL => _chars("KILL");
  static List<int> get LOAD => _chars("LOAD");

}
