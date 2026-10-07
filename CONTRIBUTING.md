# Contributing to mojo-uregex

## The gate

Every change must keep the gate green and must be able to fail:

```
tools/gate.sh   # builds the CLI, runs tests/test_uregex.mojo and tools/difftest.py (every pattern in tools/difftest.py x 5004 random strings vs Python regex)
```

A pull request that adds behaviour adds a case to the differential test and, where it applies, a negative case that the oracle rejects. A test that cannot go red is not a test.

## Sign-off (DCO)

Commits are signed off under the [Developer Certificate of Origin](https://developercertificate.org/) 1.1:

```
git commit -s
```

The `Signed-off-by:` line certifies that you wrote the change or have the right to submit it under the Apache-2.0 license. No CLA.

## Style

- Mojo is the implementation language. Python is allowed only as an oracle or verifier, kept in `tools/` next to what it checks, with versions pinned in `pyproject.toml`.
- One fact, one home: numbers live in the file that produced them and are linked, not restated.
- No attribution trailers other than `Signed-off-by`.

## Copyright

Contributions are licensed under Apache-2.0. New source files carry the header line used throughout the repo. The copyright holder for the project is amarbaro.org.
