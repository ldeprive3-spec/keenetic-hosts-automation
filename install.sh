#!/bin/sh

# ================================================================
# Keenetic DNS + DPI Bypass Automation
# GitHub: https://github.com/ldeprive3-spec/keenetic-hosts-automation
# Version: 2.0
# ================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/ldeprive3-spec/keenetic-hosts-automation/main"
TEMP_DIR="/tmp/keenetic-dns-setup"

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Keenetic DNS + DPI Bypass Installer          ║${NC}"
echo -e "${BLUE}║  dnsmasq + nfqws-keenetic                      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# ================================================================
# Проверка root
# ================================================================
if [ "$(id -u)" != "0" ]; then
    echo -e "${RED}✗ Требуются права root!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Права root: OK${NC}"

# ================================================================
# Проверка Entware
# ================================================================
if [ ! -d "/opt/etc" ] || [ ! -f "/opt/bin/opkg" ]; then
    echo -e "${RED}✗ Entware не установлен!${NC}"
    echo ""
    echo "Установите Entware через веб-интерфейс Keenetic:"
    echo "  Управление → Компоненты → Система OPKG"
    exit 1
fi

echo -e "${GREEN}✓ Entware: установлен${NC}"

# ================================================================
# Определение режима установки
# ================================================================
if [ -n "$1" ]; then
    INSTALL_MODE="$1"
elif [ -n "$MODE" ]; then
    INSTALL_MODE="$MODE"
else
    INSTALL_MODE=3
fi

echo ""
echo -e "${YELLOW}Режим установки:${NC}"

case "$INSTALL_MODE" in
    1)
        INSTALL_DNSMASQ=1
        INSTALL_NFQWS=0
        echo -e "${GREEN}✓ Режим 1: только dnsmasq (DNS сервер + hosts)${NC}"
        ;;
    2)
        INSTALL_DNSMASQ=0
        INSTALL_NFQWS=1
        echo -e "${GREEN}✓ Режим 2: только nfqws (DPI bypass)${NC}"
        ;;
    3|*)
        INSTALL_DNSMASQ=1
        INSTALL_NFQWS=1
        echo -e "${GREEN}✓ Режим 3: dnsmasq + nfqws (ПОЛНАЯ ЗАЩИТА)${NC}"
        ;;
esac

echo ""
echo -e "${BLUE}💡 Совет: для выбора режима используйте:${NC}"
echo "   MODE=1 curl ... | sh  (только dnsmasq)"
echo "   MODE=2 curl ... | sh  (только nfqws)"
echo "   MODE=3 curl ... | sh  (оба, по умолчанию)"
echo ""

sleep 2

# ================================================================
# Установка curl/wget
# ================================================================
echo -e "${YELLOW}► Проверка зависимостей...${NC}"

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
    echo "  Установка curl..."
    opkg update >/dev/null 2>&1
    opkg install curl >/dev/null 2>&1
fi

if command -v curl >/dev/null 2>&1; then
    DOWNLOAD_CMD="curl -fsSL"
    echo -e "${GREEN}✓ curl${NC}"
elif command -v wget >/dev/null 2>&1; then
    DOWNLOAD_CMD="wget -qO-"
    echo -e "${GREEN}✓ wget${NC}"
else
    echo -e "${RED}✗ Не удалось установить curl/wget${NC}"
    exit 1
fi

# ================================================================
# Проверка компонентов для nfqws
# ================================================================
if [ "$INSTALL_NFQWS" = "1" ]; then
    echo ""
    echo -e "${YELLOW}► Проверка компонентов Keenetic для nfqws...${NC}"
    
    if ! ip -6 addr show >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ IPv6 не включен${NC}"
        echo "  Включите: http://192.168.1.1 → Управление → Компоненты → Протокол IPv6"
        echo ""
        echo "  Продолжить без nfqws? (установим только dnsmasq)"
        echo "  Нажмите Ctrl+C для отмены, или ждите 10 сек..."
        sleep 10
        INSTALL_NFQWS=0
    fi
    
    if [ "$INSTALL_NFQWS" = "1" ] && ! lsmod 2>/dev/null | grep -q "nf_"; then
        echo -e "${YELLOW}⚠ Netfilter модули не найдены${NC}"
        echo "  Установите: http://192.168.1.1 → Управление → Компоненты"
        echo "  → Модули ядра Netfilter"
        echo ""
        echo "  Продолжить без nfqws? (установим только dnsmasq)"
        echo "  Нажмите Ctrl+C для отмены, или ждите 10 сек..."
        sleep 10
        INSTALL_NFQWS=0
    fi
    
    if [ "$INSTALL_NFQWS" = "1" ]; then
        echo -e "${GREEN}✓ Компоненты готовы для nfqws${NC}"
    fi
fi

# ================================================================
# Создание директории
# ================================================================
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# ================================================================
# Установка dnsmasq
# ================================================================
if [ "$INSTALL_DNSMASQ" = "1" ]; then
    echo ""
    echo -e "${YELLOW}► Загрузка setup-dnsmasq-custom.sh...${NC}"
    
    $DOWNLOAD_CMD "${REPO_URL}/setup-dnsmasq-custom.sh" > setup-dnsmasq-custom.sh 2>/dev/null
    
    if [ $? -eq 0 ] && [ -s setup-dnsmasq-custom.sh ]; then
        chmod +x setup-dnsmasq-custom.sh
        echo -e "${GREEN}✓ Скрипт загружен${NC}"
        
        echo ""
        echo -e "${YELLOW}► Установка dnsmasq...${NC}"
        echo ""
        
        ./setup-dnsmasq-custom.sh
        
        if [ $? -eq 0 ]; then
            echo ""
            echo -e "${GREEN}✓ dnsmasq успешно установлен${NC}"
            DNSMASQ_OK=1
        else
            echo ""
            echo -e "${RED}✗ Ошибка установки dnsmasq${NC}"
            DNSMASQ_OK=0
        fi
    else
        echo -e "${RED}✗ Ошибка загрузки скрипта${NC}"
        DNSMASQ_OK=0
    fi
    
    # Копирование update-hosts-auto.sh и создание sources.list
    if [ "$DNSMASQ_OK" = "1" ]; then
        echo ""
        echo -e "${YELLOW}► Установка скрипта обновления...${NC}"
        
        # Скачать скрипт обновления
        $DOWNLOAD_CMD "${REPO_URL}/update-hosts-auto.sh" > /opt/etc/update-hosts-auto.sh 2>/dev/null
        chmod +x /opt/etc/update-hosts-auto.sh
        
        # Создать директорию для sources.list
        SOURCES_DIR="/opt/etc/hosts-automation"
        SOURCES_FILE="$SOURCES_DIR/sources.list"
        
        mkdir -p "$SOURCES_DIR"
        
        # Создать sources.list если не существует
        if [ ! -f "$SOURCES_FILE" ]; then
            echo "  Создание sources.list с вашими источниками..."
            cat > "$SOURCES_FILE" << 'EOFLIST'
# ============================================================
# HOSTS SOURCES LIST
# Format: URL|Description
# Lines starting with # are ignored
# ============================================================

# ============================================================
# PRIMARY SOURCES
# ============================================================

# GeoHide DNS - разблокировка заблокированных сайтов
https://raw.githubusercontent.com/Internet-Helper/GeoHideDNS/refs/heads/main/hosts/hosts|dns.geohide.ru: hosts file

# Zapret Discord/YouTube - обход блокировок Discord и YouTube
https://raw.githubusercontent.com/Flowseal/zapret-discord-youtube/refs/heads/main/.service/hosts|Zapret Discord/YouTube

# ============================================================
# OPTIONAL SOURCES (раскомментируйте при необходимости)
# ============================================================

# StevenBlack unified hosts - комплексная блокировка рекламы
#https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts|StevenBlack Unified

# AdAway - блокировка мобильной рекламы
#https://adaway.org/hosts.txt|AdAway

# AdGuard DNS filter
#https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt|AdGuard DNS

# Dan Pollock's hosts
#https://someonewhocares.org/hosts/zero/hosts|Dan Pollock

# Peter Lowe's Ad Server List
#https://pgl.yoyo.org/adservers/serverlist.php?hostformat=hosts&showintro=0&mimetype=plaintext|Peter Lowe

# ============================================================
# CUSTOM SOURCES
# ============================================================

# Добавьте свои источники ниже в формате:
# URL|Описание

EOFLIST
            echo -e "${GREEN}✓ sources.list создан: $SOURCES_FILE${NC}"
            echo -e "${BLUE}  Источники: GeoHide DNS + Zapret Discord/YouTube${NC}"
        else
            echo -e "${GREEN}✓ sources.list уже существует${NC}"
        fi
        
        echo -e "${GREEN}✓ Скрипт обновления установлен${NC}"
        echo ""
        echo -e "${BLUE}💡 Настройка источников:${NC}"
        echo "   nano $SOURCES_FILE"
    fi
fi

# ================================================================
# Установка nfqws
# ================================================================
if [ "$INSTALL_NFQWS" = "1" ]; then
    echo ""
    echo -e "${YELLOW}► Установка nfqws-keenetic...${NC}"
    
    echo "  Установка зависимостей..."
    opkg update >/dev/null 2>&1
    opkg install ca-certificates wget-ssl >/dev/null 2>&1
    opkg remove wget-nossl >/dev/null 2>&1
    
    echo "  Добавление репозитория nfqws..."
    mkdir -p /opt/etc/opkg
    echo "src/gz nfqws-keenetic https://anonym-tsk.github.io/nfqws-keenetic/all" > /opt/etc/opkg/nfqws-keenetic.conf
    
    echo "  Установка пакетов..."
    opkg update >/dev/null 2>&1
    opkg install nfqws-keenetic >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ nfqws-keenetic установлен${NC}"
        NFQWS_OK=1
        
        echo ""
        echo -e "${YELLOW}  Установка веб-интерфейса nfqws...${NC}"
        opkg install nfqws-keenetic-web >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Веб-интерфейс: http://192.168.1.1:90${NC}"
        else
            echo -e "${YELLOW}⚠ Веб-интерфейс не установлен (необязательно)${NC}"
        fi
        
        if [ "$INSTALL_DNSMASQ" = "1" ] && [ "$DNSMASQ_OK" = "1" ]; then
            echo ""
            echo -e "${YELLOW}► Настройка интеграции dnsmasq ↔ nfqws...${NC}"
            
            cat > /opt/etc/sync-dns-dpi.sh << 'SYNCEOF'
#!/bin/sh
# Синхронизация списков между dnsmasq и nfqws

DNSMASQ_CUSTOM="/opt/etc/dnsmasq.d/custom.conf"
NFQWS_USER_LIST="/opt/etc/nfqws/user.list"

if [ -f "$DNSMASQ_CUSTOM" ]; then
    mkdir -p "$(dirname $NFQWS_USER_LIST)"
    
    grep "^address=" "$DNSMASQ_CUSTOM" | \
    sed 's|address=/\([^/]*\)/.*|\1|' | \
    sort -u > "$NFQWS_USER_LIST.tmp"
    
    if [ -f "$NFQWS_USER_LIST" ]; then
        cat "$NFQWS_USER_LIST" "$NFQWS_USER_LIST.tmp" | sort -u > "$NFQWS_USER_LIST.new"
        mv "$NFQWS_USER_LIST.new" "$NFQWS_USER_LIST"
    else
        mv "$NFQWS_USER_LIST.tmp" "$NFQWS_USER_LIST"
    fi
    
    rm -f "$NFQWS_USER_LIST.tmp"
    
    /opt/etc/init.d/S51nfqws restart >/dev/null 2>&1
    
    echo "Синхронизировано: $(wc -l < $NFQWS_USER_LIST) доменов"
fi
SYNCEOF
            
            chmod +x /opt/etc/sync-dns-dpi.sh
            
            mkdir -p /opt/etc/cron.d
            echo "10 3 * * * root /opt/etc/sync-dns-dpi.sh >> /opt/var/log/sync-dns-dpi.log 2>&1" > /opt/etc/cron.d/sync-dns-dpi
            
            /opt/etc/sync-dns-dpi.sh >/dev/null 2>&1
            
            echo -e "${GREEN}✓ Интеграция настроена${NC}"
        fi
    else
        echo -e "${RED}✗ Ошибка установки nfqws${NC}"
        echo "  Проверьте компоненты Keenetic (IPv6, Netfilter)"
        NFQWS_OK=0
    fi
fi

# ================================================================
# Очистка
# ================================================================
cd /
rm -rf "$TEMP_DIR"

# ================================================================
# Итоговая информация
# ================================================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Установка завершена!                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

SUCCESS=0

if [ "$INSTALL_DNSMASQ" = "1" ] && [ "$DNSMASQ_OK" = "1" ]; then
    echo -e "${GREEN}✅ dnsmasq установлен:${NC}"
    echo "   DNS сервер: 192.168.1.2:53"
    echo "   Источники: GeoHide DNS + Zapret Discord/YouTube"
    echo "   Команды:"
    echo "     dns-status"
    echo "     /opt/etc/init.d/S56dnsmasq restart"
    echo "     /opt/etc/update-hosts-auto.sh"
    echo ""
    SUCCESS=1
fi

if [ "$INSTALL_NFQWS" = "1" ] && [ "$NFQWS_OK" = "1" ]; then
    echo -e "${GREEN}✅ nfqws-keenetic установлен:${NC}"
    echo "   DPI bypass активен"
    echo "   Команды:"
    echo "     /opt/etc/init.d/S51nfqws status"
    echo "     /opt/etc/init.d/S51nfqws restart"
    echo "   Конфиг: /opt/etc/nfqws/nfqws.conf"
    
    if [ -f /opt/bin/nfqws-keenetic-web ]; then
        echo "   Веб: http://192.168.1.1:90"
    fi
    echo ""
    SUCCESS=1
fi

if [ "$INSTALL_DNSMASQ" = "1" ] && [ "$INSTALL_NFQWS" = "1" ] && [ "$DNSMASQ_OK" = "1" ] && [ "$NFQWS_OK" = "1" ]; then
    echo -e "${YELLOW}🔗 Интеграция:${NC}"
    echo "   Синхронизация: /opt/etc/sync-dns-dpi.sh"
    echo ""
fi

if [ "$INSTALL_DNSMASQ" = "1" ] && [ "$DNSMASQ_OK" = "1" ]; then
    echo -e "${YELLOW}📋 Следующий шаг - настройка DNS в Keenetic:${NC}"
    echo "   1. Откройте: http://192.168.1.1"
    echo "   2. Интернет → Подключения → Ваше подключение"
    echo "   3. DNS 1: 192.168.1.2"
    echo "   4. DNS 2: 8.8.8.8"
fi

echo ""

if [ "$SUCCESS" = "1" ]; then
    echo -e "${GREEN}✅ Готово! Проверьте: dns-status${NC}"
    exit 0
else
    echo -e "${RED}✗ Установка завершилась с ошибками${NC}"
    exit 1
fi
