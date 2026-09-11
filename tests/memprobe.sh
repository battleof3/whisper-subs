#!/usr/bin/env bash
# Runs a command, sampling its RSS every 0.5 s; kills it if RSS exceeds CAP_MB (default 6000)
# so a runaway can't pressure the system. Usage: memprobe.sh LABEL SECONDS_MAX cmd...
label=$1 max_s=$2; shift 2
CAP_MB=${CAP_MB:-6000}
"$@" > /dev/null 2>&1 &
pid=$!
peak=0 t=0 trace=''
while kill -0 $pid 2>/dev/null; do
    rss=$(( $(ps -o rss= -p $pid 2>/dev/null || echo 0) / 1024 ))
    (( rss > peak )) && peak=$rss
    (( t % 4 == 0 )) && trace+="$rss "
    if (( rss > CAP_MB )); then kill -9 $pid; echo "$label: KILLED at ${rss} MB after $((t / 2)) s (cap $CAP_MB MB)"; echo "  trace (MB every 2 s): $trace"; exit 1; fi
    if (( t / 2 >= max_s )); then kill $pid; echo "$label: stopped after ${max_s}s (still running), peak ${peak} MB"; echo "  trace (MB every 2 s): $trace"; exit 0; fi
    sleep 0.5; t=$((t + 1))
done
wait $pid; echo "$label: exit $? after $((t / 2)) s, peak RSS ${peak} MB"; echo "  trace (MB every 2 s): $trace"
