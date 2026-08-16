# project (monsoon config)
language: bash
package_manager: -
default_branch: main
branch_model: feature-branch
docs_lang: en+ja   # canonical README.md, full translation README.ja.md
check:
  lint: ./lint.sh && ./lint-skills.sh
  typecheck: -
  test: ./test-hooks.sh && ./test-install.sh
  build: -
opt_in:
  release_note: off
