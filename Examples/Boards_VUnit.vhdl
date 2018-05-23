library vunit_lib;
context vunit_lib.vunit_context;

library JSON;
context JSON.json_ctx;

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
  constant tb_imga : integer_vector := jsonGetIntegerArray(JSONContent, "2");
begin
  main: process
  begin
    test_runner_setup(runner, runner_cfg);
    while test_suite loop
      if run("test") then
        info("tb_path & tb_cfg_file: " & tb_path & tb_cfg_file);
        info("JSONFileContent: " & lf & JSONFileContent.Content);
        info("ML505/FPGA: " & jsonGetString(JSONFileContent, "ML505/FPGA"));
        info("ML505/Eth/0/PHY-Int: " & jsonGetString(JSONFileContent, "ML505/Eth/0/PHY-Int"));
        info("KC705/FPGA: " & jsonGetString(JSONFileContent, "KC705/FPGA"));
        info("KC705/IIC/0/Devices/0/Name: " & jsonGetString(JSONFileContent, "KC705/IIC/0/Devices/0/Name"));

        info("tb_cfg: " & tb_cfg);
        info("JSONContent: " & lf & JSONContent.Content);

        info("Integer array length: " & jsonGetString(JSONContent, "2/1"));
        for i in 0 to tb_imga'length-1 loop
          info("Integer array [" & integer'image(i) & "]: " & integer'image(tb_imga(i)));
        end loop;
      end if;
    end loop;
    test_runner_cleanup(runner);
    wait;
  end process;
end architecture;
