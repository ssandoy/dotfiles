# Misc helpers.

# CD to root of git project.
cdr() {
  if [[ -z "$(git rev-parse --show-toplevel 2>/dev/null)" ]]; then
    echo "Error: top level directory not found."
  else
    cd "$(git rev-parse --show-toplevel)"
  fi
}
