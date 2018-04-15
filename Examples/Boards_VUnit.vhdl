library vunit_lib;
context vunit_lib.vunit_context;

use	work.json.all;

entity tb_boards is
  generic (
    runner_cfg : string;
    tb_path    : string;
    filename   : string
  );
end entity;

architecture tb of tb_boards is
  constant JSONContent : T_JSON := jsonLoadFile(tb_path & filename);
begin
  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test") then
        info(tb_path&filename);
        info("KC705/FPGADevice: " & jsonGetString(JSONContent, "KC705/FPGADevice"));
        info("KC705/IIC/0/Devices/1/Type: " & jsonGetString(JSONContent, "KC705/IIC/0/Devices/1/Type"));
        info("DE4/Ethernet/2/PHY_ManagementInterface: " & jsonGetString(JSONContent, "DE4/Ethernet/2/PHY_ManagementInterface"));
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
