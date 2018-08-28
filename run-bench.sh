#!/bin/bash

## Initial setup: See setup.sh.
#
# opam 2.0~alpha6 an "operf" switch with operf-macro installed (currently
# working: ocaml 4.02.3, perf pinned to git://github.com/kayceesrk/ocaml-perf,
# operf-macro pinned to git://github.com/OCamlPro/operf-macro#opam2)
#
# opam repo add benches <repo> -a
#
# where <repo> is
#    git+https://github.com/kayceesrk/ocamlbench-repo#ppc64 for ppc64
#    git+https://github.com/kayceesrk/ocamlbench-repo#aarch64 for aarch64
#    git+https://github.com/kayceesrk/ocamlbench-repo#multicore for multicore
#
# Current switch should be "operf".
#
# Update REPODIR variable below to the location of this cloned repo.

REPODIR=$HOME/repos/ocamlbench-scripts

shopt -s nullglob

OPT_NOWAIT=
OPT_LAZY=
while [ $# -gt 0 ]; do
    case "$1" in
        --nowait) OPT_NOWAIT=1;;
        --lazy) OPT_LAZY=1;;
        *)
            cat <<EOF
Unknown option $1, options are:
  --nowait    don't wait for the system load to settle down before benches
  --lazy      only run the benches if upstream changes are detected
EOF
            exit 1
    esac
    shift
done

export PATH=~/local/bin:$PATH

unset OPAMROOT OPAMSWITCH OCAMLPARAM OCAMLRUNPARAM

STARTTIME=$(date +%s)

DATE=$(date +%Y-%m-%d-%H%M)

BASELOGDIR=~/logs/operf

mkdir -p $BASELOGDIR

LOGDIR=$BASELOGDIR/$DATE

OPERFDIR=~/.cache/operf/macro/

LOCK=$BASELOGDIR/lock

if [ -e $LOCK ]; then
    RUNNING_PID=$(cat $LOCK)
    if ps -p $RUNNING_PID >/dev/null; then
        echo "Another run-bench.sh is running (pid $RUNNING_PID). Aborting." >&2
        exit 1
    else
        echo "Removing stale lock file $LOCK." >&2
        rm $LOCK
    fi
fi

trap "rm $LOCK" EXIT

echo $$ >$LOCK

publish() {
    local FILES=$(cd $LOGDIR && for x in $*; do echo $DATE/$x; done)
    tar -C $BASELOGDIR -u $FILES -f $BASELOGDIR/results.tar
    gzip -c --rsyncable $BASELOGDIR/results.tar >$BASELOGDIR/results.tar.gz
    #rsync $BASELOGDIR/results.tar.gz flambda-mirror:
    #ssh flambda-mirror  "tar -C /var/www/flambda.ocamlpro.com/bench/ --keep-newer-files -xzf ~/results.tar.gz 2>/dev/null"
}

unpublish() {
    mv $BASELOGDIR/$DATE $BASELOGDIR/broken/
    tar --delete $DATE -f $BASELOGDIR/results.tar
    #ssh flambda-mirror  "rm -rf /var/www/flambda.ocamlpro.com/bench/$DATE"
}

trap "unpublish; exit 2" INT

mkdir -p $LOGDIR

echo "Output and log written into $LOGDIR" >&2

exec >$LOGDIR/log 2>&1

OPAMBIN=$(which opam)
opam() {
    echo "+opam $*" >&2
    "$OPAMBIN" "$@"
}

echo "=== SETTING UP BENCH SWITCHES AT $DATE ==="

OPERF_SWITCH=operf

opam update --check benches
HAS_CHANGES=$?

COMPILERS=($(opam list --no-switch --has-flag compiler --repo=benches --all-versions --short))
echo "++Compilers++"
echo $COMPILERS

SWITCHES=()
INSTALLED_BENCH_SWITCHES=($(opam switch list -s |grep '+bench$'))

for C in "${COMPILERS[@]}"; do
    SWITCH=${C#*.}+bench
    SWITCHES+=("$SWITCH")

    if [[ ! " ${INSTALLED_BENCH_SWITCHES[@]} " =~ " $SWITCH " ]]; then
        opam switch create "$SWITCH" --empty --no-switch --repositories benches,default
    fi

    opam pin add "${C%%.*}" "${C#*.}" --switch "$SWITCH" --yes --no-action
    opam switch set-base "${C%%.*}" --switch "$SWITCH" --yes
done

# Remove switches that are no longer needed
for SW in "${INSTALLED_BENCH_SWITCHES[@]}"; do
    if [[ ! " ${SWITCHES[@]} " =~ " $SW " ]]; then
        opam switch remove "$SW" --yes;
    fi;
done

echo
echo "=== UPGRADING operf-macro at $DATE ==="

touch $LOGDIR/stamp
publish stamp

opam update --check --switch $OPERF_SWITCH

opam upgrade --check --yes operf-macro --switch $OPERF_SWITCH --json $LOGDIR/$OPERF_SWITCH.json
HAS_CHANGES=$((HAS_CHANGES * $?))

BENCHES=($(opam list --required-by all-bench --short --column name))
echo "++Benches++"
echo $BENCHES

ALL_BENCHES=($(opam list --no-switch --short --column name '*-bench'))
echo "++All Benches++"
echo $ALL_BENCHES

DISABLED_BENCHES=()
for B in "${ALL_BENCHES[@]}"; do
    if [[ ! " ${BENCHES[@]} " =~ " $B " ]]; then
        DISABLED_BENCHES+=("$B")
    fi
done

for SWITCH in "${SWITCHES[@]}"; do
    if opam update --check --dev --switch $SWITCH; then
        CHANGED_SWITCHES+=("$SWITCH")
    fi
done

if [ -n "$OPT_LAZY" ] && [ "$HAS_CHANGES" -ne 0 ]; then
    if [ "${#CHANGED_SWITCHES[*]}" -eq 0 ] ; then
        echo "Lazy mode, no changes: not running benches"
        unpublish
        exit 0
    else
        echo "Lazy mode, only running benches on: ${CHANGED_SWITCHES[*]}"
        BENCH_SWITCHES=("${CHANGED_SWITCHES[@]}")
    fi
else
    BENCH_SWITCHES=("${SWITCHES[@]}")
fi

for SWITCH in "${BENCH_SWITCHES[@]}"; do
    echo
    echo "=== UPGRADING SWITCH $SWITCH =="
    opam remove "${DISABLED_BENCHES[@]}" --yes --switch $SWITCH
    COMP=($(opam list --base --short --switch $SWITCH))
    opam config exec --switch=$SWITCH -- opam pin add -k git -y frama-c git+https://github.com/kayceesrk/Frama-C-snapshot
    opam upgrade --all "${BENCHES[@]}" --best-effort --yes --switch $SWITCH --json $LOGDIR/$SWITCH.json
done

LOGSWITCHES=("${BENCH_SWITCHES[@]/#/$LOGDIR/}")
$REPODIR/opamjson2html.native ${LOGSWITCHES[@]/%/.json*} >$LOGDIR/build.html

UPGRADE_TIME=$(($(date +%s) - STARTTIME))

echo -e "\n===== OPAM UPGRADE DONE in ${UPGRADE_TIME}s =====\n"


eval $(opam config env --switch $OPERF_SWITCH)

loadavg() {
  awk '{print 100*$1}' /proc/loadavg
}

if [ -z "$OPT_NOWAIT" ]; then

    # let the loadavg settle down...
    sleep 60

    while [ $(loadavg) -gt 60 ]; do
        if [ $(($(date +%s) - STARTTIME)) -gt $((3600 * 12)) ]; then
            echo "COULD NOT START FOR THE PAST 12 HOURS; ABORTING RUN" >&2
            unpublish
            exit 10
        else
            echo "System load detected, waiting to run bench (retrying in 5 minutes)"
            wall "It's BENCH STARTUP TIME, but the load is too high. Please clear the way!"
            sleep 300
        fi
    done
fi

for SWITCH in "${SWITCHES[@]}"; do
    rm -f $OPERFDIR/*/$SWITCH.*
done

ocaml-params() {
    SWITCH=$1; shift
    [ $# -eq 0 ]
    opam config env --switch $SWITCH | sed -n "s/\(OCAMLPARAM='[^']*'\).*$/\1/p"
}

for SWITCH in "${SWITCHES[@]}"; do
    opam show ocaml-variants --switch $SWITCH --field source-hash >$LOGDIR/${SWITCH%+bench}.hash
    ocaml-params $SWITCH >$LOGDIR/${SWITCH%+bench}.params
    opam pin --switch $SWITCH >$LOGDIR/${SWITCH%+bench}.pinned
done

publish log build.html "*.hash" "*.params" "*.pinned"

wall " -- STARTING BENCHES -- don't put load on the machine. Thanks"

BENCH_START_TIME=$(date +%s)

echo
echo "=== BENCH START ==="

for SWITCH in "${BENCH_SWITCHES[@]}"; do
    nice -19 opam config exec --switch $OPERF_SWITCH -- timeout 90m operf-macro run --switch $SWITCH
done

opam config exec --switch $OPERF_SWITCH -- operf-macro summarize -b csv >$LOGDIR/summary.csv

for SWITCH in "${BENCH_SWITCHES[@]}"; do
	opam config exec --switch $OPERF_SWITCH -- operf-macro summarize -b csv --no-normalize -t time_real --switch $SWITCH > $LOGDIR/$SWITCH-time_real.csv
done

cp -r $OPERFDIR/* $LOGDIR

BENCH_TIME=$(($(date +%s) - BENCH_START_TIME))

hours() {
    printf "%02d:%02d:%02d" $(($1 / 3600)) $(($1 / 60 % 60)) $(($1 % 60))
}

cat > $LOGDIR/timings <<EOF
Upgrade: $(hours $UPGRADE_TIME)
Benches: $(hours $BENCH_TIME)
Total: $(hours $((UPGRADE_TIME + BENCH_TIME)))
EOF

publish log timings summary.csv "*/*.summary" "*-time_real.csv"

cp $REPODIR/compare.js $BASELOGDIR

cd $BASELOGDIR

echo "<html><head><title>bench index</title></head><body><ul>
  $(ls -d 201* latest | sed 's%\(.*\)%<li><a href="\1/build.html">\1</a></li>%')
</ul></body></html>" >build.html

echo "<html><head><title>bench index</title></head><body>
  <script src=\"https://cdnjs.cloudflare.com/ajax/libs/Chart.js/2.7.2/Chart.min.js\"> </script>
  <script src=\"compare.js\"></script>

  <div id=\"container\" style=\"width: 90%;\"> <canvas id=\"chart\"></canvas> </div>
  <div> <input type=\"button\" value=\"compare\" id=\"compareButton\" onclick=\"plot()\"> </div>
  </br>
	$(find . -name '*time_real.csv' -printf '%Ts\t%p\n' | sort -nr | cut -f2 | sed 's/.*\(20.*\)+bench-time_real.csv/<div><input type="checkbox" name="benchrun" value="\1">\1<\/div>/g')
	</body></html>" > index.html

tar -u index.html build.html compare.js -f results.tar
gzip -c --rsyncable results.tar > results.tar.gz

WEB=$HOME/repos/ocamllabs.github.io
mkdir -p $WEB/multicore
tar xf results.tar -C $WEB/multicore

cd $WEB
git add multicore
git commit -a -m "multicore bench sync"
git push

echo "Done"
