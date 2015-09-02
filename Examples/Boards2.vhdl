library	IEEE;
use			IEEE.STD_LOGIC_1164.ALL;
use			IEEE.NUMERIC_STD.ALL;

use			work.json.all;

entity Boards2 is
	Port (
		Clock	: in	STD_LOGIC;
		Reset	: in	STD_LOGIC;
		LED		: out	STD_LOGIC_VECTOR (7 downto 0)
	);
end entity;


architecture rtl of Boards2 is
	-- define a json file and parse its content
	constant ConfigFile		: STRING		:= "..\Data\Boards2.json";
	constant JSONContent	: T_JSON		:= jsonLoadFile(ConfigFile);
	
	procedure assertMessage(cond : BOOLEAN; msg : STRING) is
	begin
		if (cond = FALSE) then report msg severity NOTE; end if;
	end procedure;
	
	procedure printMessage(msg : STRING) is
	begin
		report msg severity NOTE;
	end procedure;
	
	-- dummy signal so the entity is not empty for synthesis
	signal Toggle	: STD_LOGIC		:= '0';
	
begin
	-- report a JSON parser error if one occured
--	assert jsonNoParserError(JSONContent) report "JSON parser error: " & jsonGetErrorMessage(JSONContent) severity ERROR;
	assertMessage(jsonNoParserError(JSONContent), "JSON parser error: " & jsonGetErrorMessage(JSONContent));
	-- dump the internal compressed STRING buffer
--	assert FALSE report "JSON: " & jsonTrim(JSONContent.Content) severity NOTE;
	-- dump the internal index structure
--	jsonReportIndex(JSONContent.Index(0 to JSONContent.IndexCount - 1), JSONContent.Content(1 to JSONContent.ContentCount)); 
	
	-- select different values from data structure
--	assert FALSE report "jsonGetString(..., 'KC705/IIC/0/Devices/1/Type'):             " & jsonGetString(JSONContent, "KC705/IIC/0/Devices/1/Type") severity NOTE;
--	assert FALSE report "jsonGetString(..., 'DE4/Ethernet/2/PHY_ManagementInterface'): " & jsonGetString(JSONContent, "DE4/Ethernet/2/PHY_ManagementInterface") severity NOTE;
	
	-- for Vivado, because assert statements got removed from the VHDL feature list ->
	printMessage("jsonGetString(..., 'KC705/IIC/0/Devices/1/Type'):             " & jsonGetString(JSONContent, "KC705/IIC/0/Devices/1/Type"));
	printMessage("jsonGetString(..., 'DE4/Ethernet/2/PHY_ManagementInterface'): " & jsonGetString(JSONContent, "DE4/Ethernet/2/PHY_ManagementInterface"));
	
	-- do something important
	Toggle	<= not Toggle when rising_edge(Clock);
	LED			<= (others => Toggle);
end architecture;
