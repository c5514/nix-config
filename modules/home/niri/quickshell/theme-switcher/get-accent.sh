#!/usr/bin/env sh
set -eu

FALLBACK="#1e66f5"
IMAGE="${1:-}"

if [ -z "$IMAGE" ] || ! command -v matugen >/dev/null 2>&1; then
    echo "$FALLBACK"
    exit 0
fi

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

TEMPLATE_IN="$TMP_DIR/accent.template"
TEMPLATE_OUT="$TMP_DIR/accent.out"
CONFIG="$TMP_DIR/config.toml"

printf '%s' '{{colors.primary.default.hex}}' > "$TEMPLATE_IN"

cat > "$CONFIG" << EOF
[config]

[templates.accent]
input_path = "$TEMPLATE_IN"
output_path = "$TEMPLATE_OUT"
EOF

if matugen image "$IMAGE" \
    -c "$CONFIG" \
    -m dark \
    --source-color-index 0 \
    -q \
    >/dev/null 2>&1 &&
    [ -s "$TEMPLATE_OUT" ]; then
    RESULT=$(tr -d '[:space:]' < "$TEMPLATE_OUT")

    case "$RESULT" in
        '#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F])
            echo "$RESULT"
            exit 0
            ;;
    esac
fi

echo "$FALLBACK"
