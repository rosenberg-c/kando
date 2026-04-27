#!/usr/bin/env sh

run_with_test_summary() {
	if [ "$#" -eq 0 ]; then
		echo "run_with_test_summary: no command provided" >&2
		return 2
	fi

	start="$(date '+%Y-%m-%d %H:%M:%S')"
	start_epoch="$(date +%s)"

	"$@"
	status=$?

	end="$(date '+%Y-%m-%d %H:%M:%S')"
	end_epoch="$(date +%s)"
	duration="$((end_epoch - start_epoch))"

	printf '\nTest Time Summary\n'
	printf 'Started : %s\n' "$start"
	printf 'Ended   : %s\n' "$end"
	printf 'Duration: %ss\n' "$duration"

	return "$status"
}
