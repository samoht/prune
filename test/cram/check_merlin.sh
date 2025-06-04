#\!/bin/bash
cd /Users/samoht/git/bug-occurences
# Check if merlin can find File.x from main.ml
echo '{"command": "occurrences", "kind": "identifiers", "position": {"line": 3, "column": 16}, "scope": "project"}' | \
ocamlmerlin server -filename lib/main.ml < lib/main.ml | jq -r '.value | length'
