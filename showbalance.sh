#!/bin/bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}║    демонстрация балансировки нагрузки      ║${NC}"
echo ""

# ШАГ 1: Проверка инфраструктуры 
echo -e "${BLUE} 1: Проверка запущенных сервисов${NC}"
echo "-------------------------------------------"
docker-compose ps | grep -E "orders-service|api-gateway"
echo ""
read -p "Нажми Enter для продолжения..."
echo ""

# 2: Единичные запросы 
echo -e "${BLUE} Шаг 2: Проверка эндпоинта system-id${NC}"
echo "Отправляю 5 тестовых запросов..."
echo ""

for i in {1..5}; do
  REPLICA=$(curl -s http://localhost/api/system-id | jq -r '.replica_id')
  if [ "$REPLICA" = "instance-1" ]; then
    echo -e "  Запрос $i → ${GREEN}$REPLICA${NC}"
  else
    echo -e "  Запрос $i → ${BLUE}$REPLICA${NC}"
  fi
  sleep 0.3
done
echo ""
read -p "Нажми Enter для продолжения..."
echo ""

#  ШАГ 3: Массовая нагрузка 
echo -e "${BLUE} 3: Массовая нагрузка (50 запросов)${NC}"

INST1=0
INST2=0
TOTAL=50

echo "Отправляю $TOTAL запросов..."
echo ""

for i in $(seq 1 $TOTAL); do
    REPLICA=$(curl -s http://localhost/api/system-id | jq -r '.replica_id')
    
    if [ "$REPLICA" = "instance-1" ]; then
        INST1=$((INST1 + 1))
        COLOR=$GREEN
    elif [ "$REPLICA" = "instance-2" ]; then
        INST2=$((INST2 + 1))
        COLOR=$BLUE
    fi
    
    printf "\r  Обработано: %d/%d | ${GREEN}instance-1: %d${NC} | ${BLUE}instance-2: %d${NC}" $i $TOTAL $INST1 $INST2
done

echo ""
echo ""

# 4: Результаты 
echo -e "${BLUE} 4: Статистика распределения${NC}"
echo "-------------------------------------------"
PERCENT1=$(echo "scale=1; $INST1*100/$TOTAL" | bc)
PERCENT2=$(echo "scale=1; $INST2*100/$TOTAL" | bc)

echo -e "  ${GREEN}Instance-1:${NC} $INST1 запросов ($PERCENT1%)"
echo -e "  ${BLUE}Instance-2:${NC} $INST2 запросов ($PERCENT2%)"
echo ""

if [ $INST1 -gt 20 ] && [ $INST2 -gt 20 ]; then
    echo -e "${GREEN} Балансировка работает корректно!${NC}"
else
    echo -e "${RED} Балансировка работает неравномерно${NC}"
fi
echo ""

# 5: Логи контейнеров 
echo -e "${BLUE}5: Проверка логов в контейнерах${NC}"
echo "Instance-1 обработал запросов:"
docker logs orders-service-1 2>&1 | grep -c "GET /system-id"

echo "Instance-2 обработал запросов:"
docker logs orders-service-2 2>&1 | grep -c "GET /system-id"
echo ""

echo -e "${YELLOW}║        конец            ║${NC}"


