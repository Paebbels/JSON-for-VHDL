
import json
from os.path import join, dirname
from vunit import VUnit
from base64 import b16encode


def json_load(p):
    return json.loads(open(p, "r").read())


def json_dump(o):
    return json.dumps(o, separators=(",", ":"))


def b16enc(s):
    return b16encode(bytes(s, 'utf-8')).decode('utf-8')


root = join(dirname(__file__), '..', '..')

vu = VUnit.from_argv()

lib = vu.add_library("JSON")
lib.add_source_files(join(root, "Src", "*.vhdl"))
lib = vu.add_library("lib")
lib.add_source_files(join(root, "Examples", "*_VUnit.vhdl"))

gen_cfg = json_load(join(root, 'Data', 'Boards1.json'))
gen_str = json_dump(gen_cfg)

tb = lib.get_test_benches('*tb_boards*')[0]

tb.get_tests("stringified*")[0].set_generic("tb_cfg", gen_str)
tb.get_tests("b16encoded stringified*")[0].set_generic("tb_cfg", b16enc(gen_str))
tb.get_tests("JSON file*")[0].set_generic("tb_cfg", join(root, 'Data', 'Boards0.json'))
tb.get_tests("b16encoded JSON file*")[0].set_generic("tb_cfg", b16enc(join(root, 'Data', 'Boards0.json')))

vu.main()
