(* Main test entry point that gathers all test cases *)

let () =
  Alcotest.run "Prune test suite"
    [
      Test_warning.tests;
      Test_integration.tests;
      Test_module_alias.tests;
      Test_locate.tests;
      Test_removal_field.tests;
      Test_removal_parsing.tests;
      Test_cache.tests;
    ]
