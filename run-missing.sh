#!/bin/bash

#------------------------------------------------------------------------------
# run-missing.sh
#------------------------------------------------------------------------------
# Run all the missing benchmarks before generating the graph. If the benchmark
# run initiated by run-bench.sh was terminated early, then the graph plotting
# scripts would fail with an error due to missing data. This script ensures
# that the missing benchmarks are run. Note that this script does not rerun all
# the benchmarks.
#------------------------------------------------------------------------------

INSTALLED_BENCH_SWITCHES=($(opam switch list -s |grep '+bench$'))

for S in "${INSTALLED_BENCH_SWITCHES[@]}"; do
	operf-macro run -s $S
done
