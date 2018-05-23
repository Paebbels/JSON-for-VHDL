from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

vu = VUnit.from_argv()

lib = vu.add_library("JSON")
lib.add_source_files(join(root, "..", "vhdl", "*.vhdl"))
lib = vu.add_library("lib")
lib.add_source_files(join(root, "..", "Examples", "Boards_VUnit.vhdl"))

vu.set_generic('tb_cfg_file', '../Data/Boards1.json')

import json
generics = json.loads(open('../Data/Boards0.json', 'r').read())
vu.set_generic("tb_cfg", json.dumps(generics, separators=(',', ':')))

vu.main()
