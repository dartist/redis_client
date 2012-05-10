#library("DUnit");

/* 
 * A minimal port of the QUnit subset that Underscore.js uses.
 */

Map<String,Map<String,Function>> _moduleTests; 
String _moduleName;
module (name) {
  if (_moduleTests == null) _moduleTests = new Map<String,Map<String,Function>>();
  _moduleName = name;
  _moduleTests.putIfAbsent(_moduleName, () => {});
}

test(name, Function assertions) {
  _moduleTests[_moduleName][name] = assertions;
}

List<Assertion> _testAssertions;
equal(actual, expected, msg) =>
  _testAssertions.add(new Assertion(actual,expected,msg));
deepEqual(actual, expected, msg) =>
    _testAssertions.add(new Assertion(actual,expected,msg,deepEqual:true));
strictEqual(actual, expected, msg) =>
    _testAssertions.add(new Assertion(actual,expected,msg,strictEqual:true));
ok(actual, msg) =>
  _testAssertions.add(new Assertion(actual,true,msg));

raises(actualFn, expectedTypeFn, msg) {
  try {
    var actual = actualFn();
    _testAssertions.add(new Assertion(actual,"expected error",msg));
  }
  catch (final e) {
    if (expectedTypeFn(e)) 
      _testAssertions.add(new Assertion(true,true,msg));
    else
      _testAssertions.add(new Assertion(e,"wrong error type",msg));
  }
}

runAllTests([bool hidePassedTests=false]){
  int totalTests = 0;
  int totalPassed = 0;
  int totalFailed = 0;
  Stopwatch sw = new Stopwatch.start();
  for (String moduleName in _moduleTests.getKeys()) {
    int testNo = 0;
    Map<String,Function> moduleTests = _moduleTests[moduleName];
    for (String testName in moduleTests.getKeys()) {
      testNo++;
      _testAssertions = new List<Assertion>();
      String error = null;
      try {
        moduleTests[testName]();
      } 
//UnComment to catch and report errors
//      catch(final e){
//        error = "Error while running test #$testNo in $moduleName: $testName\n$e";
//      }
      finally {}
      int total = _testAssertions.length;
      int failed = _testAssertions.filter((x) => !x.success()).length;
      int success = total - failed;

      totalTests  += total;
      totalFailed += failed;
      totalPassed += success;
      
      if (!hidePassedTests || failed > 0) 
        print("$testNo. $moduleName: $testName ($failed, $success, $total)");
      
      for (int i=0; i<_testAssertions.length; i++) {
        Assertion assertion = _testAssertions[i];
        bool fail = !assertion.success();
        if (!hidePassedTests || fail) {
          print("  ${i+1}. ${assertion.msg}");
          if (assertion.expected is! bool)
            print("     Expected ${assertion.expected}");
        }
        if (fail) 
          print("     FAILED was ${assertion.actual}");
      }
      if (error != null) print(error);
    }
    if (!hidePassedTests) print("");
  }
    
  print("\nTests completed in ${sw.elapsedInMs()}ms");
  print("$totalTests tests of $totalPassed passed, $totalFailed failed.");
}

class Assertion {
  var actual, expected;
  bool deepEqual,strictEqual;
  String msg;
  Assertion(this.actual,this.expected,this.msg,[this.deepEqual=false, this.strictEqual=false]);
  success() {
    if (strictEqual) return actual === expected;
    if (!deepEqual) return actual == expected;
    return _eq(actual, expected);
  }
}

_eq(actual, expected) {
  if (actual == null || expected == null) 
    return actual == expected;
   
  if (actual is Map) {
    if (expected is! Map) return false;
    if (actual.length != expected.length) return false;
    for (var key in actual.getKeys()) 
      if (!_eq(actual[key], expected[key])) return false;
    return true; 
  }
  else if (actual is List) {
    if (expected is! List) return false;
    if (actual.length != expected.length) return false;
    int i=0;
    return actual.every((x) => _eq(x, expected[i++]));  
  }
  
  return actual == expected;
}
