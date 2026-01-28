GITCOMMIT?=$(shell git describe --dirty --always)
CGO_ENABLED?=0
BINARY:=server
LDFLAGS:="-s -w -X github.com/awhdesmond/user-service/pkg/common.GitCommit=$(GITCOMMIT)"

CONTAINER_IMAGE?=buttertalk-api
CONTAINER_REGISTRY?=asia-southeast1-docker.pkg.dev/buttertalk
CONTAINER_REPOSITORY?=buttertalk-repo
IMAGE_TAG?=$(GITCOMMIT)

.PHONY: build clean test db

build:
	CGO_ENABLED=$(CGO_ENABLED) go build -ldflags=$(LDFLAGS) -o build/server cmd/server/*.go

db:
	./scripts/migrate-db.sh postgres

clean-db:
	./scripts/clean-db.sh postgres

docker:
	docker build --platform linux/amd64,linux/arm64 -t $(CONTAINER_IMAGE):$(GITCOMMIT) .
	docker tag $(CONTAINER_IMAGE):$(GITCOMMIT) $(CONTAINER_REGISTRY)/$(CONTAINER_REPOSITORY)/$(CONTAINER_IMAGE):$(IMAGE_TAG)

docker-push:
	docker push $(CONTAINER_REGISTRY)/$(CONTAINER_REPOSITORY)/$(CONTAINER_IMAGE):$(IMAGE_TAG)

# clean:
# 	rm -rf build cover.html coverage.out
