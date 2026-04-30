#!/usr/bin/env bats
# pr-flow regression tests — Bash Automated Testing System
#
# Requires: bats-core  (brew install bats-core  OR  apt install bats)
# Run:      bats tests/pr-flow.bats
#
# The tests exercise check.sh directly by building a minimal git repo in a
# temp directory and stubbing the `gh` CLI so no real GitHub API calls are made.

# ---------------------------------------------------------------------------
# Shared helpers
# ---------------------------------------------------------------------------

setup() {
  # Create a fresh tmpdir for each test
  TEST_DIR="$(mktemp -d)"
  export TEST_DIR

  # Build a minimal git repo with two commits so merge-base arithmetic works
  cd "$TEST_DIR"
  git init -q
  git config user.email "test@pr-flow.local"
  git config user.name "PR Flow Test"

  # Fake origin/main so git rev-parse --verify origin/main succeeds
  git checkout -q -b main
  mkdir -p src tests
  echo "base" > src/core.ts
  echo "base test" > tests/core.test.ts
  git add .
  git commit -q -m "init"
  git update-ref refs/remotes/origin/main HEAD

  # Work branch: add a src file + matching test file by default
  git checkout -q -b feature/default-branch
  echo "logic" > src/logic.ts
  echo "logic test" > tests/logic.test.ts
  git add .
  git commit -q -m "add logic"

  # Stub directory — place a fake `gh` and prepend to PATH
  STUB_DIR="$TEST_DIR/.stubs"
  mkdir -p "$STUB_DIR"
  export PATH="$STUB_DIR:$PATH"

  # Default stub: no open PRs, branch=feature/default-branch, no PR context
  _write_gh_stub '[]' 'feature/default-branch' '' ''

  # Point to the skill script under test
  CHECK_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/src/scripts/check.sh"
  export CHECK_SH
}

teardown() {
  rm -rf "$TEST_DIR"
}

# _write_gh_stub OPEN_PRS_JSON BRANCH TARGET_BRANCH LABELS_CSV
# Writes a gh stub that answers the subset of gh commands used by check.sh.
_write_gh_stub() {
  local open_prs_json="$1"   # JSON array for 'gh pr list'
  local branch="$2"          # current branch (unused here, git already set)
  local target_branch="$3"   # baseRefName returned by 'gh pr view baseRefName'
  local labels_csv="$4"      # labels CSV returned by 'gh pr view labels'

  cat > "$STUB_DIR/gh" <<STUB
#!/usr/bin/env bash
# Minimal gh stub for pr-flow tests
case "\$*" in
  *"repo view"*"--json nameWithOwner"*)
    echo '{"nameWithOwner":"test-org/test-repo"}'
    ;;
  *"pr list"*"--json number,baseRefName,files"*)
    echo '${open_prs_json}'
    ;;
  *"pr list"*)
    echo '${open_prs_json}'
    ;;
  *"pr view"*"--json baseRefName"*)
    echo '{"baseRefName":"${target_branch}"}'
    ;;
  *"pr view"*"--json labels"*)
    echo '"${labels_csv}"'
    ;;
  *"pr view"*"--json number"*)
    echo '{"number":99}'
    ;;
  *"repo view"*)
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
STUB
  chmod +x "$STUB_DIR/gh"
}

# ---------------------------------------------------------------------------
# Test 1: three distinct-scope PRs with different target files all pass
# ---------------------------------------------------------------------------

@test "three distinct-scope PRs with different target files all pass" {
  cd "$TEST_DIR"

  # Three open PRs each touching completely different files.
  # The current branch touches src/logic.ts + tests/logic.test.ts.
  # None of the open PRs touch those files -> no duplicate scope.
  local open_prs
  open_prs='[
    {"number":1,"baseRefName":"main","files":[{"path":"src/alpha.ts"}]},
    {"number":2,"baseRefName":"main","files":[{"path":"src/beta.ts"}]},
    {"number":3,"baseRefName":"main","files":[{"path":"src/gamma.ts"}]}
  ]'
  _write_gh_stub "$open_prs" 'feature/default-branch' 'main' ''

  # check.sh resolves REPO via 'gh repo view', branch via git, diff via git.
  run bash "$CHECK_SH"
  echo "--- output ---"
  echo "$output"
  echo "--- status: $status ---"

  [ "$status" -eq 0 ]
  [[ "$output" == *"PR-FLOW OK"* ]]
}

# ---------------------------------------------------------------------------
# Test 2: duplicate-scope PR targeting already-modified files fails
# ---------------------------------------------------------------------------

@test "duplicate-scope PR targeting already-modified files fails" {
  cd "$TEST_DIR"

  # Open PR #7 already touches src/logic.ts on the same target branch (main).
  # Our current branch also modifies src/logic.ts -> duplicate scope.
  local open_prs
  open_prs='[
    {"number":7,"baseRefName":"main","files":[{"path":"src/logic.ts"},{"path":"tests/logic.test.ts"}]}
  ]'
  _write_gh_stub "$open_prs" 'feature/default-branch' 'main' ''

  run bash "$CHECK_SH"
  echo "--- output ---"
  echo "$output"
  echo "--- status: $status ---"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL-CLOSED"* ]]
  [[ "$output" == *"escopo duplicado"* ]] || [[ "$output" == *"duplicado"* ]]
}

# ---------------------------------------------------------------------------
# Test 3: diff touches src/ but no test file — blocked
# ---------------------------------------------------------------------------

@test "src-only diff without tests is blocked" {
  cd "$TEST_DIR"

  # Remove the test file from the last commit so the diff has only src/
  git checkout -q -b feature/no-tests
  echo "more logic" >> src/logic.ts
  git add src/logic.ts
  git commit -q -m "src only, no test"

  _write_gh_stub '[]' 'feature/no-tests' 'main' ''

  run bash "$CHECK_SH"
  echo "--- output ---"
  echo "$output"
  echo "--- status: $status ---"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL-CLOSED"* ]]
  [[ "$output" == *"teste"* ]] || [[ "$output" == *"test"* ]]
}

# ---------------------------------------------------------------------------
# Test 4: critical-path file without approval label — blocked
# ---------------------------------------------------------------------------

@test "diff touching auth path without approval label is blocked" {
  cd "$TEST_DIR"

  # Branch touches an auth file + a test file (so rule 3 passes)
  git checkout -q -b feature/auth-change
  mkdir -p src/auth tests
  echo "auth logic" > src/auth/login.ts
  echo "auth test" > tests/auth-login.test.ts
  git add .
  git commit -q -m "auth change with tests"

  # No approval label
  _write_gh_stub '[]' 'feature/auth-change' 'main' ''

  run bash "$CHECK_SH"
  echo "--- output ---"
  echo "$output"
  echo "--- status: $status ---"

  [ "$status" -ne 0 ]
  [[ "$output" == *"FAIL-CLOSED"* ]]
  [[ "$output" == *"critico"* ]] || [[ "$output" == *"critical"* ]] || [[ "$output" == *"auth"* ]]
}

# ---------------------------------------------------------------------------
# Test 5: critical-path file WITH approval label — passes
# ---------------------------------------------------------------------------

@test "diff touching auth path with security-ok label passes" {
  cd "$TEST_DIR"

  git checkout -q -b feature/auth-approved
  mkdir -p src/auth tests
  echo "auth logic v2" > src/auth/login.ts
  echo "auth test v2" > tests/auth-login.test.ts
  git add .
  git commit -q -m "auth change approved"

  # Provide security-ok label
  _write_gh_stub '[]' 'feature/auth-approved' 'main' 'security-ok'

  run bash "$CHECK_SH"
  echo "--- output ---"
  echo "$output"
  echo "--- status: $status ---"

  [ "$status" -eq 0 ]
  [[ "$output" == *"PR-FLOW OK"* ]]
}
