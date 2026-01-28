# Payments API

## Dependencies

|  Dependency    |   Version   |
| -------------- | ----------- |
| Postgres       |  18.1       |
| Redis          |  8.4.0      |

## Getting Started

```bash
# Postgres
docker run -d \
  --name postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_DB=buttertalk \
  -p 5432:5432 \
  -v pgdata:/var/lib/postgresql \
  postgres:18.1

# Redis
docker run -d --name redis -p 6379:6379 redis:8.4

# Perform SQL migrations on postgres
# Flyway is an open-source database-migration tool that helps us
# to version control our data schemas.
brew install flyway
make db
```
