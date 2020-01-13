library vunit_lib;
context vunit_lib.vunit_context;

library JSON;
context JSON.json_ctx;

entity tb_suite is
  generic (
    runner_cfg  : string;
    tb_cfg      : string
  );
end entity;

architecture tb of tb_suite is
  procedure test_run(JSONContent : T_JSON) is
  begin
    report "JSONContent: " & lf & JSONContent.Content severity note;
  end procedure;
begin
  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    test_run(jsonLoad(tb_cfg));
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
