library vunit_lib;
context vunit_lib.vunit_context;

use	work.json.T_JSON;
use work.json.jsonLoad;
use work.json.jsonGetString;

entity tb_boards is
  generic (
    runner_cfg  : string;
    tb_path     : string;
    tb_cfg      : string;
    tb_cfg_file : string
  );
end entity;

architecture tb of tb_boards is
  constant JSONContent     : T_JSON := jsonLoad(tb_cfg);
  constant JSONFileContent : T_JSON := jsonLoad(tb_cfg_file);
begin
  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test") then
        info("tb_cfg: " & tb_cfg);
        info("JSONContent: " & lf & JSONContent.Content);
        info("ML505/FPGA: " & jsonGetString(JSONContent, "ML505/FPGA"));
        info("ML505/Eth/0/PHY-Int: " & jsonGetString(JSONContent, "ML505/Eth/0/PHY-Int"));
        info("KC705/FPGA: " & jsonGetString(JSONContent, "KC705/FPGA"));
        info("KC705/IIC/0/Devices/0/Name: " & jsonGetString(JSONContent, "KC705/IIC/0/Devices/0/Name"));

        info("tb_path & tb_cfg_file: " & tb_path & tb_cfg_file);
        info("JSONFileContent: " & lf & JSONFileContent.Content);
        info("ML505/FPGADevice: " & jsonGetString(JSONFileContent, "ML505/FPGADevice"));
        info("ML505/Ethernet/0/PHY_Device: " & jsonGetString(JSONFileContent, "ML505/Ethernet/0/PHY_Device"));
        info("KC705/FPGADevice: " & jsonGetString(JSONFileContent, "KC705/FPGADevice"));
        info("KC705/IIC/0/Devices/0/Type: " & jsonGetString(JSONFileContent, "KC705/IIC/0/Devices/0/Type"));
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
