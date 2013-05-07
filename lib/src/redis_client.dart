part of redis_client;


abstract class BytesEncoder {
  factory BytesEncoder() => new JsonEncoder();
  List<int> toBytes(Object obj);
  String stringify(Object obj);
  Object toObject(List<int> bytes);
}

abstract class RedisClient {
  factory RedisClient([String connStr]) => new _RedisClient(connStr);
  RedisNativeClient get raw;

  //ADMIN
  int get db;
  Future select(int db);
  Future<DateTime> get lastsave;
  Future<int> get dbsize;
  Future<Map> get info;
  Future flushdb();
  Future flushall();
  Future<bool> ping();
  Future<Object> echo(Object value);
  Future save();
  Future bgsave();
  Future shutdown();
  Future bgrewriteaof();
  Future quit();

  //KEYS
  Future<String> type(String key);
  Future<List<String>> keys(String pattern);
  Future<Object> get(String key);
  Future<List<Object>> mget(List<String> keys);
  Future<Object> getset(String key, Object value);
  Future set(String key, Object value);
  Future setex(String key, int expireInSecs, Object value);
  Future psetex(String key, int expireInMs, Object value);
  Future<bool> persist(String key);
  Future mset(Map map);
  Future<bool> msetnx(Map map);
  Future<bool> exists(String key);
  Future<int> del(String key);
  Future<int> mdel(List<String> keys);
  Future<int> incr(String key);
  Future<int> incrby(String key, int incrBy);
  Future<double> incrbyfloat(String key, double incrBy);
  Future<int> decr(String key);
  Future<int> decrby(String key, int decrBy);
  Future<int> strlen(String key);
  Future<int> append(String key, String value);
  Future<String> substr(String key, int fromIndex, int toIndex);
  Future<String> getrange(String key, int fromIndex, int toIndex);
  Future<String> setrange(String key, int offset, String value);
  Future<int> getbit(String key, int offset);
  Future<int> setbit(String key, int offset, int value);
  Future<String> randomkey();
  Future rename(String oldKey, String newKey);
  Future<bool> renamenx(String oldKey, String newKey);
  Future<bool> expire(String key, int expireInSecs);
  Future<bool> pexpire(String key, int expireInMs);
  Future<bool> expireat(String key, DateTime date);
  Future<bool> pexpireat(String key, DateTime date);
  Future<int> ttl(String key);
  Future<int> pttl(String key);

  //SET
  Future<List<Object>> smembers(String setId);
  Future<int> sadd(String setId, Object value);
  Future<int> smadd(String setId, List<Object> values);
  Future<int> srem(String setId, Object value);
  Future<Object> spop(String setId);
  Future<bool> smove(String fromSetId, String toSetId, Object value);
  Future<int> scard(String setId);
  Future<bool> sismember(String setId, Object value);
  Future<List<Object>> sinter(List<String> setIds);
  Future<int> sinterstore(String intoSetId, List<String> setIds);
  Future<List<Object>> sunion(List<String> setIds);
  Future<int> sunionstore(String intoSetId, List<String> setIds);
  Future<List<Object>> sdiff(String fromSetId, List<String> withSetIds);
  Future<int> sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds);
  Future<Object> srandmember(String setId);

  //LIST
  Future<List<Object>> lrange(String listId, [int startingFrom, int endingAt]);
  Future<int> lpush(String listId, Object value);
  Future<int> mlpush(String listId, List<Object> values);
  Future<int> lpushx(String listId, Object value);
  Future<int> mlpushx(String listId, List<Object> values);
  Future<int> rpush(String listId, Object value);
  Future<int> mrpush(String listId, List<Object> values);
  Future<int> rpushx(String listId, Object value);
  Future<int> mrpushx(String listId, List<Object> values);
  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt);
  Future<int> lrem(String listId, int removeNoOfMatches, Object value);
  Future<int> llen(String listId);
  Future<Object> lindex(String listId, int listIndex);
  Future lset(String listId, int listIndex, Object value);
  Future<Object> lpop(String listId);
  Future<Object> rpop(String listId);
  Future<Object> rpoplpush(String fromListId, String toListId);

  //SORTED SET
  Future<int> zadd(String setId, num score, Object value);
  Future<int> zmadd(String setId, Map<Object,num> scoresMap);
  Future<int> zrem(String setId, Object value);
  Future<int> zmrem(String setId, List<Object> values);
  Future<double> zincrby(String setId, num incrBy, Object value);
  Future<int> zrank(String setId, Object value);
  Future<int> zrevrank(String setId, Object value);
  Future<List<Object>> zrange(String setId, int min, int max);
  Future<Map<Object,double>> zrangeWithScores(String setId, int min, int max);
  Future<List<Object>> zrevrange(String setId, int min, int max);
  Future<Map<Object,double>> zrevrangeWithScores(String setId, int min, int max);
  Future<List<Object>> zrangebyscore(String setId, num min, num max, [int skip, int take]);
  Future<Map<Object,double>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]);
  Future<int> zremrangebyrank(String setId, int min, int max);
  Future<int> zremrangebyscore(String setId, num min, num max);
  Future<int> zcard(String setId);
  Future<double> zscore(String setId, Object value);
  Future<int> zunionstore(String intoSetId, List<String> setIds);
  Future<int> zinterstore(String intoSetId, List<String> setIds);

  //HASH
  Future<bool> hset(String hashId, String key, Object value);
  Future<bool> hsetnx(String hashId, String key, Object value);
  Future hmset(String hashId, Map<String,Object> map);
  Future<int> hincrby(String hashId, String key, int incrBy);
  Future<double> hincrbyfloat(String hashId, String key, double incrBy);
  Future<Object> hget(String hashId, String key);
  Future<List<Object>> hmget(String hashId, List<String> keys);
  Future<int> hdel(String hashId, String key);
  Future<bool> hexists(String hashId, String key);
  Future<int> hlen(String hashId);
  Future<List<String>> hkeys(String hashId);
  Future<List<Object>> hvals(String hashId);
  Future<Map<String,Object>> hgetall(String hashId);

  void close();
}

class _RedisClient implements RedisClient {
  String connStr;
  RedisNativeClient client;
  BytesEncoder bytesEncoder;

  _RedisClient([String this.connStr])
    : bytesEncoder = new BytesEncoder() {
    client = new RedisNativeClient(connStr);
  }

  RedisNativeClient get raw => client;

  //ADMIN
  int get db => client.db;
  Future select(int db) => client.select(db);
  Future<int> get dbsize => client.dbsize;
  Future<DateTime> get lastsave => client.lastsave.transform((int unixTs) => new DateTime.fromMillisecondsSinceEpoch(unixTs * 1000, isUtc:true));
  Future<Map> get info => client.info;
  Future flushdb() => client.flushdb();
  Future flushall() => client.flushall();
  Future<bool> ping() => client.ping();
  Future<Object> echo(Object value) => client.echo(toBytes(value)).transform(toObject);
  Future save() => client.save();
  Future bgsave() => client.bgsave();
  Future shutdown() => client.shutdown();
  Future bgrewriteaof() => client.bgrewriteaof();
  Future quit() => client.quit();

  //KEYS
  Future<String> type(String key) => client.type(key);
  Future<List<String>> keys(String pattern) => client.keys(pattern);
  Future<Object> get(String key) => client.get(key).transform(toObject);
  Future<List<Object>> mget(List<String> keys) => client.mget(keys).transform((x) => x.map(toObject));
  Future<Object> getset(String key, Object value) => client.getset(key, toBytes(value)).transform(toObject);
  Future set(String key, Object value) => client.set(key, toBytes(value));
  Future setex(String key, int expireInSecs, Object value) => client.setex(key, expireInSecs, toBytes(value));
  Future psetex(String key, int expireInMs, Object value) => client.psetex(key, expireInMs, toBytes(value));
  Future<bool> persist(String key) => client.persist(key);
  Future mset(Map map){ _Tuple<List<List<int>>> kvps = keyValueBytes(map); return client.mset(kvps.item1, kvps.item2); }
  Future<bool> msetnx(Map map){ _Tuple<List<List<int>>> kvps = keyValueBytes(map); return client.msetnx(kvps.item1, kvps.item2); }
  Future<bool> exists(String key) => client.exists(key);
  Future<int> del(String key) => client.del(key);
  Future<int> mdel(List<String> keys) => client.mdel(keys);
  Future<int> incr(String key) => client.incr(key);
  Future<int> incrby(String key, int incrBy) => client.incrby(key, incrBy);
  Future<double> incrbyfloat(String key, double incrBy) => client.incrbyfloat(key, incrBy);
  Future<int> decr(String key) => client.decr(key);
  Future<int> decrby(String key, int decrBy) => client.decrby(key, decrBy);
  Future<int> strlen(String key) => client.strlen(key);
  Future<int> append(String key, String value) => client.append(key, toBytes(value));
  Future<String> substr(String key, int fromIndex, int toIndex) => client.substr(key, fromIndex, toIndex).transform(toStr);
  Future<String> getrange(String key, int fromIndex, int toIndex) => client.getrange(key, fromIndex, toIndex).transform(toStr);
  Future<String> setrange(String key, int offset, String value) => client.setrange(key, offset, toBytes(value)).transform(toStr);
  Future<int> getbit(String key, int offset) => client.getbit(key, offset);
  Future<int> setbit(String key, int offset, int value) => client.setbit(key, offset, value);
  Future<String> randomkey() => client.randomkey().transform(toStr);
  Future rename(String oldKey, String newKey) => client.rename(oldKey, newKey);
  Future<bool> renamenx(String oldKey, String newKey) => client.renamenx(oldKey, newKey);
  Future<bool> expire(String key, int expireInSecs) => client.expire(key, expireInSecs);
  Future<bool> pexpire(String key, int expireInMs) => client.pexpire(key, expireInMs);
  Future<bool> expireat(String key, DateTime date) => client.expireat(key, date.toUtc().millisecondsSinceEpoch ~/ 1000);
  Future<bool> pexpireat(String key, DateTime date) => client.pexpireat(key, date.toUtc().millisecondsSinceEpoch);
  Future<int> ttl(String key) => client.ttl(key);
  Future<int> pttl(String key) => client.pttl(key);

  //SET
  Future<List<Object>> smembers(String setId) => client.smembers(setId).transform((x) => x.map(toObject));
  Future<int> sadd(String setId, Object value) => client.sadd(setId, toBytes(value));
  Future<int> smadd(String setId, List<Object> values) => client.smadd(setId, values.map((x) => toBytes(x)));
  Future<int> srem(String setId, Object value) => client.srem(setId, toBytes(value));
  Future<Object> spop(String setId) => client.spop(setId).transform(toObject);
  Future<bool> smove(String fromSetId, String toSetId, Object value) => client.smove(fromSetId, toSetId, toBytes(value));
  Future<int> scard(String setId) => client.scard(setId);
  Future<bool> sismember(String setId, Object value) => client.sismember(setId, toBytes(value));
  Future<List<Object>> sinter(List<String> setIds) => client.sinter(setIds).transform((x) => x.map(toObject));
  Future<int> sinterstore(String intoSetId, List<String> setIds) => client.sinterstore(intoSetId, setIds);
  Future<List<Object>> sunion(List<String> setIds) => client.sunion(setIds).transform((x) => x.map(toObject));
  Future<int> sunionstore(String intoSetId, List<String> setIds) => client.sunionstore(intoSetId, setIds);
  Future<List<Object>> sdiff(String fromSetId, List<String> withSetIds) => client.sdiff(fromSetId, withSetIds).transform((x) => x.map(toObject));
  Future<int> sdiffstore(String intoSetId, String fromSetId, List<String> withSetIds) => client.sdiffstore(intoSetId, fromSetId, withSetIds);
  Future<Object> srandmember(String setId) => client.srandmember(setId).transform(toObject);

  //LIST
  Future<List<Object>> lrange(String listId, [int startingFrom=0, int endingAt=-1]) =>
      client.lrange(listId, startingFrom, endingAt).transform((x) => x.map(toObject));
  Future<int> lpush(String listId, Object value) => client.lpush(listId, toBytes(value));
  Future<int> mlpush(String listId, List<Object> values) => client.mlpush(listId, values.map((x) => toBytes(x)));
  Future<int> lpushx(String listId, Object value) => client.lpushx(listId, toBytes(value));
  Future<int> mlpushx(String listId, List<Object> values) => client.mlpushx(listId, values.map((x) => toBytes(x)));
  Future<int> rpush(String listId, Object value) => client.rpush(listId, toBytes(value));
  Future<int> mrpush(String listId, List<Object> values) => client.mrpush(listId, values.map((x) => toBytes(x)));
  Future<int> rpushx(String listId, Object value) => client.rpushx(listId, toBytes(value));
  Future<int> mrpushx(String listId, List<Object> values) => client.mrpushx(listId, values.map((x) => toBytes(x)));
  Future ltrim(String listId, int keepStartingFrom, int keepEndingAt) => client.ltrim(listId, keepStartingFrom, keepEndingAt);
  Future<int> lrem(String listId, int removeNoOfMatches, Object value) => client.lrem(listId, removeNoOfMatches, toBytes(value));
  Future<int> llen(String listId) => client.llen(listId);
  Future<Object> lindex(String listId, int listIndex) => client.lindex(listId, listIndex).transform(toObject);
  Future lset(String listId, int listIndex, Object value) => client.lset(listId, listIndex, toBytes(value));
  Future<Object> lpop(String listId) => client.lpop(listId).transform(toObject);
  Future<Object> rpop(String listId) => client.rpop(listId).transform(toObject);
  Future<Object> rpoplpush(String fromListId, String toListId) => client.rpoplpush(fromListId, toListId).transform(toObject);

  //SORTED SET
  Future<int> zadd(String setId, num score, Object value) => client.zadd(setId, score, toBytes(value));
  Future<int> zmadd(String setId, Map<Object,num> scoresMap) {
    List<List<int>> args = new List<List<int>>();
    scoresMap.forEach((k,v) {
      args.add(toBytes(v));
      args.add(toBytes(k));
    });
    return client.zmadd(setId, args);
  }
  Future<int> zrem(String setId, Object value) => client.zrem(setId, toBytes(value));
  Future<int> zmrem(String setId, List<Object> values) => client.zmrem(setId, values.map((x) => toBytes(x)));
  Future<double> zincrby(String setId, num incrBy, Object value) => client.zincrby(setId, incrBy, toBytes(value));
  Future<int> zrank(String setId, Object value) => client.zrank(setId, toBytes(value));
  Future<int> zrevrank(String setId, Object value) => client.zrevrank(setId, toBytes(value));
  Future<List<Object>> zrange(String setId, int min, int max) => client.zrange(setId, min, max).transform((x) => x.map(toObject));
  Future<Map<Object,double>> zrangeWithScores(String setId, int min, int max) =>
      client.zrangeWithScores(setId, min, max).transform(_toScoreMap);
  Future<List<Object>> zrevrange(String setId, int min, int max) => client.zrevrange(setId, min, max).transform((x) => x.map(toObject));
  Future<Map<Object,double>> zrevrangeWithScores(String setId, int min, int max) =>
      client.zrevrangeWithScores(setId, min, max).transform(_toScoreMap);
  Future<List<Object>> zrangebyscore(String setId, num min, num max, [int skip, int take]) =>
      client.zrangebyscore(setId, min, max, skip, take).transform((x) => x.map(toObject));
  Future<Map<Object,double>> zrangebyscoreWithScores(String setId, num min, num max, [int skip, int take]) =>
      client.zrangebyscoreWithScores(setId, min, max, skip, take).transform(_toScoreMap);
  Future<int> zremrangebyrank(String setId, int min, int max) => client.zremrangebyrank(setId, min, max);
  Future<int> zremrangebyscore(String setId, num min, num max) => client.zremrangebyscore(setId, min, max);
  Future<int> zcard(String setId) => client.zcard(setId);
  Future<double> zscore(String setId, Object value) => client.zscore(setId, toBytes(value));
  Future<int> zunionstore(String intoSetId, List<String> setIds) => client.zunionstore(intoSetId, setIds);
  Future<int> zinterstore(String intoSetId, List<String> setIds) => client.zinterstore(intoSetId, setIds);

  //HASH
  Future<bool> hset(String hashId, String key, Object value) => client.hset(hashId, key, toBytes(value));
  Future<bool> hsetnx(String hashId, String key, Object value) => client.hsetnx(hashId, key, toBytes(value));
  Future hmset(String hashId, Map<String,Object> map) =>
    client.hmset(hashId, map.keys.map(toBytes), map.values.map(toBytes));
  Future<int> hincrby(String hashId, String key, int incrBy) => client.hincrby(hashId, key, incrBy);
  Future<double> hincrbyfloat(String hashId, String key, double incrBy) => client.hincrbyfloat(hashId, key, incrBy);
  Future<Object> hget(String hashId, String key) => client.hget(hashId, key).transform(toObject);
  Future<List<Object>> hmget(String hashId, List<String> keys) => client.hmget(hashId, keys).transform((x) => x.map(toObject));
  Future<int> hdel(String hashId, String key) => client.hdel(hashId, key);
  Future<bool> hexists(String hashId, String key) => client.hexists(hashId, key);
  Future<int> hlen(String hashId) => client.hlen(hashId);
  Future<List<String>> hkeys(String hashId) => client.hkeys(hashId);
  Future<List<Object>> hvals(String hashId) => client.hvals(hashId).transform((x) => x.map(toObject));
  Future<Map<String,Object>> hgetall(String hashId) => client.hgetall(hashId).transform(_toMap);

  void close() => raw.close();

  Map<String,Object> _toMap(List<List<int>> multiData){
    Map<String,Object> map = new Map<String,Object>();
    for (int i=0; i<multiData.length; i+= 2){
      String key = toStr(multiData[i]);
      map[key] = toObject(multiData[i + 1]);
    }
    return map;
  }

  Map<Object,double> _toScoreMap(List<List<int>> multiData){
    Map<Object,double> map = new Map<String,double>();
    for (int i=0; i<multiData.length; i+= 2){
      Object key = toObject(multiData[i]);
      map[key] = double.parse(toStr(multiData[i + 1]));
    }
    return map;
  }

  List<int> toBytes(Object obj) => bytesEncoder.toBytes(obj);
  Object toObject(List<int> bytes) => bytesEncoder.toObject(bytes);
  static String toStr(List<int> bytes) => bytes == null ? null : new String.fromCharCodes(bytes);

  _Tuple<List<List<int>>> keyValueBytes(Map map){
    List<List<int>> keys = new List<List<int>>();
    List<List<int>> values = new List<List<int>>();
    for(String key in map.keys){
      keys.add(key.runes);
      values.add(toBytes(map[key]));
    }
    return new _Tuple(keys,values);
  }

  dump(arg){
    print(arg);
    return arg;
  }
}

class _Tuple<E> {
  E item1;
  E item2;
  E item3;
  E item4;
  _Tuple(this.item1, this.item2, [this.item3, this.item4]);
}

class JsonEncoder implements BytesEncoder {
  static final int OBJECT_START = 123; // {
  static final int ARRAY_START  = 91;  // [
  static final int ZERO         = 48;  // 0
  static final int NINE         = 57;  // 9
  static final int SIGN         = 45;  // -

  static final String DATE_PREFIX = "/Date(";
  static final String DATE_SUFFIX = ")/";
  static final String TRUE  = "true";
  static final String FALSE = "false";

  List<int> toBytes(Object obj) => stringify(obj).charCodes;

  String stringify(Object obj) =>
      obj == null ?
      ""
    : obj is String ?
      obj
    : obj is DateTime ?
      "/Date(${(obj as DateTime).toUtc().millisecondsSinceEpoch})/"
    : obj is bool || obj is num ?
      obj.toString() :
      JSON.stringify(obj);

  Object toObject(List<int> bytes) =>
      bytes == null || bytes.length == 0 ?
      null
    : _isJson(bytes[0]) ?
      JSON.parse(new String.fromCharCodes(bytes)) :
      _fromBytes(bytes);

  bool _isJson(int firstByte) =>
      firstByte == OBJECT_START || firstByte == ARRAY_START || firstByte == SIGN
   || (firstByte >= ZERO && firstByte <= NINE);

  Object _fromBytes(List<int> bytes){
    try{
      String str = new String.fromCharCodes(bytes);
      if (str.startsWith(DATE_PREFIX)) {
        int epoch = int.parse(str.substring(DATE_PREFIX.length, str.length - DATE_SUFFIX.length));
        return new DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true);
      }
      if (str == TRUE)  return true;
      if (str == FALSE) return false;
      return str;
    } catch(e) { print("ERROR: $e"); }
    return bytes;
  }
}
