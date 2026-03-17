#!/bin/bash
# Watch benchmark progress: formats new CSV lines as they arrive.
# Auto-detects CSV format from header.
# Usage:
#   bash slurm/monitor.sh                          # standard benchmark (4500 runs)
#   bash slurm/monitor.sh results/other.csv 1600   # custom CSV + total

CSV="${1:-results/benchmark_standard.csv}"
TOTAL="${2:-4500}"

if [ ! -f "$CSV" ]; then
    echo "Waiting for $CSV to appear..."
    while [ ! -f "$CSV" ]; do sleep 1; done
fi

# Detect format from header
HEADER=$(head -1 "$CSV")
if echo "$HEADER" | grep -q "^model,"; then
    FORMAT="standard"
elif echo "$HEADER" | grep -q "^method,t_value"; then
    FORMAT="ablation"
else
    FORMAT="unknown"
fi

DONE=$(($(wc -l < "$CSV") - 1))
echo "Progress: ${DONE}/${TOTAL} runs completed (format: $FORMAT)"
echo "========================================"

TOTAL_ITERS=0
START=$(date +%s)

tail -n 0 -f "$CSV" | while IFS=, read -r line; do
    DONE=$(($(wc -l < "$CSV") - 1))
    NOW=$(date +%s)
    ELAPSED=$((NOW - START))

    # Parse iterations and success based on format
    if [ "$FORMAT" = "standard" ]; then
        # model,method,epsilon,seed,image,mode,iterations,success,...
        model=$(echo "$line" | cut -d, -f1)
        method=$(echo "$line" | cut -d, -f2)
        image=$(echo "$line" | cut -d, -f5)
        mode=$(echo "$line" | cut -d, -f6)
        iterations=$(echo "$line" | cut -d, -f7)
        success=$(echo "$line" | cut -d, -f8)
        label="$model | $method | $mode | $image"
    elif [ "$FORMAT" = "ablation" ]; then
        # method,t_value,image,true_label,iterations,success,...
        method=$(echo "$line" | cut -d, -f1)
        t_value=$(echo "$line" | cut -d, -f2)
        image=$(echo "$line" | cut -d, -f3)
        iterations=$(echo "$line" | cut -d, -f5)
        success=$(echo "$line" | cut -d, -f6)
        label="$method T=$t_value | $image"
    else
        iterations=$(echo "$line" | cut -d, -f5)
        success=$(echo "$line" | cut -d, -f6)
        label="$line"
    fi

    TOTAL_ITERS=$((TOTAL_ITERS + iterations))
    if [ $ELAPSED -gt 0 ]; then
        IPS=$(echo "scale=1; $TOTAL_ITERS / $ELAPSED" | bc)
    else
        IPS="--"
    fi
    [ "$success" = "True" ] && status="OK" || status="FAIL"
    printf "[%d/%d] %s | %s iters | %s | %s iter/s\n" \
        "$DONE" "$TOTAL" "$label" "$iterations" "$status" "$IPS"
done
