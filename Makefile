BIN_DIR := $(PWD)/bin
KIND := $(BIN_DIR)/kind
KIND_VERSION := 0.8.1

HELM := $(BIN_DIR)/helm
HELM_VERSION := 3.3.3
OS := linux
ARCH := amd64

KUBECTL := $(BIN_DIR)/kubectl

CLUSTER_NAME := dex-sample
KUBERNETES_VERSION=1.18.8

DEX_SAMPLE_APP_IMG := dex-sample-app:dev

.PHONY: start
start-kind: $(KIND)
	if [ ! "$(shell kind get clusters | grep $(CLUSTER_NAME))" ]; then \
		$(KIND) create cluster --name=$(CLUSTER_NAME) --image kindest/node:v$(KUBERNETES_VERSION) --wait 180s; \
	fi

.PHONY: stop
stop-kind: $(KIND)
	if [ "$(shell kind get clusters | grep $(CLUSTER_NAME))" ]; then \
		$(KIND) delete cluster --name=$(CLUSTER_NAME); \
	fi

.PHONY: dex
dex: start-kind $(HELM) $(KUBECTL)
	$(KUBECTL) apply -f ./manifests/dex-namespace.yaml
	if [ "$(shell $(HELM) list -n dex-system --short | grep dex)" ]; then \
		$(HELM) upgrade dex -n dex-system stable/dex -f ./manifests/dex-values.yaml; \
	else \
		$(HELM) install dex -n dex-system stable/dex -f ./manifests/dex-values.yaml; \
	fi

.PHONY: build-image
build-image:
	docker build -t $(DEX_SAMPLE_APP_IMG) .

.PHONY: load-image
load-image: build-image
	ID=$$(docker image inspect --format='{{.ID}}' $(DEX_SAMPLE_APP_IMG)); \
	if [ ! "$$(docker exec -it $(CLUSTER_NAME)-control-plane ctr --namespace=k8s.io images list | grep $$ID)" ]; then \
		$(KIND) load docker-image --name=$(CLUSTER_NAME) $(DEX_SAMPLE_APP_IMG); \
	fi

.PHONY: deploy
deploy: load-image
	$(KUBECTL) apply -f ./manifests/dex-sample-app.yaml

$(KIND):
	mkdir -p $(BIN_DIR)
	cd /tmp; env GOBIN=$(BIN_DIR) GOFLAGS= GO111MODULE=on go get sigs.k8s.io/kind@v$(KIND_VERSION)

$(HELM):
	mkdir -p $(BIN_DIR)
	mkdir -p /tmp/helm-v$(HELM_VERSION)-$(OS)-$(ARCH)/
	curl -sfL https://get.helm.sh/helm-v$(HELM_VERSION)-$(OS)-$(ARCH).tar.gz | tar -xz -C /tmp/helm-v$(HELM_VERSION)-$(OS)-$(ARCH)/
	mv /tmp/helm-v$(HELM_VERSION)-$(OS)-$(ARCH)/$(OS)-$(ARCH)/helm $(BIN_DIR)/
	rm -rf /tmp/helm-v$(HELM_VERSION)-$(OS)-$(ARCH)/

$(KUBECTL):
	mkdir -p $(BIN_DIR)
	curl -sfL https://storage.googleapis.com/kubernetes-release/release/v$(KUBERNETES_VERSION)/bin/$(OS)/$(ARCH)/kubectl -o $(KUBECTL)
	chmod 755 $(KUBECTL)

.PHONY: clean
	rm -rf $(BIN_DIR)
