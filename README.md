JSON-for-VHDL
================================================================================

[![CLA assistant](https://cla-assistant.io/readme/badge/Paebbels/JSON-for-VHDL)](https://cla-assistant.io/Paebbels/JSON-for-VHDL)

JSON-for-VHDL is a library to parse and query JSON data structures in VHDL. The
complete functionality is hosted in a single VHDL package, without special
dependencies.

Table of Content:
================================================================================
 1. [Overview](#1-overview)
 2. [JSON - JavaScript Object Notation](#2-json---javascript-object-notation)
 3. [Short Example](#2-short-example)
 4. [Download](#3-download)



1 Overview
================================================================================


The JSON-for-VHDL library can be used to parse and query JSON data structures, which
are read from disk. The data structure is read via VHDL file I/O functions and
procedures and parsed into a internal compressed representation. While the parsing is
done, a lightwight index is created to ease the navigation on the data structure.

Values can be selected by simple path expressions.

2 JSON - JavaScript Object Notation
================================================================================

**JavaScript Object Notation (JSON) Data Interchange Format** is specified in
[RFC 7159](https://tools.ietf.org/html/rfc7159).


3 Short Example
================================================================================

Here is a short example *.json file, which describes two common FPGA boards.

    {  "ML505": {
        "FPGA":        "XC5VLX50T-1FF1136",
        "Eth": [{
          "PHY-Int":   "GMII",
          "Device":    "MARVEL_88E1111",
          "Address":   "0x74"
        }]
      },
      "KC705": {
        "FPGA":        "XC7K325T-2FFG900C",
        "Eth": [{
          "PHY-Int":   "GMII",
          "Device":    "MARVEL_88E1111",
          "Address":   "0x74"
        }],
        "IIC": [{
          "Type":      "Switch",
          "Adr":       "0x85",
          "Devices": [{
            "Name":    "Si570",
            "Address": "0x3A"
          }]
        }]
      }
    }

Reference the JSON package in VHDL:

    use work.json.all;

Load a external *.json file, parse the data structure and select a value:

    architecture rtl of Test is
      constant ConfigFile   : STRING    := "Boards.json";
      constant JSONContent	: T_JSON    := jsonLoad(ConfigFile);
    begin
      assert (JSONContent.Error(1) = C_JSON_NUL)
        report "Error: " & JSONContent.Error
        severity ERROR;
      assert FALSE
        report "Query='KC705/Eth/0/Address' Value='" & jsonGetString(JSONContent, "KC705/Eth/0/Address") & "'"
        severity NOTE;

      -- print the compressed file content
    --  assert FALSE
    --    report "JSON: " & JSONContent.Content severity NOTE;
    end architecture;

4 Download
================================================================================
The library can be [downloaded][31] as a zip-file (latest 'master' branch) or
cloned with `git` from GitHub. GitHub offers HTTPS and SSH as transfer protocols.

For SSH protocol use the URL `ssh://git@github.com:Paebbels/JSON-for-VHDL.git` or command
line instruction:

    cd <GitRoot>
    git clone ssh://git@github.com:Paebbels/JSON-for-VHDL.git JSON

For HTTPS protocol use the URL `https://github.com/Paebbels/JSON-for-VHDL.git` or command
line instruction:

    cd <GitRoot>
    git clone https://github.com/Paebbels/JSON-for-VHDL.git JSON

 [31]: https://github.com/Paebbels/JSON-for-VHDL/archive/master.zip

