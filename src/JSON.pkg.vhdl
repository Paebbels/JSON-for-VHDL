-- =============================================================================
--       _ ____   ___  _   _        __              __     ___   _ ____  _
--      | / ___| / _ \| \ | |      / _| ___  _ __   \ \   / / | | |  _ \| |
--   _  | \___ \| | | |  \| |_____| |_ / _ \| '__|___\ \ / /| |_| | | | | |
--  | |_| |___) | |_| | |\  |_____|  _| (_) | | |_____\ V / |  _  | |_| | |___
--   \___/|____/ \___/|_| \_|     |_|  \___/|_|        \_/  |_| |_|____/|_____|
--
-- =============================================================================
-- Authors:                    Patrick Lehmann
--
-- Package:                    JSON parser and query routines
--
-- Description:
-- ------------------------------------
--        For detailed documentation see below.
--
-- License:
-- ============================================================================
-- Copyright 2017-2026 Patrick Lehmann - Boetzingen, Germany
-- Copyright 2007-2016 Patrick Lehmann - Dresden, Germany
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--        http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

use     Std.TextIO.all;

library    IEEE;
use     IEEE.STD_LOGIC_1164.all;


use     work.Encodings.all;

package JSON is
	constant C_JSON_VERBOSE : boolean   := FALSE;
	constant C_JSON_NUL     : character := NUL;   -- TODO: remove this because of an old Altera Quartus issue.

	subtype T_UINT16 is natural range 0 to 2**16-1;
	type T_NATVEC is array(natural range <>) of natural;

	type T_ELEMENT_TYPE is (ELEM_KEY, ELEM_OBJECT, ELEM_LIST, ELEM_string, ELEM_LINK, ELEM_NUMBER, ELEM_NULL, ELEM_TRUE, ELEM_FALSE);

	type T_JSON_INDEX_ELEMENT    is record
		Index       : T_UINT16;
		ChildIndex  : T_UINT16;
		NextIndex   : T_UINT16;
		StringStart : T_UINT16;
		StringEnd   : T_UINT16;
		ElementType : T_ELEMENT_TYPE;
	end record;

	type T_JSON_INDEX is array(natural range <>) of T_JSON_INDEX_ELEMENT;

	constant C_JSON_ERROR_MESSAGE_LENGTH : natural  := 64;
	constant C_JSON_INDEX_MAX            : T_UINT16 := 1023;
	constant C_JSONFILE_INDEX_MAX        : T_UINT16 := 4*C_JSON_INDEX_MAX;

	type T_JSON is record
		Content      : string(1 to T_UINT16'high);
		ContentCount : T_UINT16;
		Index        : T_JSON_INDEX(0 to C_JSON_INDEX_MAX);
		IndexCount   : T_UINT16;
		Error        : string(1 to C_JSON_ERROR_MESSAGE_LENGTH);
	end record;

	type T_JSON_PATH_ELEMENT_TYPE is (PATH_ELEM_KEY, PATH_ELEM_INDEX);

	type T_JSON_PATH_ELEMENT is record
		StringStart : T_UINT16;
		StringEnd   : T_UINT16;
		ElementType : T_JSON_PATH_ELEMENT_TYPE;
	end record;

	type T_JSON_PATH is array(natural range <>) of T_JSON_PATH_ELEMENT;

	impure function jsonLoad(Stream : string) return T_JSON;
	impure function jsonParseStream(Stream : string) return T_JSON;
	impure function jsonReadFile(Filename : string; StrLength : integer) return string;

	function jsonParsePath(Path : string) return T_JSON_PATH;
	function jsonGetElementIndex(JSONContext : T_JSON; Path : string) return T_UINT16;

	function jsonTrim(str : string) return string;
	procedure jsonStringAppend(StringBuffer : inout string; StringWriter : inout natural; Message : string);
	procedure jsonStringClear(StringBuffer : inout string; StringWriter : inout natural);

	function jsonNoParserError(JSONContext : T_JSON) return boolean;
	function jsonGetErrorMessage(JSONContext : T_JSON) return string;
	function jsonGetContent(JSONContext : T_JSON) return string;

	procedure jsonReportIndex(Index : T_JSON_INDEX; Content : string; StringBuffer : inout string; StringWriter : inout natural);

	function jsonGetBoolean(JSONContext : T_JSON; Path : string) return boolean;
	function jsonGetString(JSONContext : T_JSON; Path : string) return string;
	function jsonGetIntegerArray(JSONContext : T_JSON; Path : string) return integer_vector;
	function jsonGetIntegerArray(JSONContext : T_JSON; Path : string; Len : positive) return integer_vector;
--    function jsonGetRealArray(JSONContext : T_JSON; Path : string) return real_vector;

	function jsonIsBoolean(JSONContext : T_JSON; Path : string) return boolean;
	function jsonIsNull(JSONContext : T_JSON; Path : string) return boolean;
	function jsonIsString(JSONContext : T_JSON; Path : string) return boolean;
	function jsonIsNumber(JSONContext : T_JSON; Path : string) return boolean;
end package;


package body JSON is
	-- inlined function from PoC.utils, to break dependency
	function ite(cond : boolean; value1 : string; value2 : string) return string is begin
		if cond then    return value1;    else    return value2;    end if;
	end function;
	
	-- TODO: replace by minimum from VHDL-2008
	function imin(arg1 : integer; arg2 : integer) return integer is begin
		if arg1 < arg2 then return arg1;    else    return arg2;    end if;
	end function;
	-- TODO: replace by maximum from VHDL-2008
	function imax(arg1 : integer; arg2 : integer) return integer is begin
		if arg1 > arg2 then return arg1;    else    return arg2;    end if;
	end function;

	-- chr_is* function
	function chr_isDigit(chr : character) return boolean is
	begin
		return (character'pos('0') <= character'pos(chr)) and (character'pos(chr) <= character'pos('9'));
	end function;

	function chr_isLowerAlpha(chr : character) return boolean is
	begin
		return (character'pos('a') <= character'pos(chr)) and (character'pos(chr) <= character'pos('z'));
	end function;

	function chr_isUpperAlpha(chr : character) return boolean is
	begin
		return (character'pos('A') <= character'pos(chr)) and (character'pos(chr) <= character'pos('Z'));
	end function;

	function chr_isAlpha(chr : character) return boolean is
	begin
		return chr_isLowerAlpha(chr) or chr_isUpperAlpha(chr);
	end function;

	function chr_isSpecial(chr : character) return boolean is
	begin
		return (chr = '_') or (chr = '-') or (chr = '.') or (chr = '#') or (chr = '!') or (chr = '$');
	end function;

	function chr_isIdentifier(chr : character) return boolean is
	begin
		return chr_isAlpha(chr) or chr_isDigit(chr) or chr_isSpecial(chr);
	end function;

	function jsonStringMatch(str1 : string; str2 : string) return boolean is
		constant len : natural := imin(str1'length, str2'length);
	begin
		-- if both strings are empty
		if (str1'length = 0) and (str2'length = 0) then
			return TRUE;
		end if;
		-- compare char by char
		for i in str1'low to str1'low + len - 1 loop
			if (str1(i) /= str2(str2'low + (i - str1'low))) then
				return FALSE;
			elsif ((str1(i) = C_JSON_NUL) xor (str2(str2'low + (i - str1'low)) = C_JSON_NUL)) then
				return FALSE;
			elsif ((str1(i) = C_JSON_NUL) and (str2(str2'low + (i - str1'low)) = C_JSON_NUL)) then
				return TRUE;
			end if;
		end loop;
		-- check special cases,
		return (((str1'length = len) and (str2'length = len)) or                    -- both strings are fully consumed and equal
		        ((str1'length > len) and (str1(str1'low + len) = C_JSON_NUL)) or    -- str1 is longer, but jsonStringlength equals len
		        ((str2'length > len) and (str2(str2'low + len) = C_JSON_NUL)));     -- str2 is longer, but jsonStringlength equals len
	end function;

	procedure jsonStringAppend(StringBuffer : inout string; StringWriter : inout natural; Message : string) is
		constant StringStart : natural := StringWriter + 1;
		constant StringEnd   : natural := imin(StringBuffer'high, StringWriter + Message'length);
		constant Length      : natural := StringEnd - StringStart + 1;
	begin
		StringBuffer(StringStart to StringEnd) := Message(Message'low to Message'low + Length - 1);
		StringWriter                           := StringEnd;
	end procedure;

	procedure jsonStringClear(StringBuffer : inout string; StringWriter : inout natural) is
	begin
		StringBuffer := (StringBuffer'range => C_JSON_NUL);
		StringWriter := 0;
	end procedure;

	function jsonTrim(str : string) return string is
	begin
		for i in str'range loop
			if (str(i) = C_JSON_NUL) then
				return str(str'low to i - 1);
			end if;
		end loop;
		return str;
	end function;

	function to_natural_dec(str : string) return integer is
		variable Result : natural;
		variable Digit  : integer;
	begin
		for i in str'range loop
			Result := Result * 10 + (character'pos(str(i)) - character'pos('0'));
		end loop;
		return Result;
--        return integer'value(str);            -- 'value(...) is not supported by Vivado Synth 2014.1
	end function;

	function errorMessage(str : string) return string is
		constant ConstNUL : string(1 to 1)  := (others => C_JSON_NUL);
		variable Result   : string(1 to C_JSON_ERROR_MESSAGE_LENGTH);
	begin
		Result := (others => C_JSON_NUL);
		if (str'length > 0) then        -- workaround for Quartus II
			Result(1 to imin(C_JSON_ERROR_MESSAGE_LENGTH, imax(1, str'length))) := ite((str'length > 0), str(1 to imin(C_JSON_ERROR_MESSAGE_LENGTH, str'length)), ConstNUL);
		end if;
		return Result;
	end function;

	function jsonNoParserError(JSONContext : T_JSON) return boolean is
	begin
		return (JSONContext.Error(1) = C_JSON_NUL);
	end function;

	function jsonGetErrorMessage(JSONContext : T_JSON) return string is
	begin
		return jsonTrim(JSONContext.Error);
	end function;

	function jsonGetContent(JSONContext : T_JSON) return string is
	begin
		return JSONContext.Content(1 to JSONContext.ContentCount);
	end function;

	procedure jsonReportIndex(Index : T_JSON_INDEX; Content : string; StringBuffer : inout string; StringWriter : inout natural) is
--        variable StringBuffer        : string(1 to 2**15);
--        variable StringWriter        : T_UINT16;
	begin
--        jsonStringClear(StringBuffer, StringWriter);
		jsonStringappend(StringBuffer, StringWriter, LF & "Index: depth=" & integer'image(Index'length) & LF);
		for i in Index'range loop
			jsonStringappend(StringBuffer, StringWriter, integer'image(i) &
					": index=" & integer'image(Index(i).Index) &
					"  child=" & integer'image(Index(i).ChildIndex) &
					"  next=" & integer'image(Index(i).NextIndex) &
					"  start=" & integer'image(Index(i).StringStart) &
					"  end=" & integer'image(Index(i).StringEnd) &
					"  type=" & T_ELEMENT_TYPE'image(Index(i).ElementType) & LF
				 );
		end loop;
--        report StringBuffer(1 to StringWriter - 1) severity NOTE;
	end procedure;

	impure function decode(Stream : string) return string is
		alias str : string(1 to Stream'length) is Stream;
	begin
		case str(1) is
			when '{'|'['|'.'|'/'|'\' =>
				return str;
			when others =>
				if str(2) = ':' then
					return str;
				end if;
				return base16_decode(str);
		end case;
	end function;

	impure function jsonLoad(Stream : string) return T_JSON is
		alias str : string(1 to Stream'length) is Stream;
		constant raw : string := decode(str);
	begin
		if ( ".json" = raw(raw'length-4 to raw'length) ) then
			report "jsonLoad: Filename " & raw severity NOTE;
			return jsonParseStream(jsonReadFile(raw, C_JSONFILE_INDEX_MAX));
		end if;
		report "jsonLoad: Stream" severity NOTE;
		return jsonParseStream(raw);
	end function;

	impure function jsonReadFile(Filename : string; StrLength : integer) return string is
		file FileHandle       : TEXT open READ_MODE is Filename;
		variable CurrentLine  : LINE;
		variable IsString     : boolean;
		variable Stream       : string(1 to StrLength);
		variable CurrentStr   : string(1 to StrLength);
		variable Len          : natural range 1 to StrLength +1;
		variable z            : natural range 1 to StrLength +1 :=1;
	begin
		report "jsonReadFile: " & Filename severity NOTE;
		loopi : loop
			exit when endfile(FileHandle);
			readline(FileHandle, CurrentLine);
			Len := CurrentLine'length;
			read(CurrentLine, CurrentStr(1 to Len), IsString);
			assert IsString report "unexpected error during file-read." severity failure;
			
			loopj : for j in 1 to Len loop
				if ((CurrentStr(j)/=' ') and (CurrentStr(j)/=HT)) then  -- Remove leading whitespaces
					if z + Len - j > StrLength then
						report "File to large. Skipping other characters." severity failure;
						exit loopi; 
					end if;
					
					Stream(z to z + Len -j) := CurrentStr(j to Len);
					z := z + Len - j + 1;
					exit loopj;
				end if;
			end loop;
		end loop;
		file_close(FileHandle);
		return Stream(1 to z-1);
	end function;

	impure function jsonParseStream(Stream : string) return T_JSON is
		variable CurrentChar  : character;

		variable Result       : T_JSON;

		constant VERBOSE      : boolean                    := C_JSON_VERBOSE or FALSE;
		constant C_JSON_NULL  : string(1 to 4)    := "null";
		constant C_JSON_TRUE  : string(1 to 4)    := "true";
		constant C_JSON_FALSE : string(1 to 5)    := "false";

		type T_PARSER_STATE        is (
			ST_HEADER,
				ST_OBJECT,     ST_LIST,
				ST_KEY,        ST_KEY_END,
				ST_DELIMITER1, ST_DELIMITER2, ST_DELIMITER3,
				ST_string,     ST_string_END,
				ST_LINK,       ST_LINK_END,
				ST_NUMBER,     ST_NUMBER_END,
				ST_NULL_END,   ST_TRUE_END, ST_FALSE_END,
			ST_CLOSED
		);
		type T_PARSER_STACK_ELEMENT is record
			State : T_PARSER_STATE;
			Index : T_UINT16;
		end record;

		type T_PARSER_STACK is array(natural range <>) of T_PARSER_STACK_ELEMENT;

		function printPos(Column : T_UINT16) return string is
		begin
			return "Col:" & integer'image(Column);
		end function;

		procedure printParserStack(ParserStack : T_PARSER_STACK; StringBuffer : inout string; StringWriter : inout natural) is
--        variable StringBuffer        : string(1 to 2**15);
--        variable StringWriter        : T_UINT16;
		begin
--            jsonStringClear(StringBuffer, StringWriter);
			jsonStringappend(StringBuffer, StringWriter, "ParserStack: depth=" & integer'image(ParserStack'length) & LF);
			for i in ParserStack'range loop
				jsonStringappend(StringBuffer, StringWriter, "        " & integer'image(i) & ": state=" & T_PARSER_STATE'image(ParserStack(i).State) & "  index=" & integer'image(ParserStack(i).Index) & LF);
			end loop;
--            report StringBuffer(1 to StringWriter - 1) severity NOTE;
		end procedure;

		procedure readChar(Pointer: inout T_UINT16; Current: inout character) is
		begin
			Pointer := Pointer+1;
			Current := Stream(Pointer);
			--report integer'image(Pointer) & " " &  integer'image(Stream'length) & " " & Current severity note;
		end procedure;

		constant PARSER_DEPTH  : POSITIVE := 1023;
		variable StackPointer  : natural range 0 to PARSER_DEPTH - 1;
		variable ParserStack   : T_PARSER_STACK(0 to PARSER_DEPTH - 1);
		variable ContentWriter : T_UINT16;
		variable IndexWriter   : T_UINT16;

		variable StringBuffer  : string(1 to 2**12);
		variable StringWriter  : T_UINT16;

		variable Column_Index  : T_UINT16;

	begin
		jsonStringClear(StringBuffer, StringWriter);

		StackPointer                    := 0;
		ParserStack(StackPointer).State := ST_HEADER;
		ParserStack(StackPointer).Index := 0;
		ContentWriter                   := 0;
		IndexWriter                     := 0;
		Column_Index                    := 0;

		Result.Error                    := (1 to 64 => C_JSON_NUL);

		loopi: while Column_Index < Stream'length loop

			readChar(Column_Index, CurrentChar);

				jsonStringClear(StringBuffer, StringWriter);
				if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, Lf &
						"---------------------------------------------------" & LF &
						"Parser State:" &
						"  CurrentChar='" & CurrentChar & "'" &
						"  State=" & T_PARSER_STATE'image(ParserStack(StackPointer).State) &
						"  StackPointer=" & integer'image(StackPointer) & LF &
						"---------------------------------------------------" & LF);
				end if;

				case ParserStack(StackPointer).State is
					when ST_HEADER =>
						case CurrentChar is
							when ' ' | HT =>
								next loopi;
							when '{' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Object - Add new IndexElement(OBJ) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_OBJECT;
								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_OBJECT;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '[' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: List - Add new IndexElement(LIST) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_LIST;
								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_LIST;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: String - Add new IndexElement(STR) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_string;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_string;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '-' | '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;

								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Number - Add new IndexElement(NUM) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NUMBER;
								Result.Index(IndexWriter).StringStart    := ContentWriter;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_NUMBER;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'n' | 'N' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_NULL(k)) then
										Result.Error    := errorMessage("Parsing List(" & printPos(Column_Index) & "): Keyword 'null' has a not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: NULL - Add new IndexElement(NULL) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NULL;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_NULL_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 't' | 'T' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_TRUE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'true' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: TRUE - Add new IndexElement(TRUE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_TRUE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_TRUE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'f' | 'F' =>
								for k in 2 to 5 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_FALSE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'false' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: FALSE - Add new IndexElement(FALSE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_FALSE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_FALSE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when others =>
								Result.Error := errorMessage("Parsing Header(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_OBJECT =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Key - Add new IndexElement(KEY) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_KEY;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_KEY;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '}' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Empty object" & LF); end if;
								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_CLOSED;
							when others =>
								Result.Error := errorMessage("Parsing Object(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_LIST =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							when '{' =>
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Object - Add new IndexElement(OBJ) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_OBJECT;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_OBJECT;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '[' =>
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: List - Add new IndexElement(LIST) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_LIST;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_LIST;
								ParserStack(StackPointer).Index                := IndexWriter;
							when ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Empty list" & LF); end if;
								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_CLOSED;
							when '@' =>
								-- consume the opening quote
								readChar(Column_Index, CurrentChar);
								if (CurrentChar /= '"') then        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
									Result.Error    := errorMessage("Parsing Link(" & printPos(Column_Index) & "): Begin of link has a not allowed character.");
									exit loopi;
								end if;

								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Link - Add new IndexElement(LNK) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_LINK;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_LINK;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: String - Add new IndexElement(STR) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_string;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_string;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '-' | '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;

								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Number - Add new IndexElement(NUM) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NUMBER;
								Result.Index(IndexWriter).StringStart    := ContentWriter;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_NUMBER;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'n' | 'N' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_NULL(k)) then
										Result.Error    := errorMessage("Parsing List(" & printPos(Column_Index) & "): Keyword 'null' has a not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: NULL - Add new IndexElement(NULL) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NULL;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_NULL_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 't' | 'T' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_TRUE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'true' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: TRUE - Add new IndexElement(TRUE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_TRUE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_TRUE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'f' | 'F' =>
								for k in 2 to 5 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_FALSE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'false' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: FALSE - Add new IndexElement(FALSE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_FALSE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_FALSE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when others =>
								Result.Error := errorMessage("Parsing List(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_KEY =>
						case CurrentChar is
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: KeyEnd - Setting End to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).StringEnd        := ContentWriter;
								ParserStack(StackPointer).State                := ST_KEY_END;
							when others =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;
						end case;

					when ST_KEY_END =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							when ':' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter1 (':')" & LF); end if;
								ParserStack(StackPointer).State                := ST_DELIMITER1;
							when others =>
								Result.Error := errorMessage("Parsing KeyEnd(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					-- colon
					when ST_DELIMITER1 =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							when '{' =>
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Object - Add new IndexElement(OBJ) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_OBJECT;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_OBJECT;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '[' =>
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: List - Add new IndexElement(LIST) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_LIST;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_LIST;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '@' =>
								-- consume the opening quote
								readChar(Column_Index, CurrentChar);
								if (CurrentChar /= '"') then        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
									Result.Error    := errorMessage("Parsing Link(" & printPos(Column_Index) & "): Begin of link has a not allowed character.");
									exit loopi;
								end if;

								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Link - Add new IndexElement(LNK) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_LINK;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_LINK;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: String - Add new IndexElement(STR) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_string;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_string;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '-' | '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;

								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Number - Add new IndexElement(NUM) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NUMBER;
								Result.Index(IndexWriter).StringStart    := ContentWriter;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_NUMBER;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'n' | 'N' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_NULL(k)) then
										Result.Error    := errorMessage("Parsing List(" & printPos(Column_Index) & "): Keyword 'null' has a not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: NULL - Add new IndexElement(NULL) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NULL;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_NULL_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 't' | 'T' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_TRUE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'true' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: TRUE - Add new IndexElement(TRUE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_TRUE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_TRUE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'f' | 'F' =>
								for k in 2 to 5 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_FALSE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'false' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: FALSE - Add new IndexElement(FALSE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_FALSE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer).Index) & " as child." & LF); end if;
								Result.Index(ParserStack(StackPointer).Index).ChildIndex    := IndexWriter;

								StackPointer                                                    := StackPointer + 1;
								ParserStack(StackPointer).State                := ST_FALSE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when others =>
								Result.Error := errorMessage("Parsing Delimiter1(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					-- coma in objects
					when ST_DELIMITER2 =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Key - Add new IndexElement(KEY) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_KEY;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 2).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 2).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 2;
								ParserStack(StackPointer).State                := ST_KEY;
								ParserStack(StackPointer).Index                := IndexWriter;
							when others =>
								-- printParserStack(ParserStack(0 to StackPointer), StringBuffer, StringWriter);
								-- report StringBuffer(1 to StringWriter - 1) severity NOTE;
								Result.Error := errorMessage("Parsing Delimiter2(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					-- coma in lists
					when ST_DELIMITER3 =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							when '{' =>
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Object - Add new IndexElement(OBJ) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_OBJECT;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_OBJECT;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '[' =>
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: List - Add new IndexElement(LIST) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_LIST;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_LIST;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '@' =>
								-- consume the opening quote
								readChar(Column_Index, CurrentChar);
								if (CurrentChar /= '"') then        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
									Result.Error    := errorMessage("Parsing Link(" & printPos(Column_Index) & "): Begin of link has a not allowed character.");
									exit loopi;
								end if;

								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Link - Add new IndexElement(LNK) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_LINK;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_LINK;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: String - Add new IndexElement(STR) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter + 1) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_string;
								Result.Index(IndexWriter).StringStart    := ContentWriter + 1;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_string;
								ParserStack(StackPointer).Index                := IndexWriter;
							when '-' | '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;

								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Number - Add new IndexElement(NUM) at pos " & integer'image(IndexWriter) & " setting Start to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NUMBER;
								Result.Index(IndexWriter).StringStart    := ContentWriter;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_NUMBER;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'n' | 'N' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_NULL(k)) then
										Result.Error    := errorMessage("Parsing List(" & printPos(Column_Index) & "): Keyword 'null' has a not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: NULL - Add new IndexElement(NULL) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_NULL;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_NULL_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 't' | 'T' =>
								for k in 2 to 4 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_TRUE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'true' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: TRUE - Add new IndexElement(TRUE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_TRUE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_TRUE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when 'f' | 'F' =>
								for k in 2 to 5 loop
									readChar(Column_Index, CurrentChar);
									if (CurrentChar /= C_JSON_FALSE(k)) then
										Result.Error    := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Keyword 'false' as not allowed character.");
										exit loopi;
									end if;
								end loop;
								IndexWriter                                                        := IndexWriter + 1;
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: FALSE - Add new IndexElement(FALSE) at pos " & integer'image(IndexWriter) & LF); end if;
								Result.Index(IndexWriter).Index                := IndexWriter;
								Result.Index(IndexWriter).ElementType    := ELEM_FALSE;
								Result.Index(IndexWriter).StringStart    := 0;
								Result.Index(IndexWriter).StringEnd        := 0;

								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Linking new key to index " & integer'image(ParserStack(StackPointer - 1).Index) & " as next." & LF); end if;
								Result.Index(ParserStack(StackPointer - 1).Index).NextIndex    := IndexWriter;

								StackPointer                                                    := StackPointer - 1;
								ParserStack(StackPointer).State                := ST_FALSE_END;
								ParserStack(StackPointer).Index                := IndexWriter;
							when others =>
								Result.Error := errorMessage("Parsing Delimiter3(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_LINK =>
						case CurrentChar is
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: LinkEnd - Setting End to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).StringEnd        := ContentWriter;
								ParserStack(StackPointer).State                := ST_LINK_END;
							when others =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;
						end case;

					when ST_LINK_END =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing" & LF); end if;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "ST_LINK_END" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "ST_LINK_END" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing LinkEnd(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_string =>
						case CurrentChar is
							when '"' =>        -- a single quote to restore the syntax highlighting FSM in Notepad++ "
								if (ContentWriter = 0) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: StringEnd - Setting End to " & integer'image(ContentWriter) & LF); end if;
									Result.Index(IndexWriter).StringEnd    := ContentWriter;
									ParserStack(StackPointer).State            := ST_string_END;
								elsif ((ContentWriter > 0) and (Result.Content(ContentWriter) /= '\')) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: StringEnd - Setting End to " & integer'image(ContentWriter) & LF); end if;
									Result.Index(IndexWriter).StringEnd    := ContentWriter;
									ParserStack(StackPointer).State            := ST_string_END;
								else
									ContentWriter                                                := ContentWriter + 1;
									Result.Content(ContentWriter)                := CurrentChar;
								end if;
							when others =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;
						end case;

					when ST_string_END =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing" & LF); end if;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "(" & printPos(Column_Index) & ") ST_string_END" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "(" & printPos(Column_Index) & ") ST_string_END" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing StringEnd(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_NUMBER =>
						case CurrentChar is
							when ' ' | HT =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: WS after number - Setting End to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).StringEnd        := ContentWriter;
								ParserStack(StackPointer).State                := ST_NUMBER_END;
							when '0' | '1' | '2' | '3' | '4' | '5' | '6' | '7' | '8' | '9' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;
							when '.' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;
							when '-' | '+' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;
							when 'e' | 'E' =>
								ContentWriter                                                    := ContentWriter + 1;
								Result.Content(ContentWriter)                    := CurrentChar;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing - Setting End to " & integer'image(ContentWriter) & LF); end if;
								Result.Index(IndexWriter).StringEnd        := ContentWriter;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "(" & printPos(Column_Index) & ") ST_NUMBER" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								Result.Index(IndexWriter).StringEnd        := ContentWriter;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "(" & printPos(Column_Index) & ") ST_NUMBER" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing Number(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_NUMBER_END =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing" & LF); end if;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "(" & printPos(Column_Index) & ")ST_NUMBER_END" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "(" & printPos(Column_Index) & ") ST_NUMBER_END" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing NumberEnd(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_NULL_END =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing" & LF); end if;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "(" & printPos(Column_Index) & ") ST_NULL_END" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "(" & printPos(Column_Index) & ") ST_NULL_END" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing NullEnd(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_TRUE_END =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing" & LF); end if;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "(" & printPos(Column_Index) & ") ST_TRUE_END" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "(" & printPos(Column_Index) & ") ST_TRUE_END" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing TrueEnd(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_FALSE_END =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing" & LF); end if;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "(" & printPos(Column_Index) & ") ST_FALSE_END" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "(" & printPos(Column_Index) & ") ST_FALSE_END" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing FalseEnd(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

					when ST_CLOSED =>
						case CurrentChar is
							when ' ' | HT =>                                                next loopi;
							-- check if allowed
							when '}' | ']' =>
								if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Closing" & LF); end if;
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									StackPointer                                                := StackPointer - 2;
									ParserStack(StackPointer).State            := ST_CLOSED;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									StackPointer                                                := StackPointer - 1;
									ParserStack(StackPointer).State            := ST_CLOSED;
								else
									report "(" & printPos(Column_Index) & ") ST_CLOSED" severity FAILURE;
								end if;
							-- check if allowed
							when ',' =>
								if (ParserStack(StackPointer - 1).State = ST_DELIMITER1) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter2 (Obj)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER2;
									ParserStack(StackPointer).Index            := IndexWriter;
								elsif (ParserStack(StackPointer - 1).State = ST_LIST) then
									if (VERBOSE = TRUE) then jsonStringAppend(StringBuffer, StringWriter, "Found: Delimiter3 (List)" & LF); end if;
									StackPointer                                                := StackPointer + 1;
									ParserStack(StackPointer).State            := ST_DELIMITER3;
									ParserStack(StackPointer).Index            := IndexWriter;
								else
									report "(" & printPos(Column_Index) & ") ST_CLOSED" severity FAILURE;
								end if;
							when others =>
								Result.Error := errorMessage("Parsing Closed(" & printPos(Column_Index) & "): Char '" & CurrentChar & "' is not allowed.");
								exit loopi;
						end case;

				end case;

				if (VERBOSE = TRUE) then
					printParserStack(ParserStack(0 to StackPointer), StringBuffer, StringWriter);
					jsonReportIndex(Result.Index(0 to IndexWriter), Result.Content(1 to ContentWriter), StringBuffer, StringWriter);
					report StringBuffer(1 to StringWriter - 1) severity NOTE;
				end if;
		end loop;

		Result.IndexCount   := IndexWriter + 1;
		Result.ContentCount := ContentWriter;

		-- print complete index after parsing all input characters
		if (VERBOSE = TRUE) then
			jsonStringClear(StringBuffer, StringWriter);
			jsonReportIndex(Result.Index(0 to Result.IndexCount - 1), Result.Content(1 to Result.ContentCount), StringBuffer, StringWriter);
			report StringBuffer(1 to StringWriter - 1) severity NOTE;
		end if;

		if (Result.Error(1) /= C_JSON_NUL) then
			return Result;
		elsif ((StackPointer /= 1) or (ParserStack(StackPointer).State /= ST_CLOSED)) then
			case ParserStack(StackPointer).State is
				when ST_FALSE_END | ST_NULL_END | ST_TRUE_END => null;
				when ST_string_END | ST_NUMBER | ST_NUMBER_END => null;
				when ST_CLOSED => null;
				when others =>
					printParserStack(ParserStack(0 to StackPointer), StringBuffer, StringWriter);
					jsonReportIndex(Result.Index(0 to IndexWriter), Result.Content(1 to ContentWriter), StringBuffer, StringWriter);
					report StringBuffer(1 to StringWriter - 1) severity NOTE;
					Result.Error := errorMessage("(" & printPos(Column_Index) & ") Reached end of file before end of structure.");
					return Result;
			end case;
		end if;

		return Result;
	end function;

	function jsonParsePath(Path : string) return T_JSON_PATH is
		variable Result       : T_JSON_PATH(0 to 31);
		variable ResultWriter : natural;
	begin
		ResultWriter                                            := 0;
		Result(ResultWriter).StringStart    := 0;

		loopi : for i in Path'range loop
			if (Result(ResultWriter).StringStart = 0) then        -- determine element type
				if (chr_isAlpha(Path(i)) = TRUE) then
					Result(ResultWriter).StringStart    := i;
					Result(ResultWriter).ElementType    := PATH_ELEM_KEY;
				elsif (chr_isDigit(Path(i)) = TRUE) then
					Result(ResultWriter).StringStart    := i;
					Result(ResultWriter).ElementType    := PATH_ELEM_INDEX;
				else
					report "jsonParsePath: Unsupported character '" & Path(i) & "'in path." severity failure;
				end if;
			else
				case Result(ResultWriter).ElementType is
					when PATH_ELEM_KEY =>
						if (chr_isIdentifier(Path(i)) = TRUE) then
							next loopi;
						elsif (Path(i) = '/') then
							Result(ResultWriter).StringEnd        := i - 1;
							ResultWriter                                            := ResultWriter + 1;
							Result(ResultWriter).StringStart    := 0;
						else
							report "jsonParsePath: Unsupported character '" & Path(i) & "' in identifier." severity failure;
						end if;

					when PATH_ELEM_INDEX =>
						if (chr_isDigit(Path(i)) = TRUE) then
							next loopi;
						elsif (Path(i) = '/') then
							Result(ResultWriter).StringEnd        := i - 1;
							ResultWriter                                            := ResultWriter + 1;
							Result(ResultWriter).StringStart    := 0;
						else
							report "jsonParsePath: Unsupported character '" & Path(i) & "'in index." severity failure;
						end if;

				end case;
			end if;
		end loop;
		Result(ResultWriter).StringEnd := Path'high;

		return Result(0 to ResultWriter);
	end function;

	function jsonGetElementIndex(JSONContext : T_JSON; Path : string) return T_UINT16 is
		constant VERBOSE      : boolean               := C_JSON_VERBOSE or FALSE;
		constant JSON_PATH    : T_JSON_PATH           := jsonParsePath(Path);
		variable IndexElement : T_JSON_INDEX_ELEMENT;
		variable Index        : natural;
	begin
		if (VERBOSE = TRUE) then report "jsonGetElementIndex: Path='" & Path & "'  JSON_PATH elements " & integer'image(JSON_PATH'length) severity NOTE; end if;
		IndexElement                := JSONContext.Index(0);
		-- resolve objects and lists to their first child
		if (IndexElement.ElementType = ELEM_OBJECT) then
			if (VERBOSE = TRUE) then               report "jsonGetElementIndex: Resolve root element (OBJ) to first child: Index=" & integer'image(IndexElement.ChildIndex)    severity NOTE;  end if;
			if (IndexElement.ChildIndex = 0) then  report "jsonGetElementIndex: Object has no child."                                                                                                                                                severity FAILURE;    return 0;    end if;
			IndexElement                        := JSONContext.Index(IndexElement.ChildIndex);
		elsif (IndexElement.ElementType = ELEM_LIST) then
			if (VERBOSE = TRUE) then               report "jsonGetElementIndex: Resolve root element (LIST) to first child: Index=" & integer'image(IndexElement.ChildIndex)    severity NOTE; end if;
			if (IndexElement.ChildIndex = 0) then  report "jsonGetElementIndex: List has no child."                                                                                                                                                    severity FAILURE; return 0;    end if;
			IndexElement                        := JSONContext.Index(IndexElement.ChildIndex);
		end if;

		loopi : for i in JSON_PATH'range loop
			-- -------------------------------
			if (JSON_PATH(i).ElementType = PATH_ELEM_INDEX) then
				Index        := to_natural_dec(Path(JSON_PATH(i).StringStart to JSON_PATH(i).StringEnd));
				if (Index = 0) then
					if (IndexElement.ElementType = ELEM_LINK) then
						if (VERBOSE = TRUE) then  report "jsonGetElementIndex0: Resolving link to '" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'." severity NOTE;  end if;
						IndexElement    := JSONContext.Index(jsonGetElementIndex(JSONContext, JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)));
						if (VERBOSE = TRUE) then  report "jsonGetElementIndex0: Resolved: Index=" & integer'image(IndexElement.Index) severity NOTE;                                                                                                        end if;
						next loopi;
					end if;

					-- Go one level down
					if (IndexElement.ChildIndex = 0) then        -- no child
						if (i /= JSON_PATH'high) then                    -- this was not the last path element to compare
							report "jsonGetElementIndex: Element has no child, can't process the full path." severity FAILURE;
							return 0;
						end if;
					else        -- IndexElement.ChildIndex
						if (i = JSON_PATH'high) then                    -- this was the last path element to compare
							report "jsonGetElementIndex: Result is not a leaf node. Element has a child." severity NOTE;
							return IndexElement.Index;                    -- found result
						else
							IndexElement        := JSONContext.Index(IndexElement.ChildIndex);
						end if;
					end if;    -- IndexElement.ChildIndex
				end if;    -- Index = 0
				for j in 1 to Index loop
					if (IndexElement.NextIndex = 0) then
						report "jsonGetElementIndex: Reached last element in chain." severity NOTE; --FAILURE
						return 0;
					end if;
					IndexElement        := JSONContext.Index(IndexElement.NextIndex);
				end loop;

				if (IndexElement.ElementType = ELEM_LINK) then
					if (VERBOSE = TRUE) then                 report "jsonGetElementIndex1: Resolving link to '" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'." severity NOTE;        end if;
					IndexElement    := JSONContext.Index(jsonGetElementIndex(JSONContext, JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)));
					if (VERBOSE = TRUE) then                 report "jsonGetElementIndex1: Resolved: Index=" & integer'image(IndexElement.Index) severity NOTE;                                                                                                        end if;
				end if;

				-- resolve objects and lists to their first child
				if (IndexElement.ElementType = ELEM_OBJECT) then
					if (VERBOSE = TRUE) then                 report "jsonGetElementIndex: Resolve element (OBJ) to first child: Index=" & integer'image(IndexElement.ChildIndex)        severity NOTE;                                end if;
					if (IndexElement.ChildIndex = 0) then    report "jsonGetElementIndex: Object has no child."                                                                                                                                        severity FAILURE;    return 0;        end if;
					IndexElement                        := JSONContext.Index(IndexElement.ChildIndex);
				elsif (IndexElement.ElementType = ELEM_LIST) then
					if (VERBOSE = TRUE) then                 report "jsonGetElementIndex: Resolve element (LIST) to first child: Index=" & integer'image(IndexElement.ChildIndex)    severity NOTE;                                end if;
					if (IndexElement.ChildIndex = 0) then    report "jsonGetElementIndex: List has no child."                                                                                                                                            severity FAILURE; return 0;        end if;
					IndexElement                        := JSONContext.Index(IndexElement.ChildIndex);
				end if;

				if (IndexElement.ElementType = ELEM_LINK) then
					if (VERBOSE = TRUE) then                 report "jsonGetElementIndex2: Resolving link to '" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'." severity NOTE;        end if;
					IndexElement    := JSONContext.Index(jsonGetElementIndex(JSONContext, JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)));
					if (VERBOSE = TRUE) then                 report "jsonGetElementIndex2: Resolved: Index=" & integer'image(IndexElement.Index) severity NOTE;                                                                                                        end if;
				end if;
			-- -------------------------------
			elsif (JSON_PATH(i).ElementType = PATH_ELEM_KEY) then
				if (IndexElement.ElementType = ELEM_KEY) then
					loopj : for j in 0 to 127 loop
						if (VERBOSE = TRUE) then report "jsonGetElementIndex: Compare keys - Path='" & Path(JSON_PATH(i).StringStart to JSON_PATH(i).StringEnd) & "'  Key='" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'" severity NOTE; end if;
						if (jsonStringmatch(Path(JSON_PATH(i).StringStart to JSON_PATH(i).StringEnd), JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)) = TRUE) then
							if (VERBOSE = TRUE) then report "jsonGetElementIndex: -> matched - Get Child: Index=" & integer'image(IndexElement.ChildIndex) severity NOTE; end if;
							-- Go one level down
							if (IndexElement.ChildIndex = 0) then        -- no child
								if (i /= JSON_PATH'high) then                    -- this was not the last path element to compare
									report "jsonGetElementIndex: Element has no child, can't process the full path." severity FAILURE;
									return 0;
								end if;
							else        -- IndexElement.ChildIndex
								if (i = JSON_PATH'high) then                    -- this was the last path element to compare
--                                    if ((IndexElement.ElementType = ELEM_OBJECT) or (IndexElement.ElementType = ELEM_LIST) or (IndexElement.ElementType = ELEM_KEY)) then
--                                        report "jsonGetElementIndex: Result is not a leaf node. Element has a child." severity NOTE;
--                                    end if;
--                                    return IndexElement.Index;                    -- found result
									IndexElement        := JSONContext.Index(IndexElement.ChildIndex);
								else
									IndexElement        := JSONContext.Index(IndexElement.ChildIndex);
								end if;
							end if;    -- IndexElement.ChildIndex

							if (IndexElement.ElementType = ELEM_LINK) then
								if (VERBOSE = TRUE) then                            report "jsonGetElementIndex3: Resolving link to '" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'." severity NOTE;    end if;
								IndexElement    := JSONContext.Index(jsonGetElementIndex(JSONContext, JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)));
								if (VERBOSE = TRUE) then                            report "jsonGetElementIndex3: Resolved: Index=" & integer'image(IndexElement.Index) severity NOTE;                                                                                                    end if;
							end if;

							-- resolve objects and lists to their first child
							if (IndexElement.ElementType = ELEM_OBJECT) then
								if (VERBOSE = TRUE) then                            report "jsonGetElementIndex: Resolve element (OBJ) to first child: Index=" & integer'image(IndexElement.ChildIndex)        severity NOTE;                                end if;
								if (IndexElement.ChildIndex = 0) then    report "jsonGetElementIndex: Object has no child."                                                                                                                                        severity FAILURE;    return 0;        end if;
								IndexElement            := JSONContext.Index(IndexElement.ChildIndex);
							elsif (IndexElement.ElementType = ELEM_LIST) then
								if (VERBOSE = TRUE) then                            report "jsonGetElementIndex: Resolve element (LIST) to first child: Index=" & integer'image(IndexElement.ChildIndex)    severity NOTE;                                end if;
								if (IndexElement.ChildIndex = 0) then    report "jsonGetElementIndex: List has no child."                                                                                                                                            severity FAILURE; return 0;        end if;
								IndexElement            := JSONContext.Index(IndexElement.ChildIndex);
							end if;

							-- if (IndexElement.ElementType = ELEM_LINK) then
								-- if (VERBOSE = TRUE) then                            report "jsonGetElementIndex4: Resolving link to '" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'." severity NOTE;    end if;
								-- IndexElement    := JSONContext.Index(jsonGetElementIndex(JSONContext, JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)));
								-- if (VERBOSE = TRUE) then                            report "jsonGetElementIndex4: Resolved: Index=" & integer'image(IndexElement.Index) severity NOTE;                                                                                                    end if;
							-- end if;
							next loopi;
						else        -- jsonStringmatch
							if (VERBOSE = TRUE) then report "jsonGetElementIndex: -> no match - Get Next: Index=" & integer'image(IndexElement.NextIndex) severity NOTE; end if;
							if (IndexElement.NextIndex = 0) then
								report "jsonGetElementIndex: No more keys to compare for '" & Path(JSON_PATH(i).StringStart to JSON_PATH(i).StringEnd) & "'. Processed path items: " & integer'image(i) severity FAILURE;
								return 0;
							else        -- IndexElement.NextIndex
								IndexElement                := JSONContext.Index(IndexElement.NextIndex);
								next loopj;
							end if;    -- IndexElement.NextIndex
						end if;    -- jsonStringmatch
					end loop;    -- loopj
				else        -- IndexElement.ElementType /= ELEM_KEY
					report "jsonGetElementIndex: IndexElement is not a key." severity FAILURE;
					return 0;
				end if;    -- IndexElement.ElementType
			end if;

			if (IndexElement.ElementType = ELEM_LINK) then
				if (VERBOSE = TRUE) then report "jsonGetElementIndex: Resolving link to '" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'." severity NOTE;    end if;
				IndexElement    := JSONContext.Index(jsonGetElementIndex(JSONContext, JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)));
				if (VERBOSE = TRUE) then                            report "jsonGetElementIndex: Resolved: Index=" & integer'image(IndexElement.Index) severity NOTE;                                                                            end if;
			end if;
		end loop;

		if (IndexElement.ElementType = ELEM_LINK) then
			if (VERBOSE = TRUE) then report "jsonGetElementIndex: Resolving link to '" & JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd) & "'." severity NOTE;        end if;
			IndexElement    := JSONContext.Index(jsonGetElementIndex(JSONContext, JSONContext.Content(IndexElement.StringStart to IndexElement.StringEnd)));
			if (VERBOSE = TRUE) then                            report "jsonGetElementIndex: Resolved: Index=" & integer'image(IndexElement.Index) severity NOTE;                                                                                end if;
		end if;

		return IndexElement.Index;
	end function;

	function jsonGetString(JSONContext : T_JSON; Path : string) return string is
		constant ElementIndex : T_UINT16             := jsonGetElementIndex(JSONContext, Path);
		constant Element      : T_JSON_INDEX_ELEMENT := JSONContext.Index(ElementIndex);
	begin
--        report "jsonGetString: ElementIndex=" & integer'image(ElementIndex) & "  Type=" & T_ELEMENT_TYPE'image(Element.ElementType) severity NOTE;
		if (ElementIndex /= 0) then
			case Element.ElementType is
				when ELEM_NULL =>                                    return "NULL";
				when ELEM_TRUE =>                                    return "TRUE";
				when ELEM_FALSE =>                                return "FALSE";
				when ELEM_string | ELEM_NUMBER => return JSONContext.Content(Element.StringStart to Element.StringEnd);
				when others =>                                        null;
			end case;
		end if;
		return "ERROR";
	end function;

	function jsonGetBoolean(JSONContext : T_JSON; Path : string) return boolean is
		constant ElementIndex    : T_UINT16                            := jsonGetElementIndex(JSONContext, Path);
		constant Element            : T_JSON_INDEX_ELEMENT    := JSONContext.Index(ElementIndex);
	begin
		if (ElementIndex = 0) then return FALSE; end if;
		return (Element.ElementType = ELEM_TRUE);
	end function;

	-- function to get a integer_vector from the compressed content extracted from a JSON input
	function jsonGetIntegerArray(JSONContext : T_JSON; Path : string) return integer_vector is
		variable len: natural := 0;
	begin
		while jsonIsNumber(JSONContext, Path & "/" & to_string(len)) loop
			len := len+1;
		end loop;
		return jsonGetIntegerArray(JSONContext, Path, len);
	end function;

	-- function to get a integer_vector of a fixed length from the compressed content extracted from a JSON input
	function jsonGetIntegerArray(JSONContext : T_JSON; Path : string; Len : positive) return integer_vector is
		variable return_value : integer_vector(Len-1 downto 0);
	begin
		for i in 0 to Len-1 loop
			return_value(i) := to_natural_dec(jsonGetString(JSONContext, Path & "/" & to_string(i)));
		end loop;
		return return_value;
	end function;

	function jsonIsBoolean(JSONContext : T_JSON; Path : string) return boolean is
		constant ElementIndex    : T_UINT16                            := jsonGetElementIndex(JSONContext, Path);
		constant Element            : T_JSON_INDEX_ELEMENT    := JSONContext.Index(ElementIndex);
	begin
		if (ElementIndex = 0) then return FALSE; end if;
		return (Element.ElementType = ELEM_TRUE) or (Element.ElementType = ELEM_FALSE);
	end function;

	function jsonIsNull(JSONContext : T_JSON; Path : string) return boolean is
		constant ElementIndex    : T_UINT16                            := jsonGetElementIndex(JSONContext, Path);
		constant Element            : T_JSON_INDEX_ELEMENT    := JSONContext.Index(ElementIndex);
	begin
		if (ElementIndex = 0) then return FALSE; end if;
		return (Element.ElementType = ELEM_NULL);
	end function;

	function jsonIsString(JSONContext : T_JSON; Path : string) return boolean is
		constant ElementIndex    : T_UINT16                            := jsonGetElementIndex(JSONContext, Path);
		constant Element            : T_JSON_INDEX_ELEMENT    := JSONContext.Index(ElementIndex);
	begin
		if (ElementIndex = 0) then return FALSE; end if;
		return (Element.ElementType = ELEM_string);
	end function;

	function jsonIsNumber(JSONContext : T_JSON; Path : string) return boolean is
		constant ElementIndex    : T_UINT16                            := jsonGetElementIndex(JSONContext, Path);
		constant Element            : T_JSON_INDEX_ELEMENT    := JSONContext.Index(ElementIndex);
	begin
		if (ElementIndex = 0) then return FALSE; end if;
		return (Element.ElementType = ELEM_NUMBER);
	end function;
end package body;
