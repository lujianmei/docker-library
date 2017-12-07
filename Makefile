
.PHONY: build-all help release-all

# Use bash for inline if-statements in test target
SHELL:=bash

OWNER:=lujianmei
# need to list these manually because there's a dependency tree
ARCH:=$(shell uname -m)

ifeq ($(ARCH),ppc64le)
ALL_STACKS:=hyperkube \
		        k8s-dns-dnsmasq-nanny-amd64 \
					  k8s-dns-sidecar-amd64 \
						k8s-dns-kube-dns-amd64 \
						kubernetes-dashboard-amd64
else
ALL_STACKS:=hyperkube \
		        k8s-dns-dnsmasq-nanny-amd64 \
					  k8s-dns-sidecar-amd64 \
						k8s-dns-kube-dns-amd64 \
						kubernetes-dashboard-amd64

endif

ALL_IMAGES:=$(ALL_STACKS)

GIT_MASTER_HEAD_SHA:=$(shell git rev-parse --short=12 --verify HEAD)
#GIT_MASTER_HEAD_SHA:=$(shell git rev-parse HEAD)

RETRIES:=10

arch_patch/%: ## apply hardware architecture specific patches to the Dockerfile
	if [ -e ./$(notdir $@)/Dockerfile.$(ARCH).patch ]; then \
		if [ -e ./$(notdir $@)/Dockerfile.orig ]; then \
				cp -f ./$(notdir $@)/Dockerfile.orig ./$(notdir $@)/Dockerfile;\
		else\
				cp -f ./$(notdir $@)/Dockerfile ./$(notdir $@)/Dockerfile.orig;\
		fi;\
		patch -f ./$(notdir $@)/Dockerfile ./$(notdir $@)/Dockerfile.$(ARCH).patch; \
	fi

build/%: DARGS?=
build/%: ## build the latest image for a stack
	docker build $(DARGS) --rm --force-rm -t $(OWNER)/$(notdir $@):latest ./$(notdir $@)

build-all: $(foreach I,$(ALL_IMAGES),arch_patch/$(I) build/$(I) ) ## build all stacks
build-test-all: $(foreach I,$(ALL_IMAGES),arch_patch/$(I) build/$(I) test/$(I) ) ## build and test all stacks

dev/%: ARGS?=
dev/%: DARGS?=
dev/%: PORT?=8888
dev/%: ## run a foreground container for a stack
	docker run -it --rm -p $(PORT):8888 $(DARGS) $(OWNER)/$(notdir $@) $(ARGS)

push/%: ## push the latest and HEAD git SHA tags for a stack to Docker Hub
	docker login -u=$(DOCKER_NAME) -p=$(DOCKER_PASSWORD)
	docker push $(OWNER)/$(notdir $@):latest
	#docker push $(OWNER)/$(notdir $@):$(GIT_MASTER_HEAD_SHA)

push-all: $(ALL_IMAGES:%=push/%) ## push all stacks

refresh/%: ## pull the latest image from Docker Hub for a stack
# skip if error: a stack might not be on dockerhub yet
	-docker pull $(OWNER)/$(notdir $@):latest

refresh-all: $(ALL_IMAGES:%=refresh/%) ## refresh all stacks

release-all: build-all \
						 push-all
release-all: ## build, test, tag, and push all stacks

# retry/%:
# 	@for i in $$(seq 1 $(RETRIES)); do \
# 		make $(notdir $@) ; \
# 		if [[ $$? == 0 ]]; then exit 0; fi; \
# 		echo "Sleeping for $$((i * 60))s before retry" ; \
# 		sleep $$((i * 60)) ; \
# 	done ; exit 1

# tag/%: ##tag the latest stack image with the HEAD git SHA
# 	#docker tag -f $(OWNER)/$(notdir $@):latest $(OWNER)/$(notdir $@):$(GIT_MASTER_HEAD_SHA)
# 	docker tag $(OWNER)/$(notdir $@):$(GIT_MASTER_HEAD_SHA) $(OWNER)/$(notdir $@):latest

# tag-all: $(ALL_IMAGES:%=tag/%) ## tag all stacks

# test/%: ## run a stack container, check for jupyter server liveliness
# 	@-docker rm -f container-test
# 	@docker run -d --name container-test $(OWNER)/$(notdir $@)
# 	@for i in $$(seq 0 9); do \
# 		sleep $$i; \
# 		docker exec container-test bash -c 'wget http://localhost:8888 -O- | grep -i jupyter'; \
# 		if [[ $$? == 0 ]]; then exit 0; fi; \
# 	done ; exit 1

# test-all: $(ALL_IMAGES:%=test/%) ## test all stacks
