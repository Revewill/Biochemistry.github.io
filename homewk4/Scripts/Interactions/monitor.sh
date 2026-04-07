#!/bin/bash
while true; do
    if ! pgrep -f "run_md.sh" > /dev/null; then
        echo "MD job has stopped at $(date)" >> monitor.log
        echo "Last 20 lines of run.log:" >> monitor.log
        tail -20 run.log >> monitor.log
        break
    fi
    sleep 900  # Check every 15min
done
