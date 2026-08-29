#!/bin/bash
# Полный скрипт прямого обхода VPN для всех серверов и CDN Apple (Fastly + Akamai + Apple Inc.)

GATEWAY=$(netstat -rn -f inet | grep 'default' | grep 'en0' | awk '{print $2}' | head -n 1)
if [ -z "$GATEWAY" ]; then
    GATEWAY="192.168.1.1"
fi

echo "Применяю прямые маршруты в обход VPN через Wi-Fi шлюз $GATEWAY..."

# 1. Apple Inc. (App Store, DRM, Push, Devices, StoreKit)
sudo route -n add -net 17.0.0.0/8 "$GATEWAY" 2>/dev/null || sudo route -n change -net 17.0.0.0/8 "$GATEWAY"

# 2. Fastly CDN (bag.itunes.apple.com, is1-ssl.mzstatic.com)
sudo route -n add -net 151.101.0.0/16 "$GATEWAY" 2>/dev/null || sudo route -n change -net 151.101.0.0/16 "$GATEWAY"

# 3. Akamai CDN (init.itunes.apple.com, a1.mzstatic.com, apps.apple.com)
sudo route -n add -net 23.0.0.0/8 "$GATEWAY" 2>/dev/null || sudo route -n change -net 23.0.0.0/8 "$GATEWAY"

echo ""
echo "=== Проверка маршрутизации Apple ==="
echo "1. buy.itunes.apple.com:"
route get buy.itunes.apple.com | grep -E 'interface|gateway'
echo "2. bag.itunes.apple.com (Fastly):"
route get bag.itunes.apple.com | grep -E 'interface|gateway'
echo "3. init.itunes.apple.com (Akamai):"
route get init.itunes.apple.com | grep -E 'interface|gateway'
echo "4. mzstatic.com:"
route get is1-ssl.mzstatic.com | grep -E 'interface|gateway'

echo ""
echo "Готово! Все серверы и CDN Apple теперь идут 100% напрямую через ваш домашний интернет (en0)."
