#library("RedisClient");
#import("dart:io");
#import("vendor/Mixins/Mixin.dart");


class InMemoryRedisClient {

  Map<String,Object> _keys;

  InMemoryRedisClient() :
    _keys = {};

  Future<List<String>> keys(String pattern){
    Completer<List<String>> task = new Completer<List<String>>();
    List<Object> values = [];
    _keys.forEach((k,v) =>
      if (_globMatch(k, pattern)) values.add(v)
    );
    task.complete(values);
    return task.future;
  }

  Future<Object> get(String key) {
    Completer<Object> task = new Completer<List<Object>>();
    task.complete(_keys[key]);
    return task.future;
  }

  Future<List<Object>> mget(List<String> keys){
    Completer<Object> task = new Completer<List<Object>>();
    List<Object> values = [];
    keys.forEach((x) =>
      if (_keys.containsKey(x)) values.add(v)
    );
    task.complete(values);
    return task.future;
  }

  Future set(String key, Object value){
    Completer task = new Completer();
    _keys[key] = value;
    task.complete(null);
    return task.future;
  }

  Future incr(String key){
    Completer task = new Completer();
    var counter = _keys[key];
    counter = counter == null ? 1 : Math.parseInt(counter.toString())++;
    _keys[key] = counter;
    task.complete(counter);
    return task.future;
  }

  Future del(String key){
    Completer task = new Completer();
    _keys.remove(key);
    task.complete(null);
    return task.future;
  }
}

static bool _globMatch(String key, String withPattern) {
  bool startsWith = withPattern.endsWith("*");
  bool endsWith = withPattern.startsWith("*");
  bool contains = startsWith && endsWith;
  String pattern = withPattern.replaceAll(new RegExp("^\*"),"").replaceAll(new RegExp("^\*"),"");

  return contains
      ? key.indexOf(pattern) >= 0
      : startsWith ?
        key.startsWith(pattern)
      : endsWith ?
        key.endsWith(pattern) :
        key == pattern;
}
