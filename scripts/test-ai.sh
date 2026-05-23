#!/bin/bash
echo "=== LEOS AI Inference Test ==="
echo ""
echo "BEFORE:"
leos-mem
echo ""
echo "Running tinyllama model..."
RESPONSE=$(curl -s http://localhost:11434/api/generate -d '{"model":"tinyllama","prompt":"Say hello in one sentence","stream":false}')
echo ""
echo "AI Response:"
echo "$RESPONSE" | python3 -c "import sys,json; r=json.load(sys.stdin); print(r.get('response','error'))" 2>/dev/null || echo "$RESPONSE" | grep -o '"response":"[^"]*"' | head -1
echo ""
echo "AFTER:"
leos-mem
