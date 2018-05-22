from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

vu = VUnit.from_argv()

lib = vu.add_library("JSON")
lib.add_source_files(join(root, "..", "vhdl", "*.vhdl"))
lib = vu.add_library("lib")
lib.add_source_files(join(root, "..", "Examples", "Boards_VUnit.vhdl"))

vu.set_generic('tb_cfg_file', '../Data/Boards1.json')

def add_array_lens(obj):
    if isinstance(obj, list):
        if isinstance(obj[0], int) and not isinstance(obj[0], bool):
            obj = [len(obj)] + obj
        else:
            for i in range(len(obj)):
                obj[i] = add_array_lens(obj[i])
    else:
        if isinstance(obj, dict):
            for key, val in obj.items():
                obj[key] = add_array_lens(val)
    return obj

import json
generics = json.loads(open('../Data/Boards0.json', 'r').read())
vu.set_generic("tb_cfg", json.dumps(add_array_lens(generics), separators=(',', ':')))

vu.main()
