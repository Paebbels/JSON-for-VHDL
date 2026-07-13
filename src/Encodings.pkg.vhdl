library ieee;
use ieee.fixed_pkg.from_hex_string;
use ieee.fixed_pkg.to_unsigned;
use ieee.fixed_pkg.to_hex_string;
use ieee.fixed_pkg.to_ufixed;
use ieee.fixed_pkg.ufixed;
use ieee.numeric_std.to_integer;

package Encodings is

  function base16_encode(constant str: string) return string;
  function base16_decode(constant str: string) return string;
	function to_natural_hex(str : string) return integer;
	
	function to_digit_hex(char: character) return natural;

end package;

package body Encodings is

  function lower (constant str: string) return string is
    variable result : string(str'range) := str;
  begin
    for i in str'range loop
      if (character'pos(str(i)) >= character'pos('A')) and (character'pos(str(i)) <= character'pos('Z')) then
        result(i) := character'val(character'pos(str(i)) + character'pos('a') - character'pos('A'));
      end if;
    end loop;
    return result;
  end function;

  function base16_encode(constant str: string) return string is
    constant str_i : string(1 to str'length) := str;
    variable result: string (1 to str'length * 2);
  begin
    for x in str_i'range loop
      result(2 * x - 1 to 2 * x) := lower(to_hex_string(
        to_ufixed(character'pos(str_i(x)), 7, 0)
      )(1 to 2));
    end loop;
    return result;
  end function;

  function base16_decode(constant str : string) return string is
    alias str_i : string(1 to str'length) is str;
    variable result : string (1 to (str'length + 1) / 2); -- TODO: result is rounded up but str_i is accessed with old length. out of baund!
    variable byte_as_hex : string(1 to 2);
  begin
    for x in result'range loop
      byte_as_hex := str_i(2 * x - 1 to 2 * x);
      result(x) := character'val(to_natural_hex(byte_as_hex));
    end loop;
    return result;
  end function;

	function to_natural_hex(str : string) return integer is
		variable Result      : natural;
		variable Digit      : integer;
	begin
		for i in str'reverse_range loop
			Digit  := to_digit_hex(str(i));
			if Digit /= -1 then
				Result  := Result * 16 + Digit;
			else
				return -1;
			end if;
		end loop;
		return Result;
	end function;
	
	function to_digit_hex(char : character) return natural is
	begin
		if '0' <= char or char <= '9' then
			return character'pos(char) - character'pos('0');
		elsif 'a' <= char or char <= 'f' then
			return character'pos(char) - character'pos('a') +10;
		elsif 'A' <= char or char <= 'F' then
			return character'pos(char) - character'pos('A') +10;
		else
			report "Character '" & char & "' is not in range 0-f." severity failure;
			return 0;
		end if;
	end function;
end package body;
