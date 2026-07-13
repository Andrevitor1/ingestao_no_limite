#!/bin/bash
# Estimativa de timeout do pipeline a partir do perfil do dataset oficial.
#
# Uso (após carregar juiz/config.env):
#   source scripts/lib/estimate-timeout.sh
#   compute_pipeline_timeout    # imprime segundos
#   print_timeout_estimate      # log legível

# Dataset oficial (5 zips ~1 GB; primeiro descompactado ~2 GB; total ~8–10 GB)
: "${DATA_ZIP_COUNT:=5}"
: "${DATA_COMPRESSED_MB:=1024}"
: "${DATA_UNCOMPRESSED_MB:=10240}"
: "${PIPELINE_THROUGHPUT_FLOOR_MBPS:=2.5}"
: "${PIPELINE_TIMEOUT_MARGIN_PCT:=25}"
: "${PIPELINE_TIMEOUT_ROUND_SEC:=300}"

format_timeout_human() {
    local sec="$1"
    awk -v s="$sec" 'BEGIN {
        m = int((s + 59) / 60)
        h = int(m / 60)
        rm = m % 60
        if (h > 0) printf "%dh%02dm (%ds)", h, rm, s
        else printf "%dm (%ds)", m, s
    }'
}

compute_pipeline_timeout() {
    local base timeout rounded
    base=$(awk -v mb="$DATA_UNCOMPRESSED_MB" -v mbps="$PIPELINE_THROUGHPUT_FLOOR_MBPS" \
        'BEGIN {printf "%.0f", mb / mbps}')
    timeout=$(awk -v b="$base" -v m="$PIPELINE_TIMEOUT_MARGIN_PCT" \
        'BEGIN {printf "%.0f", b * (1 + m / 100)}')
    rounded=$(awk -v t="$timeout" -v r="$PIPELINE_TIMEOUT_ROUND_SEC" \
        'BEGIN {printf "%.0f", int((t + r - 1) / r) * r}')
    echo "$rounded"
}

print_timeout_estimate() {
    local computed human floor_label
    computed="$(compute_pipeline_timeout)"
    human="$(format_timeout_human "$computed")"
    floor_label="${PIPELINE_THROUGHPUT_FLOOR_MBPS} MB/s"
    cat <<EOF
Estimativa de timeout (dataset oficial):
  zips: ${DATA_ZIP_COUNT} (~${DATA_COMPRESSED_MB} MB comprimidos)
  descompactado (est.): ~${DATA_UNCOMPRESSED_MB} MB
  throughput mínimo assumido: ${floor_label} no Celeron (2 CPU / 2 GB RAM)
  margem: ${PIPELINE_TIMEOUT_MARGIN_PCT}%
  timeout calculado: ${human}
EOF
}

resolve_pipeline_timeout() {
    if [[ -n "${PIPELINE_TIMEOUT_SEC:-}" ]]; then
        echo "$PIPELINE_TIMEOUT_SEC"
        return
    fi
    compute_pipeline_timeout
}
