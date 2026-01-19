#!/bin/sh

# ================================================================
# Keenetic DNS + DPI Bypass Automation
# GitHub: https://github.com/ldeprive3-spec/keenetic-hosts-automation
# Version: 2.0 (dnsmasq + nfqws support)
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
# Выбор режима установки
# ================================================================
echo ""
echo -e "${YELLOW}Выберите режим установки:${NC}"
echo "  1) Только dnsmasq (DNS сервер + hosts)"
echo "  2) Только nfqws (DPI bypass для YouTube/Discord)"
echo "  3) Оба (РЕКОМЕНДУЕТСЯ - полная защита)"
echo ""
read -p "Ваш выбор [1-3]: " INSTALL_MODE

case "$INSTALL_MODE" in
    1)
        INSTALL_DNSMASQ=1
        INSTALL_NFQWS=0
        echo -e "${GREEN}✓ Режим: только dnsmasq${NC}"
        ;;
    2)
        INSTALL_DNSMASQ=0
        INSTALL_NFQWS=1
        echo -e "${GREEN}✓ Режим: только nfqws${NC}"
        ;;
    3)
        INSTALL_DNSMASQ=1
        INSTALL_NFQWS=1
        echo -e "${GREEN}✓ Режим: dnsmasq + nfqws (полный)${NC}"
        ;;
    *)
        echo -e "${RED}✗ Неверный выбор, используем режим 3${NC}"
        INSTALL_DNSMASQ=1
        INSTALL_NFQWS=1
        ;;
esac

# ================================================================
# Установка curl/wget
# ================================================================
echo ""
echo -e "${YELLOW}► Проверка зависимостей...${NC}"

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
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
# Проверка компонентов Keenetic для nfqws
# ================================================================
if [ "$INSTALL_NFQWS" = "1" ]; then
    echo ""
    echo -e "${YELLOW}► Проверка компонентов Keenetic для nfqws...${NC}"
    echo ""
    echo -e "${BLUE}ВНИМАНИЕ!${NC} Для работы nfqws требуются компоненты:"
    echo "  1. Протокол IPv6 (Network functions → IPv6)"
    echo "  2. Модули ядра Netfilter (OPKG → Kernel modules)"
    echo ""
    echo "Установите их через веб-интерфейс: http://192.168.1.1"
    echo ""
    read -p "Компоненты установлены? [y/N]: " COMPONENTS_OK
    
    if [ "$COMPONENTS_OK" != "y" ] && [ "$COMPONENTS_OK" != "Y" ]; then
        echo -e "${YELLOW}⚠ Установка nfqws будет пропущена${NC}"
        INSTALL_NFQWS=0
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
        ./setup-dnsmasq-custom.sh
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ dnsmasq установлен${NC}"
        else
            echo -e "${RED}✗ Ошибка установки dnsmasq${NC}"
        fi
    else
        echo -e "${RED}✗ Ошибка загрузки скрипта${NC}"
    fi
    
    # Копирование update-hosts-auto.sh
    $DOWNLOAD_CMD "${REPO_URL}/update-hosts-auto.sh" > /opt/etc/update-hosts-auto.sh 2>/dev/null
    chmod +x /opt/etc/update-hosts-auto.sh
fi

# ================================================================
# Установка nfqws
# ================================================================
if [ "$INSTALL_NFQWS" = "1" ]; then
    echo ""
    echo -e "${YELLOW}► Установка nfqws-keenetic...${NC}"
    
    # Установка зависимостей
    opkg update >/dev/null 2>&1
    opkg install ca-certificates wget-ssl >/dev/null 2>&1
    opkg remove wget-nossl >/dev/null 2>&1
    
    # Добавление репозитория nfqws
    mkdir -p /opt/etc/opkg
    echo "src/gz nfqws-keenetic https://anonym-tsk.github.io/nfqws-keenetic/all" > /opt/etc/opkg/nfqws-keenetic.conf
    
    # Установка nfqws
    opkg update >/dev/null 2>&1
    opkg install nfqws-keenetic >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ nfqws-keenetic установлен${NC}"
        
        # Опционально веб-интерфейс
        echo ""
        read -p "Установить веб-интерфейс nfqws? (http://192.168.1.1:90) [y/N]: " INSTALL_WEB
        
        if [ "$INSTALL_WEB" = "y" ] || [ "$INSTALL_WEB" = "Y" ]; then
            opkg install nfqws-keenetic-web >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Веб-интерфейс установлен: http://192.168.1.1:90${NC}"
            fi
        fi
        
        # Настройка интеграции с dnsmasq
        if [ "$INSTALL_DNSMASQ" = "1" ]; then
            echo ""
            echo -e "${YELLOW}► Интеграция dnsmasq ↔ nfqws...${NC}"
            
            # Создание скрипта синхронизации списков
            cat > /opt/etc/sync-dns-dpi.sh << 'SYNCSCRIPT'
#!/bin/sh
# Синхронизация списков доменов между dnsmasq и nfqws

DNSMASQ_CUSTOM="/opt/etc/dnsmasq.d/custom.conf"
NFQWS_USER_LIST="/opt/etc/nfqws/user.list"

# Извлечение доменов из dnsmasq и добавление в nfqws
if [ -f "$DNSMASQ_CUSTOM" ]; then
    grep "^address=" "$DNSMASQ_CUSTOM" | \
    sed 's|address=/\([^/]*\)/.*|\1|' | \
    sort -u > "$NFQWS_USER_LIST.tmp"
    
    # Объединение с существующими
    if [ -f "$NFQWS_USER_LIST" ]; then
        cat "$NFQWS_USER_LIST" "$NFQWS_USER_LIST.tmp" | sort -u > "$NFQWS_USER_LIST.new"
        mv "$NFQWS_USER_LIST.new" "$NFQWS_USER_LIST"
    else
        mv "$NFQWS_USER_LIST.tmp" "$NFQWS_USER_LIST"
    fi
    
    rm -f "$NFQWS_USER_LIST.tmp"
    
    # Перезапуск nfqws
    /opt/etc/init.d/S51nfqws restart >/dev/null 2>&1
    
    echo "Списки синхронизированы: $(wc -l < $NFQWS_USER_LIST) доменов"
fi
SYNCSCRIPT
            
            chmod +x /opt/etc/sync-dns-dpi.sh
            
            # Добавление в cron
            echo "10 3 * * * root /opt/etc/sync-dns-dpi.sh >> /opt/var/log/sync-dns-dpi.log 2>&1" >> /opt/etc/cron.d/sync-dns-dpi
            
            # Первая синхронизация
            /opt/etc/sync-dns-dpi.sh
            
            echo -e "${GREEN}✓ Интеграция настроена${NC}"
        fi
    else
        echo -e "${RED}✗ Ошибка установки nfqws${NC}"
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

if [ "$INSTALL_DNSMASQ" = "1" ]; then
    echo -e "${GREEN}✅ dnsmasq установлен:${NC}"
    echo "   DNS сервер: 192.168.1.2:53"
    echo "   Команды:"
    echo "     dns-status                          - статус"
    echo "     /opt/etc/init.d/S56dnsmasq restart  - перезапуск"
    echo ""
fi

if [ "$INSTALL_NFQWS" = "1" ]; then
    echo -e "${GREEN}✅ nfqws-keenetic установлен:${NC}"
    echo "   DPI bypass активен"
    echo "   Команды:"
    echo "     /opt/etc/init.d/S51nfqws status     - статус"
    echo "     /opt/etc/init.d/S51nfqws restart    - перезапуск"
    echo "   Конфиг: /opt/etc/nfqws/nfqws.conf"
    echo "   Домены: /opt/etc/nfqws/user.list"
    
    if [ -f /opt/bin/nfqws-keenetic-web ]; then
        echo "   Веб: http://192.168.1.1:90"
    fi
    echo ""
fi

if [ "$INSTALL_DNSMASQ" = "1" ] && [ "$INSTALL_NFQWS" = "1" ]; then
    echo -e "${YELLOW}🔗 Интеграция:${NC}"
    echo "   Домены из dnsmasq автоматически синхронизируются с nfqws"
    echo "   Синхронизация: /opt/etc/sync-dns-dpi.sh"
    echo ""
fi

echo -e "${YELLOW}📋 Настройка DNS в Keenetic:${NC}"
if [ "$INSTALL_DNSMASQ" = "1" ]; then
    echo "   http://192.168.1.1 → Интернет → Подключения"
    echo "   DNS 1: 192.168.1.2"
    echo "   DNS 2: 8.8.8.8"
fi

echo ""
echo -e "${GREEN}Готово! Проверьте работу: dns-status${NC}"
echo ""

exit 0
