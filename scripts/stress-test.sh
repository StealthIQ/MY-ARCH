#!/bin/bash
echo '=== LEOS RAM Compression Stress Test ==='
echo ''
echo 'BEFORE:'
leos-mem

echo ''
echo 'Holding 5GB in memory (3.8GB physical system)...'
echo ''

# Use tail to hold open large memory mappings
# Each tail /dev/zero will consume memory until killed
tail /dev/zero > /dev/null 2>&1 &
P1=$!
tail /dev/zero > /dev/null 2>&1 &
P2=$!
tail /dev/zero > /dev/null 2>&1 &
P3=$!

# Wait for memory pressure to build
sleep 20

echo 'AFTER (memory under pressure):'
leos-mem

# Cleanup
kill $P1 $P2 $P3 2>/dev/null
wait $P1 $P2 $P3 2>/dev/null
echo ''
echo 'Cleaned up.'
