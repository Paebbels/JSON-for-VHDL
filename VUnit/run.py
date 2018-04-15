from os.path import join, dirname
from vunit import VUnit

root = dirname(__file__)

vu = VUnit.from_argv()

lib = vu.add_library("lib")
lib.add_source_files(join(root, "../vhdl/JSON.pkg.vhdl"))
lib.add_source_files(join(root, "../Examples/Boards_VUnit.vhdl"))

vu.set_generic("filename","../Data/Boards2.json")

vu.main()
