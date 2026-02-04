(* Main test entry point that gathers all test cases *)

let () =
  Alcotest.run "Prune test suite"
    [
      Test_warning.suite;
      Test_module_alias.suite;
      Test_locate.suite;
      Test_cache.suite;
      ("Comments", Test_comments.suite);
      Test_analysis.suite;
      Test_doctor.suite;
      Test_occurrence.suite;
      Test_output.suite;
      Test_progress.suite;
      Test_prune.suite;
      Test_removal.suite;
      Test_show.suite;
      Test_system.suite;
      Test_types.suite;
    ]
