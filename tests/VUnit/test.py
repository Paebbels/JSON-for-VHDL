from pathlib import Path, PurePath
from os import listdir
from vunit import VUnit

root = Path(PurePath(__file__).parent / '..' / '..')

vu = VUnit.from_argv()

vu.add_library("JSON").add_source_files(str(root / "src" / "*.vhdl"))
lib = vu.add_library("lib")
lib.add_source_files(str(root / "examples" / "TestSuite.vhdl"))

JSONTestSuite = root / "examples" / "JSONTestSuite" / "test_parsing"

for fname in listdir(JSONTestSuite):
    lib.get_test_benches('*tb_suite*')[0].add_config(
        name=fname[0:-5],
        generics=dict(tb_cfg=str(JSONTestSuite / fname))
    )

vu.main()
