#!/usr/bin/env bash
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
exempt=()
[ -f $dir/.gdcheckignore ] && IFS=$'\n' read -d '' -r -a exempt <<< "$( grep -Ev '^#' $dir/.gdcheckignore )" || true

lint=1
format=1
fix=0

set -eu

usage() {
	echo "$0 [flags]

	The default behavior is to run gdlint and gdformat in 'check' mode and fail if either one does not pass.

	--help: Print this help
	--fix:  Apply formatting with gdformat
	--lint: Only do linting (don't run gdformat)
	--format: Only do formatting (don't run gdlint)
	"
}

while [[ "${1:-}" =~ ^-- ]]; do
	if [ "$1" == "--fix" ]; then
		fix=1
	fi
	if [ "$1" == "--lint" ]; then
		format=0
	fi
	if [ "$1" == "--format" ]; then
		lint=0
	fi
	if [ "$1" == "--help" ]; then
		usage
		exit 0
	fi
	shift
done

format_flag=
if [ $fix == 0 ]; then
	format_flag=--check
fi

declare -a prune_flags
if [ ${#exempt[@]} -gt 0 ]; then
	prune_flags=( '(' )
	for i in "${!exempt[@]}"; do
		if [ $i -gt 0 ]; then
			prune_flags+=( -o )
		fi
		prune_flags+=( -path "./${exempt[$i]}" )
	done
	prune_flags+=( ')' -prune -o )
fi

cd $dir

set +e

function activate_venv {
	if [[ -d "$dir/.py_venv/bin" ]]; then
		source "$dir/.py_venv/bin/activate"
	else
		source "$dir/.py_venv/Scripts/activate"
	fi
}

if ! [[ -d "$dir/.py_venv" ]]; then
	# install gdtoolkit in a venv
	PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring python -m pip install 'virtualenv' --user
	python -m virtualenv .py_venv
	activate_venv
	PYTHON_KEYRING_BACKEND=keyring.backends.null.Keyring python -m pip install 'gdtoolkit==4.3.3'
else
	activate_venv
fi

python --version

if [ $lint == 1 ]; then
echo "GDLint"
gdlint --version
find . "${prune_flags[@]}" -name '*.gd' -exec gdlint {} + 2>&1
lint_result=$?
fi

if [ $format == 1 ]; then
echo "GDFormat $format_flag"
gdformat --version
find . "${prune_flags[@]}" -name '*.gd' -exec gdformat $format_flag {} + 2>&1
format_result=$?
fi

result=0
if [ $lint_result != 0 ]; then
	echo "Lint failed with $lint_result" >&2
	result=$lint_result
fi
if [ $format_result != 0 ]; then
	echo "Format failed with $format_result" >&2
	result=$format_result
fi

exit $result
