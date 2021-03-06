#!/bin/sh

cd "$GITHUB_WORKSPACE"

export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

# Rewrite package.json so that it only contains the packages we're about to use.
# The lockfile will remain the same so the package versions should match what
# we have checked in as the versions for local development.
echo $(cat package.json | jq 'to_entries | map(if .key == "dependencies" or .key == "devDependencies" then . + {"value": .value | to_entries | map(select(.key | test("(stylelint)"))) | from_entries} else . end) | from_entries') > package.json

yarn install

$(yarn bin)/stylelint --version

if [ "${INPUT_REPORTER}" == 'github-pr-review' ]; then
  # Use jq and github-pr-review reporter to format result to include link to rule page.
  $(yarn bin)/stylelint "${INPUT_STYLELINT_INPUT:-'**/*.css'}" --config="${INPUT_STYLELINT_CONFIG}" --ignore-pattern="${INPUT_STYLELINT_IGNORE}" -f json \
    | jq -r '.[] | {source: .source, warnings:.warnings[]} | "\(.source):\(.warnings.line):\(.warnings.column):\(.warnings.severity): \(.warnings.text) [\(.warnings.rule)](https://stylelint.io/user-guide/rules/\(.warnings.rule))"' \
    | reviewdog -efm="%f:%l:%c:%t%*[^:]: %m" -name="${INPUT_NAME:-stylelint}" -reporter=github-pr-review -level="${INPUT_LEVEL}" -filter-mode="${INPUT_FILTER_MODE}" -fail-on-error="${INPUT_FAIL_ON_ERROR}"
else
  $(yarn bin)/stylelint "${INPUT_STYLELINT_INPUT:-'**/*.css'}" --config="${INPUT_STYLELINT_CONFIG}" --ignore-pattern="${INPUT_STYLELINT_IGNORE}" \
    | reviewdog -f="stylelint" -name="${INPUT_NAME:-stylelint}" -reporter="${INPUT_REPORTER:-github-pr-check}" -level="${INPUT_LEVEL}" -filter-mode="${INPUT_FILTER_MODE}" -fail-on-error="${INPUT_FAIL_ON_ERROR}"
fi
