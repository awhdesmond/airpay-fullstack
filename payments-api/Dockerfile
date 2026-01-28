FROM golang:1.25 AS build

WORKDIR /app

COPY go.mod go.mod
COPY go.sum go.sum

RUN go mod download

COPY . .
RUN make build

FROM gcr.io/distroless/static-debian12

WORKDIR /app
COPY --from=build /app/build/ /app
