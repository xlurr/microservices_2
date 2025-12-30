PROJECT: Microservices Architecture Demo
AUTHOR: xlurr

==================================================
DESCRIPTION
==================================================

This project demonstrates a microservices architecture
where all inter-service communication goes ONLY through
an API Gateway (Nginx).

Services DO NOT communicate directly with each other.
The gateway acts as a single entry point and load balancer.

==================================================
ARCHITECTURE OVERVIEW
==================================================

Client
|
v
API Gateway (Nginx)
|
|----> users-service ----> users-db
|
|----> orders-service (replica 1) ----\
 | > orders-db
|----> orders-service (replica 2) ----/
|
|----> payments-service ----> payments-db
|
|----> delivery-service ----> delivery-db

==================================================
CORE PRINCIPLES
==================================================

- No direct service-to-service calls
- All HTTP traffic goes through API Gateway
- Load balancing handled by Nginx
- Orders service runs in multiple replicas
- Each service has its own database

==================================================
SERVICE COMMUNICATION
==================================================

Each service uses the environment variable:

GATEWAY_URL = http://api-gateway

Example (users-service -> orders-service):

users-service
|
| HTTP request to:
| http://api-gateway/api/orders/user/{id}
|
v
API Gateway (Nginx)
|
| load balancing
|
v
orders-service replica

==================================================
LOAD BALANCING
==================================================

Orders service has multiple instances:

orders-service-1
orders-service-2

Nginx distributes requests between them automatically.

==================================================
DEMONSTRATION SCRIPT
==================================================

File: showbalance.sh (located in project root)

Purpose:

- Send multiple requests through API Gateway
- Show which orders-service replica handled each request

Usage:

chmod +x showbalance.sh
./showbalance.sh

Expected output example:

Request 1 -> instance-1
Request 2 -> instance-2
Request 3 -> instance-1
Request 4 -> instance-2

==================================================
PROJECT START
==================================================

To start the entire system:

docker-compose up --build

==================================================
SUMMARY
==================================================

This project clearly demonstrates:

- API Gateway pattern
- Load balancing
- Service isolation
- Centralized routing
- Microservice-based architecture
