#!/usr/bin/env bash
set -u

POSITIVE_COLOR=0xff70d6a3
NEGATIVE_COLOR=0xffff6b6b
TEXT_COLOR=0xffe8eaed
API_BASE="${FINANCE_API_BASE:-https://query1.finance.yahoo.com/v8/finance/chart}"

curl_cmd="$(command -v curl 2>/dev/null || true)"
jq_cmd="$(command -v jq 2>/dev/null || true)"

[ -n "$curl_cmd" ] && [ -n "$jq_cmd" ] || exit 0

update_quote() {
  symbol="$1"
  item="$2"

  response="$(
    "$curl_cmd" -fsSL \
      --connect-timeout 5 \
      --max-time 10 \
      --retry 1 \
      --user-agent "SketchyBar finance ticker" \
      "$API_BASE/$symbol?interval=1d&range=2d" 2>/dev/null
  )" || return

  quote="$(
    printf '%s' "$response" |
      "$jq_cmd" -er '
        .chart.result[0].meta
        | select(.regularMarketPrice | type == "number")
        | [
            .regularMarketPrice,
            (.chartPreviousClose // .previousClose // .regularMarketPrice),
            (.currency // "")
          ]
        | @tsv
      ' 2>/dev/null
  )" || return

  IFS=$'\t' read -r price previous_close currency <<< "$quote"

  formatted_price="$(LC_ALL=C printf '%.2f' "$price")"
  change="$(LC_ALL=C awk -v price="$price" -v previous="$previous_close" '
    BEGIN {
      if (previous == 0) {
        printf "+0.0%%"
      } else {
        printf "%+.1f%%", (price - previous) / previous * 100
      }
    }
  ')"

  color="$TEXT_COLOR"
  if LC_ALL=C awk -v price="$price" -v previous="$previous_close" 'BEGIN { exit !(price > previous) }'; then
    color="$POSITIVE_COLOR"
  elif LC_ALL=C awk -v price="$price" -v previous="$previous_close" 'BEGIN { exit !(price < previous) }'; then
    color="$NEGATIVE_COLOR"
  fi

  case "$currency" in
    NOK) value="$formatted_price kr" ;;
    USD) value="\$$formatted_price" ;;
    "") value="$formatted_price" ;;
    *) value="$formatted_price $currency" ;;
  esac

  sketchybar --set "$item" label="$value  $change" label.color="$color"
}

update_quote "STB.OL" "finance.stb"
update_quote "MSFT" "finance.msft"
