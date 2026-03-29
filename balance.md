docker logs -f orders-service-1

docker logs -f orders-service-2

# 3

echo " Демонстрация балансировки нагрузки"
echo ""

# 10 запросов

for i in {1..10}; do
REPLICA=$(curl -s http://localhost/api/system-id | jq -r '.replica_id')
echo "Запрос $i → обработал: $REPLICA"
done
