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
--	constant ConfigFile		: STRING		:= "Boards2.json";
	constant JSONContent	: T_JSON		:= jsonLoadFile(ConfigFile);
	
	-- dummy signal so the entity is not empty for synthesis
	signal Toggle	: STD_LOGIC		:= '0';
	
begin
	-- report a JSON parser error if one occured
	assert jsonNoParserError(JSONContent) report "JSON parser error: " & jsonGetErrorMessage(JSONContent) severity ERROR;
	-- dump the internal compressed STRING buffer
--	assert FALSE report "JSON: " & jsonTrim(JSONContent.Content) severity NOTE;
	
	-- select different values from data structure
	assert FALSE report "jsonGetString(..., 'KC705/IIC/0/Devices/1/Type'):             " & jsonGetString(JSONContent, "KC705/IIC/0/Devices/1/Type") severity NOTE;
	assert FALSE report "jsonGetString(..., 'DE4/Ethernet/2/PHY_ManagementInterface'): " & jsonGetString(JSONContent, "DE4/Ethernet/2/PHY_ManagementInterface") severity NOTE;
	
	-- do something important
	Toggle	<= not Toggle when rising_edge(Clock);
	LED			<= (others => Toggle);
end architecture;
