import unittest

from verify_example_runtime import verified_flows


class RuntimeEvidenceTest(unittest.TestCase):
    def test_process_success_without_completed_flows_is_not_evidence(self):
        self.assertFalse(verified_flows("Application finished.\nAll tests passed."))

    def test_all_compositions_must_finish_two_cycles(self):
        report = ('Verified profile flows: {"cyclesPerComposition": 2, '
                  '"verifiedCompositions": ["Manual Factory composition", '
                  '"Annotated Factory composition", "Provider-only composition"]}')
        self.assertTrue(verified_flows(report))
        self.assertFalse(verified_flows(report.replace(', "Provider-only composition"', '')))
        self.assertFalse(verified_flows(report.replace(': 2,', ': 1,')))
        self.assertFalse(verified_flows('Verified profile flows: null'))
        self.assertFalse(verified_flows('Verified profile flows: invalid'))


if __name__ == "__main__":
    unittest.main()
