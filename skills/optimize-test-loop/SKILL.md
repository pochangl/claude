---
name: optimize-test-loop
description: Use this skill whenever running tests repeatedly while iterating — fixing a failing case, mutation-testing a fixture, checking a change to one handler. Triggers on "run the tests again", "rerun", "mutation test", "break it and see it fail", or any loop of edit → test → edit.
---

While iterating, run the narrowest set of tests that can answer the question you are asking. CI (CodeBuild here) runs the full suites and blocks a deploy on failure; locally, the only unfiltered runs are the checks CI cannot perform, once, right before a deploy.

## 1. Filter to the Cases the Change Can Affect

Every test runner takes a filter; use it on every iteration.

- `go test ./pkg/ -run 'TestParity/prs_mnemonic'` — subtest names with spaces become underscores
- `python manage.py test app.tests.test_x.TestCase.test_y --keepdb`
- `flutter test test/foo_test.dart --plain-name 'name'`
- Project harnesses that wrap a runner must accept the same filter and pass it through (e.g. `go/parity/run 'prs_mnemonic'`). If one does not, add the parameter before using it in a loop.

A mutation round only needs the cases it is meant to turn red. Running 400 cases to watch 3 of them is a 45-second wait for a 25-second answer, once per mutation.

## 2. Keep the Fixed Cost, Cut the Variable Cost

Some setup cannot be filtered (seeding, booting a server, building an image). Accept it; filter the part after it. Do not skip setup steps to go faster — a stale seed or an old binary turns the loop into guessing.

## 3. Before a Deploy, Run Unfiltered Only What CI Cannot

Commits carry filtered greens. CI runs the suites it can run and blocks the deploy on a failure, so repeating them locally buys nothing. What it cannot run — checks that need Docker, a local database, a throwaway server (here: the Go/Django parity run and the nginx routing check) — has no other gate, so run those unfiltered, once, right before the deploy push. Each project's deploy skill names them. If a single change touches something shared (a base class, a fixture every test uses, a config file), widen the filter to the suites that consume it — still a filter, not the world.

## 4. Never Parallelise Runs That Share State

Two runs against one database, one port or one seeded fixture set corrupt each other's answers. If a loop is slow because of a shared resource, shorten each run with a filter; do not start a second one beside it.

## Do Not

- Do not run locally what CI runs anyway; before a deploy, run unfiltered only the checks CI cannot.
- Do not remove or shorten setup to make the loop faster.
- Do not deploy on filtered greens alone — the CI-less checks run unfiltered first, and CI still has to pass.
- Do not start two runs that share a database, port or fixture set.
