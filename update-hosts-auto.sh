#!/bin/sh

# ================================================================
# Automatic Hosts Update Script with nfqws integration
# GitHub: https://github.com/ldeprive3-spec/keenetic-hosts-automation
# Version: 2.0
# ================================================================

LOG_FILE="/opt/var/log/hosts-updater.log"
HOSTS_DIR="/opt/etc/dnsmasq.d"
TEMP_DIR="/tmp/hosts-update-$$"
BACKUP_DIR="/opt/var/backups/hosts"

# Интеграция с nfqws
NFQWS_USER_LIST="/opt/etc/nfqws/user.list"
NFQWS_INSTALLED=0

# Проверка наличия nfqws
if [ -f "/opt/etc/init.d/S51nfqws" ]; then
    NFQWS_INSTALLED=1
fi

# ================================================================
# Источники
# ================================================================
STEVENBLACK_URL="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
ADAWAY_URL="https://adaway.org/hosts.txt"

# ================================================================
# Функции
# ================================================================

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

download_file() {
    local url="$1"
    local output="$2"
    
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output" 2>>"$LOG_FILE"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O "$output" 2>>"$LOG_FILE"
    else
        return 1
    fi
    
    return $?
}

convert_to_dnsmasq() {
    local input="$1"
    local output="$2"
    
    grep -E "^(0\.0\.0\.0|127\.0\.0\.1)" "$input" | \
    grep -v "^#" | \
    grep -v "localhost" | \
    awk '{print "address=/"$2"/0.0.0.0"}' | \
    sort -u > "$output"
}

extract_domains_for_nfqws() {
    local input="$1"
    local output="$2"
    
    # Извлечение доменов из dnsmasq формата
    grep "^address=" "$input" | \
    sed 's|address=/\([^/]*\)/.*|\1|' | \
    sort -u > "$output"
}

# ================================================================
# Главная логика
# ================================================================

log_message "========================================"
log_message "Начало обновления hosts"
log_message "nfqws интеграция: $([ $NFQWS_INSTALLED -eq 1 ] && echo 'ДА' || echo 'НЕТ')"
log_message "========================================"

mkdir -p "$TEMP_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$HOSTS_DIR"

# Бэкап
if [ -f "$HOSTS_DIR/auto-blocked.conf" ]; then
    BACKUP_FILE="$BACKUP_DIR/auto-blocked-$(date +%Y%m%d-%H%M%S).conf"
    cp "$HOSTS_DIR/auto-blocked.conf" "$BACKUP_FILE"
    log_message "Бэкап: $BACKUP_FILE"
    
    ls -t "$BACKUP_DIR"/auto-blocked-*.conf 2>/dev/null | tail -n +6 | xargs rm -f 2>/dev/null
fi

TOTAL_ENTRIES=0

# ================================================================
# Загрузка источников
# ================================================================

log_message "Загрузка StevenBlack hosts..."
if download_file "$STEVENBLACK_URL" "$TEMP_DIR/stevenblack.txt"; then
    convert_to_dnsmasq "$TEMP_DIR/stevenblack.txt" "$TEMP_DIR/stevenblack.conf"
    ENTRIES=$(wc -l < "$TEMP_DIR/stevenblack.conf")
    TOTAL_ENTRIES=$((TOTAL_ENTRIES + ENTRIES))
    log_message "✓ StevenBlack: $ENTRIES записей"
else
    log_message "✗ Ошибка загрузки StevenBlack"
fi

# ================================================================
# Объединение
# ================================================================

if [ $TOTAL_ENTRIES -gt 0 ]; then
    log_message "Объединение списков..."
    
    cat "$TEMP_DIR"/*.conf 2>/dev/null | sort -u > "$TEMP_DIR/combined.conf"
    
    FINAL_COUNT=$(wc -l < "$TEMP_DIR/combined.conf")
    
    mv "$TEMP_DIR/combined.conf" "$HOSTS_DIR/auto-blocked.conf"
    chmod 644 "$HOSTS_DIR/auto-blocked.conf"
    
    log_message "✓ Итого записей: $FINAL_COUNT"
    
    # ================================================================
    # Интеграция с nfqws
    # ================================================================
    if [ $NFQWS_INSTALLED -eq 1 ]; then
        log_message "Синхронизация с nfqws..."
        
        extract_domains_for_nfqws "$HOSTS_DIR/auto-blocked.conf" "$TEMP_DIR/nfqws-domains.txt"
        
        if [ -f "$NFQWS_USER_LIST" ]; then
            cat "$NFQWS_USER_LIST" "$TEMP_DIR/nfqws-domains.txt" | sort -u > "$NFQWS_USER_LIST.new"
            mv "$NFQWS_USER_LIST.new" "$NFQWS_USER_LIST"
        else
            mkdir -p "$(dirname $NFQWS_USER_LIST)"
            mv "$TEMP_DIR/nfqws-domains.txt" "$NFQWS_USER_LIST"
        fi
        
        NFQWS_COUNT=$(wc -l < "$NFQWS_USER_LIST")
        log_message "✓ nfqws: $NFQWS_COUNT доменов"
        
        # Перезапуск nfqws
        /opt/etc/init.d/S51nfqws restart >> "$LOG_FILE" 2>&1
    fi
    
    # Перезапуск dnsmasq
    log_message "Перезапуск dnsmasq..."
    if /opt/etc/init.d/S56dnsmasq restart >> "$LOG_FILE" 2>&1; then
        log_message "✓ dnsmasq перезапущен"
    else
        log_message "✗ Ошибка перезапуска dnsmasq"
    fi
else
    log_message "✗ Не загружено записей"
fi

# Очистка
rm -rf "$TEMP_DIR"

log_message "========================================"
log_message "Обновление завершено"
log_message "========================================"
log_message ""

exit 0
