package Encodings is

  function base16_encode(constant str: string) return string;
  function base16_decode(constant str: string) return string;

end package;

package body Encodings is

  constant offset_0 : natural := character'pos('0');
  constant offset_U : natural := character'pos('A') - 10;
  constant offset_l : natural := character'pos('a') - 10;

  function to_natural (c: character) return natural is
    variable num: integer := -1;
  begin
    num := character'pos(c);
    case c is
      when '0' to '9' => return num - offset_0;
      when 'A' to 'F' => return num - offset_U;
      when 'a' to 'f' => return num - offset_l;
      when others => return -1;
    end case;
  end;

  function to_character(num: natural) return character is
  begin
    if num<10 then
      return character'val(offset_0 + num);
    end if;
    return character'val(offset_l + num);
  end;

  function base16_encode(constant str: string) return string is
    constant str_i : string(1 to str'length) := str;
    variable result: string (1 to str'length * 2);
    variable num: natural;
  begin
    for x in str_i'range loop
      num := character'pos(str_i(x));
      result(2*x-1 to 2*x) := to_character(num / 16) & to_character(num rem 16);
    end loop;
    return result;
  end function;

  function base16_decode(constant str: string) return string is
    alias str_i : string(1 to str'length) is str;
    variable result: string (1 to (str'length + 1) /2);
  begin
    for x in result'range loop
      result(x) := character'val(to_natural(str_i(2*x-1)) *16 + to_natural(str_i(2*x)));
    end loop;
    return result;
  end function;

end package body;
