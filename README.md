Компоненты системы:
API Gateway (Nginx)
Users Service - порт 8001
Orders Service-1 (реплика) - порт 8002
Orders Service-2 (реплика) - порт 8003
Payments Service - порт 8004
Delivery Service - порт 8005
pgAdmin (управление БД) - порт 5050
4 PostgreSQL базы данных

📁 Структура проекта создана:

.
./payments-service
./payments-service/cmd
./payments-service/internal
./delivery-service
./delivery-service/cmd
./delivery-service/internal
./nginx
./orders-service
./orders-service/cmd
./orders-service/internal
./init-scripts
./users-service
./users-service/cmd
./users-service/internal

🚀 Запуск проекта:

1.  docker-compose up --build
2.  Ждать ~30-60 секунд
3.  Открыть http://localhost

🔄 Демонстрация балансировки:
for i in {1..5}; do curl http://localhost/services/orders/api/system-id | jq . ; done

📊 Полезные команды:
docker-compose ps # Статус контейнеров
docker-compose logs -f # Реал-тайм логи
docker-compose down # Остановить
docker-compose down -v --rmi all # Полная очистка

💾 PostgreSQL управление:
pgAdmin: http://localhost:5050
Email: admin@example.com
Password: admin

📋 SQL операции:
docker-compose exec users-db psql -U postgres -d users_db
docker-compose exec users-db pg_dump -U postgres users_db > backup.sql
