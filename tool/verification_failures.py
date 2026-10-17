"""Shared failure triage for candidate verification and the published canary."""


def classify_failure(phase, consumer, output):
    """Return a triage area, not a claim of proven root cause."""
    text = output.lower()
    if any(marker in text for marker in (
            'socketexception', 'connection timed out', 'connection reset',
            'could not resolve host', 'http error', 'tls', 'permission denied',
            'no space left', 'failed host lookup', 'timeout expired')):
        return 'infrastructure'
    if phase == 'sdk' or (phase == 'resolution' and any(marker in text for marker in (
            'requires sdk version', 'requires flutter sdk version',
            'current dart sdk version', 'current flutter sdk version',
            'from sdk which depends on'))):
        return 'sdk'
    if phase == 'resolution':
        return 'dependency-resolution'
    if phase in ('generation', 'generated-analysis', 'generated-test', 'generated-drift'):
        return 'generation'
    if consumer == 'flutter':
        return 'factory-provider-integration'
    return 'provider' if consumer == 'provider-control' else 'factory'

