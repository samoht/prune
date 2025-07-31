(* Main test entry point that gathers all test cases *)

let () =
  Alcotest.run "Prune test suite"
    [
      Test_warning.suite;
      Test_integration.suite;
      Test_module_alias.suite;
      Test_locate.suite;
      Test_removal_field.suite;
      Test_removal_parsing.suite;
      Test_cache.suite;
      ("Comments", Test_comments.suite);
    ]
