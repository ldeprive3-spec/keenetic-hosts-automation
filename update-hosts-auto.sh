#!/bin/sh

# ============================================================
# HOSTS UPDATER FOR KEENETIC v2.0
# Downloads, deduplicates, converts to dnsmasq format
# ============================================================

TEMP_DIR="/tmp/hosts_updater_$$"
SOURCES_LIST="/opt/etc/hosts-automation/sources.list"
DNSMASQ_OUTPUT="/opt/etc/dnsmasq.d/custom.conf"
BACKUP_DIR="/opt/etc/dnsmasq.d/backups"
LOG_FILE="/opt/var/log/hosts-updater.log"
STATS_FILE="/opt/var/log/hosts-stats.txt"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_msg "============================================================"
log_msg "HOSTS UPDATER STARTED"
log_msg "============================================================"

# STEP 1: Prepare
log_msg "[STEP 1/8] Preparing environment..."

mkdir -p "$TEMP_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$LOG_FILE")"

find /tmp -name "hosts_updater_*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null

log_msg "[OK] Environment ready"

# STEP 2: Backup
log_msg "[STEP 2/8] Creating backup..."

if [ -f "$DNSMASQ_OUTPUT" ]; then
    BACKUP_FILE="$BACKUP_DIR/custom.conf.$(date '+%Y%m%d_%H%M%S')"
    cp "$DNSMASQ_OUTPUT" "$BACKUP_FILE"
    OLD_ENTRIES=$(grep -c "^address=" "$DNSMASQ_OUTPUT" 2>/dev/null || echo 0)
    log_msg "[OK] Backup: $BACKUP_FILE"
    log_msg "[INFO] Old entries: $OLD_ENTRIES"
else
    OLD_ENTRIES=0
    log_msg "[INFO] No existing configuration"
fi

# STEP 3: Download sources
log_msg "[STEP 3/8] Downloading sources..."

if [ ! -f "$SOURCES_LIST" ]; then
    log_msg "[ERROR] sources.list not found: $SOURCES_LIST"
    rm -rf "$TEMP_DIR"
    exit 1
fi

SUCCESS_COUNT=0
TOTAL_SOURCES=0
SOURCE_INDEX=0

while IFS='|' read -r URL NAME; do
    # Skip comments and empty lines
    echo "$URL" | grep -qE '^#|^$' && continue

    TOTAL_SOURCES=$((TOTAL_SOURCES + 1))
done < "$SOURCES_LIST"

while IFS='|' read -r URL NAME; do
    # Skip comments
    echo "$URL" | grep -qE '^#|^$' && continue

    SOURCE_INDEX=$((SOURCE_INDEX + 1))
    SOURCE_FILE="$TEMP_DIR/source${SOURCE_INDEX}.txt"

    log_msg "  [$SOURCE_INDEX/$TOTAL_SOURCES] $NAME"

    if wget -q --timeout=30 --tries=3 -O "$SOURCE_FILE" "$URL" 2>/dev/null; then
        SIZE=$(wc -c < "$SOURCE_FILE")
        LINES=$(wc -l < "$SOURCE_FILE")

        if head -n 5 "$SOURCE_FILE" | grep -qE '<!DOCTYPE|<html|<head>'; then
            log_msg "    [ERROR] HTML detected"
            rm -f "$SOURCE_FILE"
        else
            log_msg "    [OK] $SIZE bytes, $LINES lines"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    else
        log_msg "    [ERROR] Download failed"
    fi
done < "$SOURCES_LIST"

log_msg "[INFO] Downloaded: $SUCCESS_COUNT/$TOTAL_SOURCES"

if [ $SUCCESS_COUNT -eq 0 ]; then
    log_msg "[ERROR] No sources downloaded"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# STEP 4: Parse and deduplicate
log_msg "[STEP 4/8] Parsing and deduplicating..."

DOMAINS_FILE="$TEMP_DIR/all_domains.txt"
> "$DOMAINS_FILE"

for SOURCE_FILE in "$TEMP_DIR"/source*.txt; do
    if [ -f "$SOURCE_FILE" ]; then
        grep -vE '^#|^$|^REM|localhost' "$SOURCE_FILE" | \
        awk '{
            if (NF == 1) {
                print "0.0.0.0 " $1
            } else if (NF >= 2) {
                print $1 " " $2
            }
        }' >> "$DOMAINS_FILE"
    fi
done

TOTAL_LINES=$(wc -l < "$DOMAINS_FILE")
log_msg "[INFO] Total lines: $TOTAL_LINES"

DEDUP_FILE="$TEMP_DIR/domains_dedup.txt"
awk '!seen[$2]++' "$DOMAINS_FILE" > "$DEDUP_FILE"

UNIQUE_DOMAINS=$(wc -l < "$DEDUP_FILE")
DUPLICATES=$((TOTAL_LINES - UNIQUE_DOMAINS))

log_msg "[OK] Deduplication completed"
log_msg "  Unique: $UNIQUE_DOMAINS"
log_msg "  Duplicates: $DUPLICATES"

# STEP 5: Convert to dnsmasq
log_msg "[STEP 5/8] Converting to dnsmasq format..."

TEMP_OUTPUT="$TEMP_DIR/custom.conf"
> "$TEMP_OUTPUT"

cat >> "$TEMP_OUTPUT" << HEADER
# ============================================================
# Custom DNS entries - Auto-generated
# Updated: $(date '+%Y-%m-%d %H:%M:%S')
# Sources: $SUCCESS_COUNT/$TOTAL_SOURCES
# Unique domains: $UNIQUE_DOMAINS
# ============================================================

HEADER

BLOCKED_0000=0
REDIRECT_127=0
REDIRECT_OTHER=0

while read -r IP DOMAIN; do
    if ! echo "$DOMAIN" | grep -qE '^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'; then
        continue
    fi

    case "$IP" in
        0.0.0.0)
            echo "address=/$DOMAIN/" >> "$TEMP_OUTPUT"
            BLOCKED_0000=$((BLOCKED_0000 + 1))
            ;;
        127.0.0.1|::1)
            echo "address=/$DOMAIN/127.0.0.1" >> "$TEMP_OUTPUT"
            REDIRECT_127=$((REDIRECT_127 + 1))
            ;;
        *)
            echo "address=/$DOMAIN/$IP" >> "$TEMP_OUTPUT"
            REDIRECT_OTHER=$((REDIRECT_OTHER + 1))
            ;;
    esac
done < "$DEDUP_FILE"

TOTAL_ENTRIES=$((BLOCKED_0000 + REDIRECT_127 + REDIRECT_OTHER))

log_msg "[OK] Conversion completed"
log_msg "  Total entries: $TOTAL_ENTRIES"
log_msg "  Blocked (0.0.0.0): $BLOCKED_0000"
log_msg "  Redirected (127.0.0.1): $REDIRECT_127"
log_msg "  Custom: $REDIRECT_OTHER"

cat >> "$TEMP_OUTPUT" << FOOTER

# ============================================================
# Statistics:
#   Total: $TOTAL_ENTRIES
#   Blocked: $BLOCKED_0000
#   Redirected: $REDIRECT_127
#   Custom: $REDIRECT_OTHER
# ============================================================
FOOTER

# STEP 6: Install
log_msg "[STEP 6/8] Installing configuration..."

if [ -s "$TEMP_OUTPUT" ]; then
    cp "$TEMP_OUTPUT" "$DNSMASQ_OUTPUT"
    log_msg "[OK] Installed: $DNSMASQ_OUTPUT"
else
    log_msg "[ERROR] Empty file, keeping old config"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# STEP 7: Restart dnsmasq
log_msg "[STEP 7/8] Restarting dnsmasq..."

if [ -f /opt/etc/init.d/S56dnsmasq ]; then
    /opt/etc/init.d/S56dnsmasq restart >/dev/null 2>&1
    log_msg "[OK] dnsmasq restarted (S56)"
elif [ -f /opt/etc/init.d/S05dnsmasq ]; then
    /opt/etc/init.d/S05dnsmasq restart >/dev/null 2>&1
    log_msg "[OK] dnsmasq restarted (S05)"
else
    killall dnsmasq 2>/dev/null
    sleep 1
    dnsmasq --conf-file=/opt/etc/dnsmasq.conf 2>/dev/null &
    log_msg "[OK] dnsmasq restarted (manual)"
fi

sleep 2

# STEP 8: Test and cleanup
log_msg "[STEP 8/8] Testing and cleanup..."

TEST_DOMAIN=$(grep -m 1 "^address=/" "$DNSMASQ_OUTPUT" | sed 's/address=\/\([^\/]*\)\/.*/\1/')

if [ -n "$TEST_DOMAIN" ]; then
    if nslookup "$TEST_DOMAIN" 127.0.0.1 >/dev/null 2>&1; then
        log_msg "[OK] DNS test passed: $TEST_DOMAIN"
    else
        log_msg "[WARNING] DNS test failed: $TEST_DOMAIN"
    fi
fi

# Save stats
cat > "$STATS_FILE" << STATS
Last update: $(date '+%Y-%m-%d %H:%M:%S')
Sources: $SUCCESS_COUNT/$TOTAL_SOURCES
Unique domains: $UNIQUE_DOMAINS
Total entries: $TOTAL_ENTRIES
  - Blocked (0.0.0.0): $BLOCKED_0000
  - Redirected (127.0.0.1): $REDIRECT_127
  - Custom redirects: $REDIRECT_OTHER
Previous: $OLD_ENTRIES
Difference: $((TOTAL_ENTRIES - OLD_ENTRIES))
STATS

# Cleanup
rm -rf "$TEMP_DIR"

# Keep last 7 backups
ls -t "$BACKUP_DIR"/custom.conf.* 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null

log_msg "[OK] Cleanup completed"
log_msg "============================================================"
log_msg "UPDATE COMPLETED"
log_msg "  Old: $OLD_ENTRIES | New: $TOTAL_ENTRIES | Diff: $((TOTAL_ENTRIES - OLD_ENTRIES))"
log_msg "============================================================"
log_msg ""

exit 0
