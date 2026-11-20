"""Exercise local compatibility setup for both FreeKill core layouts."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'scripts'))
from prepare_runtime import apply  # noqa: E402


class PrepareRuntimeTest(unittest.TestCase):
    def test_patches_each_installed_core_layout_and_is_idempotent(self):
        with TemporaryDirectory() as directory:
            runtime = Path(directory)
            packaged_core = runtime / 'packages/freekill-core'
            for layout in (runtime, packaged_core):
                (layout / 'lua').mkdir(parents=True)
                (layout / 'lua/freekill.lua').touch()
                (layout / 'lua/request.lua').write_text('  old\n', encoding='utf-8')

            with patch('prepare_runtime.replacements', return_value={
                'lua/request.lua': [('  old\n', '  new\n')],
            }), redirect_stdout(StringIO()) as output:
                apply(runtime)
                apply(runtime)

            for layout in (runtime, packaged_core):
                self.assertEqual((layout / 'lua/request.lua').read_text(encoding='utf-8'), '  new\n')
            self.assertIn('(2 files updated)', output.getvalue())
            self.assertIn('(0 files updated)', output.getvalue())
