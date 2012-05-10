#library("Mixin");
#import("dart:core");

$(target){
  for (Function factory in Mixin.factories) {
    var $target = factory(target);
    if ($target != null) return $target;
  }
  return target;
}

//TODO: Rename to $ when Dart adds support for callable classes
class Mixin {
  var e;
  Mixin(this.e);

  static List _factories;
  static List get factories() {
    if (_factories == null) {
      _factories = [
        (target) => target is Mixin ? target : null,
        (target) => target is Collection ? new List$(target) : null, 
        (target) => target is Map ? new Map$(target) : null,
        (target) => target is String ? new String$(target) : null,
        (target) => target is num ? new Num$(target) : null,
        (target) => target is Function ? new Function$(target) : null,
        (target) => new Mixin(target),
      ];
    }
    return _factories;
  }
  
  /* Register your own factory. 
   * New factory is given the first opportunity to handle new invocations of $(). 
   * Return a wrapped Mixin if target is a match; otherwise null to let other factories handle object.  
   */
  static void registerFactory(Mixin factory(target)) => factories.insertRange(0, 1, factory);
  
  valueOf() => e;
  int get length() => e.length;
  bool isEqual(to) => e == to;
  bool isElement() => e != null && e['nodeType'] == 1;
  bool isArray() => e is List;
  bool isObject() => e == null ? false : e is Object && !(e is String || e is num || e is bool);
  bool isFunction() => e is Function;
  bool isString() => e is String;
  bool isNumber() => e is num;
  bool isFinite() => e is num && !e.isNaN() && !e.isInfinite();
  bool isNaN() => e == null ? false : e.isNaN();
  bool isBoolean() => e is bool;
  bool isDate() => e is Date;
  bool isRegExp() => e is RegExp;
  bool isNull() => e == null;
  bool isUndefined() => isNull(); 
  bool isFalsy() => _isFalsy(e); 
  bool isTruthy() => !_isFalsy(e); 
  int size() => e.length;
  bool isEmpty() => e is RegExp ? true : _isFalsy(e);

  List toArray() => e == null ? 
      [] : 
    e is List ? 
      _cloneList(e) : 
    e is Map ? 
      (e['toArray'] is Function ?
        e['toArray']() :
        e.getValues())
    : new List.from(e);
        
  void each(f(x)) {
    if (e == null) return;
    if (e is Collection) e.forEach(f);
    else if (e is Map) e.forEach((k,v) => f(v));
  }
  void forEach(f(x)) => each(f);
  
  map(f(x)) {
    if (e == null) return [];
    return e.map(f);
  }
  void collect(f(x)) => map(f);
  
  reduce(f(x,y), [memo]) {
    if (e == null)
      if (memo == null)
        throw new TypeError$('Reduce of empty array with no initial value');
      else return memo;
    return List$.fn(e).reduce(f,memo);
  }
  void foldl(f(x,y), [memo]) => reduce(f,memo);
  void inject(f(x,y), [memo]) => reduce(f,memo);
  
  reduceRight(f(x,y), [memo]) => e == null 
      ? reduce(f,memo) //same behavior if null
      : List$.fn(e).reduceRight(f,memo);  
  void foldr(f(x,y), [memo]) => reduceRight(f,memo);
  
  static int _idCounter = 0;
  static uniqueId ([prefix]) {
    int id = _idCounter++;
    return prefix == null ? "$prefix$id" : id;
  }
  
  result(key) { 
    if (e == null) return null;
    var val = e[key];
    return val is Function ? val(e) : val;
  }
  
  indexOf(needle) {
    if (e == null || needle == null) return -1;
    return e.indexOf(needle);
  }
  
  lastIndexOf(needle) {
    if (e == null || needle == null) return -1;
    return e.lastIndexOf(needle);
  }
  
  clone() => e is List ? _cloneList(e) : e is Map ? _cloneMap(e) : e;
  
  functions() { throw "Reflection Api not supported in Dart yet"; }
  
  static Map _mixins;
  static void mixin (obj) {
    if (_mixins == null) _mixins = {}; //TODO: remove after Dart gets static lazy initialization
    Map$.fn(obj).functions().forEach((name){
      _mixins[name] = obj[name];
    });
  }

  noSuchMethod(name, args) {
    if (_mixins == null) _mixins = {}; //TODO: remove after Dart gets static lazy initialization
    Function fn = _mixins[name];
    if (fn == null) throw new TypeError$('Method $name not implemented');
    var len = args.length;
    //TODO replace with generic sln when Dart gets varargs + Function call/apply ops
    //print("calling fn with $len args..");
    return len == 0 
        ? fn(e)
        : len == 1
          ? fn(e, args[0])
          : len == 2
            ? fn(e, args[0],args[1])
            : fn(e, args[0],args[1],args[2]);
  }
  
  static identity(x) => x;
    
  static List range ([start=0, stop=null, step=1]) {
    if (stop==null) {
      stop = start;
      start = 0;
    }

    int len = Math.max(((stop - start) / step).ceil(), 0).toInt();
    int idx = 0;
    List res = new List(len);

    while(idx < len) {
      res[idx++] = start;
      start += step;
    }

    return res;
  }
  
  tap(Expr interceptor) {
    interceptor(e);
    return e;
  }
    
  String toDebugString() => String$.debugString(e);
}

class Num$ extends Mixin {
  num target;
  Num$(target) : super(target) {
    this.target = target;
  }

  static Num$ fn(n) => new Num$(n);

  times(iterator(int n)) {
    for (int i = 0; i < e; i++) iterator(i);
  }    
}

class String$ extends Mixin {
  String target;
  String$(target) : super(target) {
    this.target = target == null 
      ? ""
      : target is String 
        ? target 
        : "$target";
  }

  static String$ fn(string) => new String$(string);
  
  String escape() =>
    target.replaceAll(new RegExp("&"), '&amp;')
          .replaceAll(new RegExp("<"), '&lt;')
          .replaceAll(new RegExp(">"), '&gt;')
          .replaceAll(new RegExp('"'), '&quot;')
          .replaceAll(new RegExp("'"), '&#x27;')
          .replaceAll(new RegExp('/'),'&#x2F;');

  bool isBlank() => new RegExp(@"^\s*$").hasMatch(target);  
  String trim() => target.trim();
  String stripTags() => target.replaceAll(new RegExp("<\/?[^>]+>"), '');
  String capitalize() => "${target[0].toUpperCase()}${target.substring(1)}";
  List chars() => target.charCodes();
  List lines() => target.split(new RegExp(@"\n"));

  String clean() => trim().replaceAll(new RegExp(@"\s+"), ' ').trim();
  
  String replaceAllMatches(Pattern pattern, String f(Match)) {
    StringBuffer sb = new StringBuffer();
    int lastEnd = 0;
    $(pattern.allMatches(target)).forEach(
      (Match m) {
        sb.add(target.substring(lastEnd, m.start()));
        sb.add(f(m));
        lastEnd = m.end();
      });
    sb.add(target.substring(lastEnd));
    return sb.toString();
  }

  String titleize(){    
    List arr = target.split(' ');
    List to = new List();
    for (var i=0; i < arr.length; i++) {
      List word = arr[i].split('');      
      if (word.length > 0 && word[0] != null) 
        word[0] = word[0].toUpperCase();      
      var val = (i+1 == arr.length)
          ? List$.fn(word).join('') 
          : "${List$.fn(word).join('')} ";
       to.add(val);
    }
    return List$.fn(to).join('');
  }
  
  String underscored() => $(trim())
     .replaceAllMatches(new RegExp(@"([a-z\d])([A-Z]+)"), (m) => "${m.group(1)}_${m.group(2)}")
     .replaceAll(new RegExp(@"\-|\s+"), '_')
     .replaceAll(new RegExp("-"), '_')
     .toLowerCase();
  
  String dasherize() => $($(trim())
    .replaceAllMatches(new RegExp(@"([a-z\d])([A-Z]+)"), (m) => "${m.group(1)}-${m.group(2)}"))
    .replaceAllMatches(new RegExp("^([A-Z]+)"), (m) => '-${m.group(1)}')
    .replaceAll(new RegExp(@"\_|\s+"), '-')
    .toLowerCase();
  
  humanize() => fn(underscored().replaceAll(new RegExp(@"_id$"),'').replaceAll("_", ' ')).capitalize();
  
  succ() => "${target.substring(0, target.length - 1)}${new String.fromCharCodes([target.charCodeAt(target.length - 1) + 1])}";

  truncate(length, [String truncateStr='...']) => 
      target.length > length ? "${target.substring(0,length)}$truncateStr" : target;
      
  List words([Pattern delimiter=" "]) => trim().replaceAll(new RegExp(@"\s+"), " ").split(delimiter);
  
  String repeat([int times=0, String seperator='']) => _strRepeat(target, times, seperator);

  static final int _PAD_LEFT = 1;
  static final int _PAD_RIGHT = 2;
  static final int _PAD_BOTH = 3;
  
  String pad(int length, [String padStr=null, int type]) {
    String padding = '', str = target;
    int padlen  = 0;

    if (padStr == null) padStr = ' ';
    else if (padStr.length > 1) padStr = padStr[0]; 
    switch(type) {
      case _PAD_LEFT:
        padlen = (length - target.length);
        padding = _strRepeat(padStr, padlen);
        return "$padding$target";
      case _PAD_RIGHT:
        padlen = (length - target.length);
        padding = _strRepeat(padStr, padlen);
        return "$target$padding";
      case _PAD_BOTH:
        padlen = (length - str.length);
        String _prefix  = _strRepeat(padStr, (padlen/2).ceil().toInt());
        String _suffix = _strRepeat(padStr, (padlen/2).floor().toInt());
        return "$_prefix$target$_suffix";
    }
  }

  padLeft(int length, [String padStr]) => pad(length, padStr, _PAD_LEFT);
  lpad(int length, [String padStr]) => pad(length, padStr, _PAD_LEFT);
  padRight(int length, [String padStr]) => pad(length, padStr, _PAD_RIGHT);
  rpad(int length, [String padStr]) => pad(length, padStr, _PAD_RIGHT);
  padBoth(int length, [String padStr]) => pad(length, padStr, _PAD_BOTH);
  lrpad(int length, [String padStr]) => pad(length, padStr, _PAD_BOTH);
    
  String reverse() => List$.fn(List$.fn(target.split('')).reverse()).join('');
 
  List split(Pattern pattern) => target.split(pattern);
  
  List<String> splitOnFirst(String needle){
    int pos;
    return needle == null ? 
        []
      : (pos = target.indexOf(needle)) == -1 ?
        [target] :
        [target.substring(0, pos), target.substring(pos + 1)];
  }
      
  List<String> splitOnLast(String needle){
    int pos;
    return needle == null ? 
        []
      : (pos = target.lastIndexOf(needle)) == -1 ?
        [target] :
        [target.substring(0, pos), target.substring(pos + 1)];
  }
          
  static String debugString(str) => 
    "$str".replaceAll("[", "")
          .replaceAll("]", "")
          .replaceAll("null", "")
          .replaceAll(" ", "");
}

class List$ extends Mixin {
  List target;
  List$(target) : super(target) {
    this.target = target == null 
      ? []
      : target is List 
        ? target 
        : new List.from(target);
  }
  
  operator [](int index) => target[index];
  void operator []=(int index, value) {
    target[index] = value;
  } 

  static List$ fn(list) => new List$(list);
  List get value() => target;
  num sum() => reduce((memo, value) => memo + value, 0);
  List clone() => _cloneList(target);
  void insert(int index, item) => target.insertRange(index, 1, item);      
  
  List reverse() {
    List to = new List();
    int i=target.length;
    while (--i>=0) to.add(target[i]);
    return to; 
  }
  
  List sort([int comparer(x,y)]) { 
    if (comparer == null) comparer=(x,y) => x.compareTo(y);
    target.sort(comparer); 
    return target; 
  }
  
  reduce(IteratorFn iterator, [memo]) {
    bool hasInitial = memo != null;
    target.forEach((value) {
      if (!hasInitial) {
        memo = value;
        hasInitial = true;
      } else {
        memo = iterator(memo, value);
      }
    });
    if (!hasInitial) throw new TypeError$('Reduce of empty array with no initial value');
    return memo;
  }
  foldl(IteratorFn iterator,  [memo]) => reduce(iterator, memo); 
  inject(IteratorFn iterator, [memo]) => reduce(iterator, memo); 

  reduceRight(IteratorFn iterator, [memo]) => fn(reverse()).reduce(iterator, memo);
  foldr(IteratorFn iterator, [memo]) => reduceRight(iterator, memo); 
  
  single(_Predicate match) {
    var res;
    for (var value in target) {
      if (match(value)) {
        res = value;
        break;
      }
    }
    return res;
  }
  find(_Predicate match)   => single(match);
  detect(_Predicate match) => single(match);
  
  List filter(_Predicate match) => target.filter(match);
  List select(_Predicate match) => target.filter(match);
  List map(Function convert) => target.map(convert);
  void forEach(Function f) => target.forEach(f);
  void each(Function f) => target.forEach(f);
  bool every(_Predicate match) => target.every(match);
  bool all(_Predicate match) => every(match);
  bool some([_Predicate match]) => target.some(match != null ? match : (x) => !_isFalsy(x));
  bool any([_Predicate match]) => some(match);
  bool isEmpty() => target.isEmpty();
  void add(item) => target.add(item);
  void addLast(item) => target.addLast(item);
  void addAll(Collection collection) => target.addAll(collection);
  void clear() => target.clear();
  removeLast() => target.removeLast();
  List getRange(int start, int length) => target.getRange(start, length);
  void setRange(int start, int length, List from, [int startFrom]) => target.setRange(start, length, from, startFrom);
  
  reject(_Predicate match) => target.filter((x) => !match(x));
  
  List pluck(String key) => map((value) => value[key]);
  
  include(item) => target.indexOf(item) != -1;
  contains(item) => include(item);
  
  static final int MaxInt = 2^32-1;
  Date MinDate; //TODO: use lazy static initialization when available
  max([Expr expr]) {
    if (MinDate == null) MinDate = new Date.fromEpoch(0, new TimeZone.utc());
    if (isEmpty()) return double.NEGATIVE_INFINITY;
    var firstArg = target[0];
    var res = {'computed': firstArg is Date ? MinDate : double.NEGATIVE_INFINITY};
    each((value) {
      var computed = expr != null ? expr(value) : value;
      computed.compareTo(res['computed']) >= 0 && (res = {'value': value, 'computed': computed}) != null;
    });
    return res['value'];
  }
  
  Date MaxDate; //TODO: use lazy static initialization when available
  min([Expr expr]) {
    if (isEmpty()) return double.INFINITY;
    if (MaxDate == null) MaxDate = new Date.fromEpoch(MaxInt, new TimeZone.utc());
    var firstArg = target[0];
    var res = {'computed': firstArg is Date ? MaxDate : double.INFINITY};
    each((value) {
      var computed = expr != null ? expr(value) : value;
      computed.compareTo(res['computed']) < 0 && (res = {'value': value, 'computed': computed}) != null;
    });
    return res['value'];
  }
  
  shuffle() {
    List shuffled = clone();
    int index=0;
    each((value) {
      int rand = (Math.random() * (index + 1)).floor().toInt();
      shuffled[index] = shuffled[rand];
      shuffled[rand] = value;
      index++;
    });
    return shuffled;
  }  
  
  sortBy(val) {
    List l = [2,3,4];
    Function iterator = val is Function ? val : (obj) => obj[val];
    return fn(
      fn(
        map((value) => {
          'value': value,
          'criteria': iterator(value)
        })
      )
      .sort((left, right) {
        var a = left['criteria'], b = right['criteria'];
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      })
    ).pluck('value');
  }
  
  Map groupBy(val) {
    Map res = {};
    Function iterator = val is Function ? val : (obj) => obj[val];
    each((value) {
      var key = iterator(value);
      if (res["$key"] == null) res["$key"] = [];
      res["$key"].add(value);
    });
    return res;
  }
  
  sortedIndex(obj, [Function iterator]) {
    if (iterator == null) iterator = Mixin.identity;
    int low = 0, high = target.length;
    while (low < high) {
      var mid = (low + high) >> 1;
      iterator(target[mid]) < iterator(obj) ? low = mid + 1 : high = mid;
    }
    return low;
  }
  
  first([int n]) => n != null 
      ? target.getRange(0, n <= target.length ? n : target.length) 
      : target[0];
  head([int n]) => first(n);
  take([int n]) => first(n);

  initial([int n]) => target.getRange(0, target.length - (n == null ? 1 : n));
  
  last([int n]) {
    if (n == null) return target.last(); 
    int startAt = Math.max(target.length - n, 0);
    return target.getRange(startAt, target.length - startAt);
  }
  
  rest([int n]) => target.getRange(n == null ? 1 : n, target.length - (n == null ? 1 : n));  
  tail([int n]) => rest(n);
  
  compact() => filter((value) => _isFalsy(value));
  
  List flatten([shallow=false]) {
    return reduce((List memo, value) {
      if (value is List) 
        memo.addAll(shallow ? value : fn(value).flatten());
      else 
        memo.add(value);
      return memo;
    }, []);
  }
  
  uniq([isSorted=false, iterator]) {
    var init = iterator is Function ? map(iterator) : target;
    List results = [];
    // The `isSorted` flag is irrelevant if the array only contains two elements.
    if (target.length < 3) isSorted = true;
    int index = 0;
    fn(init).reduce((List memo, value) {
      bool exists = isSorted ? memo.length == 0 || memo.last() != value : memo.indexOf(value) == -1;
      if (exists) {
        memo.add(value);
        results.add(target[index]);
      }
      index++;
      return memo;
    },[]);
    return results;
  }
  unique([isSorted, iterator]) => uniq(isSorted, iterator);
  
  join([delim=',']) => reduce((memo,x) => memo.isEmpty() ? "$x" : "$memo$delim$x","");
//  join([delim=',']) => Strings.join(target, delim);  
  
  static concat(List<List> lists) {
    List to = [];
    lists.forEach((x) => to.addAll(x));
    return to;
  }
    
  //TODO: replace with varargs
  intersection(List<List> with) =>
    uniq().filter((item) =>
      with.every( (other) => other.indexOf(item) >= 0 )
    ); 
  intersect(List<List> with) => intersection(with);
  
  difference(List<List> with) {
    List _rest = fn(with).flatten(true);
    return filter((value) => !fn(_rest).include(value) );
  }
  without(List<List> with) => difference(with);
  union(List<List> with) => fn(fn(concat([target,with])).flatten(true)).uniq();
  
  static zip(List args) {
    int length = fn(args.map((x) => x.length)).max();
    List results = new List(length);
    var $args = $(args);
    for (int i = 0; i < length; i++) results[i] = $args.map((x) => i < x.length ? x[i] : null);
    return results;
  }
  
//TODO: requires currying
//  invoke (method) {
//    var args = slice.call(arguments, 2);
//    return _.map(obj, function(value) {
//      return (_.isFunction(method) ? method || value : value[method]).apply(value, args);
//    });
//  };    
}

class Map$ extends Mixin {
  Map target;
  Map$(target) : super(target) {
    this.target = target == null ? {} : target;
  }

  operator [](key) => target[key];
  void operator []=(key, value) {
    target[key] = value;
  } 
  
  static Map$ fn(e) => new Map$(e);
  
  Collection keys() => target.getKeys();
  Collection getKeys() => target.getKeys();
  Collection values() => target.getValues();
  Collection getValues() => target.getValues();

  bool isEmpty() => target.isEmpty();    
  bool containsKey() => target.containsKey(target);
  bool has() => target.containsKey(target);
  bool containsValue(item) => target.containsValue(item);
  bool include(item) => target.containsValue(item);
  bool contains(item) => include(item);
  
  Map map(iterator(val)) {
    Map res = {};    
    for (var key in target.getKeys()){
      res[key] = iterator(target[key]);
    }
    return res;
  }

  Map clone() => _cloneMap(target);
  
  max([Expr expr]) => List$.fn(target.getValues()).max(expr);
  min([Expr expr]) => List$.fn(target.getValues()).min(expr);

  List functions() {
    List<String> names = [];
    for (var key in target.getKeys()) {
      if (target[key] is Function) names.add(key);
    }
    names.sort((String x, String y) => x.compareTo(y));
    return names;
  }
  methods() => functions();
  
  //TODO: Change to var args
  pick(List names) {
    Map res = {};
    for (var key in $(names).flatten()) {
      if (target.containsKey("$key")) res["$key"] = target["$key"];
    }
    return res;
  }

  //TODO: support varargs defaultProps
  defaults(defaultProps) {
    if (defaultProps is Map) defaultProps = [defaultProps];
    defaultProps.forEach((source) {
      source.forEach((key, value){
        if (!target.containsKey(key)) target[key] = value;
      });
    });
    return target;
  }

//  _.extend Requires Reflection  
}

class Function$ extends Mixin {
  Function target;
  Function$(target) : super(target) {
    this.target = target == null ? {} : target;
  }

  static Function$ fn(e) => new Function$(e);
  
  invoke([arg1, arg2, arg3, arg4]) => _call(target, arg1, arg2, arg3, arg4);
    
  memoize([Function hasher]) {
    Map memo = {};
    if (hasher == null) hasher = Mixin.identity;
    return ([arg1, arg2, arg3, arg4]) {
      var key = _call(hasher, arg1, arg2, arg3, arg4);
      return memo.containsKey(key) ? memo[key] : (memo[key] = _call(target, arg1, arg2, arg3, arg4));
    };
  }
  
  //requires core:Timer
//  delay(Function func, int waitMs) => null;    
//  defer(Function func) => delay(func, 1);
//  throttle(Function func, int waitMs) => null;
//  debounce(Function func, int waitMs, bool immediate) => null;
  
  once() {
    bool ran = false;
    var memo;
    return ([arg1, arg2, arg3, arg4]) {
      if (ran) return memo;
      ran = true;
      return memo = _call(target, arg1, arg2, arg3, arg4);
    };
  }
  
  wrap(wrapper) => ([arg1, arg2, arg3]) => _call(wrapper, target, arg1, arg2, arg3);

  compose(Function f1, [Function f2, Function f3, Function f4]) {
    List funcs = [target,f1];
    if (f2 != null) funcs.add(f2);
    if (f3 != null) funcs.add(f3);
    if (f4 != null) funcs.add(f4);
    return ([arg]) {
      List args = [arg];
      for (int i = funcs.length - 1; i >= 0; i--) {
        args = [_call(funcs[i], args[0])];
      }
      return args[0];
    };
  }
  
  after(int times) {
    if (times <= 0) return target();
    return ([arg1, arg2, arg3, arg4]) {
      if (--times < 1) return _call(target, arg1, arg2, arg3, arg4); 
    };
  }
  
}

typedef IteratorFn(memo, value);
typedef bool _Predicate(item);
typedef Dynamic Expr(item);

class TypeError$ {
  String msg;
  TypeError$(this.msg) {
//    print("TypeError $msg");
  }
  static type(x) => x is TypeError$;
}

_isFalsy(e) => e == null || e == false || e == 0 || e == double.NAN || e == '';
_cloneList(List from) {
  List to = [];
  for (var item in from) to.add(item);
  return to;
}
_cloneMap(Map from) {
  Map to = {};
  for (var key in from.getKeys())
    to[key] = from[key];
  return to;
}
_strRepeat(String str, int i, [String seperator='']) {
  List to = new List(i);
  for (; i > 0; to[--i] = i == 1 ? str : "$str$seperator") {}
  return List$.fn(to).join('');
}
_call(func, [arg1, arg2, arg3, arg4]) {
  return arg4 != null ? 
      func(arg1, arg2, arg3, arg4)
    : arg3 != null ? 
      func(arg1, arg2, arg3)
    : arg2 != null ? 
      func(arg1, arg2)
    : arg1 != null ? 
      func(arg1) : 
      func();
}
