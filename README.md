# Roulette deployment

This repository contains a docker-compose network build on top of the [roulete.core](https://github.com/GoosvandenBekerom/roulette.core) project.

To run this project locally run the following commands:
- `$ git submodule update --init` (this is only needed the first time to clone the submodules)
- `$ ./run.sh`

## Exposed services
| Service           | Ports        | Additional information
| --------          | --------     | -------
| MySQL             | 3306         | user: root, password: password
| RabbitMQ          | 5672, 15672  | user: guest, password: guest
| Dealer            | 8080         | [roulete.dealer](https://github.com/GoosvandenBekerom/roulette.dealer)
| Monitor           | 8081         | [roulete.monitor](https://github.com/GoosvandenBekerom/roulette.monitor)
| Prometheus        | 9090         | Stats & information about services (JVM and RabbitMQ)
| Grafana           | 3000         | Visual dashboards for Prometheus data
