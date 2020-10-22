#--------------------------#
# Hadolint Pre Test        #
#--------------------------#
FROM hadolint/hadolint:latest-alpine AS hadolint

COPY Dockerfile Dockerfile

RUN hadolint Dockerfile

#--------------------------#
# Docker                   #
#--------------------------#
FROM docker:18.09.2 AS static-docker-source

#--------------------------#
# Golang Builder           #
#--------------------------#

FROM golang:1.15 AS builder

ENV GOPATH /go
RUN go get github.com/OJ/gobuster
WORKDIR /go/src/github.com/OJ/gobuster
RUN make linux

#--------------------------#
# Dependencies             #
#--------------------------#
FROM debian:buster-slim AS dependencies

# Ignore DL3008 as the tools installed in this image do not form part of our final image
# hadolint ignore=DL3008
RUN DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install --assume-yes --no-install-recommends \
    bash                                                                                                  \
    ca-certificates                                                                                       \
    curl

# bash 4 required for `pipefail`
SHELL ["/bin/bash", "-c"]
RUN mkdir /dependencies /downloads
WORKDIR /downloads

# Install doctl (Digital Ocean CLI)
ARG DOCTL_VERSION=1.46.0
# Ignore DL4006 as it has been set for this command and the alert is erroneous
# hadolint ignore=DL4006
RUN set -euxo pipefail; curl -sL "https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz" \
    | tar -xz                                                                                                                                          \
  && mv doctl /dependencies/

# Install github hub
ARG HUB_VERSION=2.6.0
# Ignore DL4006 as it has been set for this command and the alert is erroneous
# hadolint ignore=DL4006
RUN set -euxo pipefail; curl -sL "https://github.com/github/hub/releases/download/v${HUB_VERSION}/hub-linux-amd64-${HUB_VERSION}.tgz" \
  | tar -xz                                                                                                                           \
  && mv ./hub-linux-amd64-*/bin/hub /dependencies/

# Install AWS IAM authenticator for EKS
ARG AWS_AUTHENTICATOR_VERSION="1.17.9/2020-08-04"
RUN curl -sLo /dependencies/aws-iam-authenticator                                                                                 \
    "https://amazon-eks.s3-us-west-2.amazonaws.com/${AWS_AUTHENTICATOR_VERSION}/bin/linux/amd64/aws-iam-authenticator" \
  && chmod +x /dependencies/aws-iam-authenticator

# Install notary
ARG NOTARY_VERSION=0.6.1
RUN curl -sLo /dependencies/notary                                                                         \
    "https://github.com/theupdateframework/notary/releases/download/v${NOTARY_VERSION}/notary-Linux-amd64" \
  && chmod +x /dependencies/notary

# Install docker-compose
ARG DOCKER_COMPOSE_VERSION=1.27.3
RUN curl -sLo /dependencies/docker-compose                                                                                 \
    "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    && chmod +x /dependencies/docker-compose

# Install goss
ARG GOSS_VERSION=0.3.13
RUN curl -sLo /dependencies/goss                                                             \
    "https://github.com/aelsabbahy/goss/releases/download/v${GOSS_VERSION}/goss-linux-amd64" \
  && chmod +x /dependencies/goss

# Install conftest
ARG CONFTEST_VERSION=0.21.0
# Ignore DL4006 as it has been set for this command and the alert is erroneous
# hadolint ignore=DL4006
RUN set -euxo pipefail; curl -sL "https://github.com/instrumenta/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
  | tar -xz                                                                                                                                                        \
  && mv conftest /dependencies/

# Install jq
ARG JQ_VERSION=1.6
RUN curl -sLo /dependencies/jq                                                     \
    "https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64" \
  && chmod +x /dependencies/jq

# Install yq
ARG YQ_VERSION=2.1.1
RUN curl -sLo /dependencies/yq                                                       \
    "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
  && chmod +x /dependencies/yq

# Install kustomize
ARG KUSTOMIZE_VERSION=2.0.2
RUN curl -sLo /dependencies/kustomize                                                                                                 \
    "https://github.com/kubernetes-sigs/kustomize/releases/download/v${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64" \
  && chmod +x /dependencies/kustomize

ARG CLOUD_NUKE_VERSION=v0.1.13
RUN curl -sLo /dependencies/cloud-nuke                                                                        \
  "https://github.com/gruntwork-io/cloud-nuke/releases/download/${CLOUD_NUKE_VERSION}/cloud-nuke_linux_amd64" \
  && chmod +x /dependencies/cloud-nuke

#--------------------------#
# docker-gcloud-sdk        #
#--------------------------#
FROM debian:buster-slim AS docker-gcloud-sdk

# 310.0.0 (2020-09-15)
ENV CLOUD_SDK_VERSION 310.0.0
RUN DEBIAN_FRONTEND=noninteractive apt-get update &&                             \
    apt-get install --assume-yes --no-install-recommends                         \
    apt-transport-https=1.8.2.1                                                  \
    awscli=1.16.113-1                                                            \
    bash=5.0-4                                                                   \
    bzip2=1.0.6-9.2~deb10u1                                                        \
    ca-certificates=20200601~deb10u1                                             \
    curl=7.64.0-4+deb10u1                                                        \
    dnsutils=1:9.11.5.P4+dfsg-5.1+deb10u2                                        \
    gawk=1:4.2.1+dfsg-1                                                          \
    gettext-base=0.19.8.1-9                                                      \
    git=1:2.20.1-2+deb10u3                                                       \
    gnupg=2.2.12-1+deb10u1                                                       \
    golang=2:1.11~1                                                              \
    lsb-release=10.2019051400                                                    \
    lsof=4.91+dfsg-1                                                             \
    make=4.2.1-1.2                                                               \
    ncat=7.70+dfsg1-6+deb10u1                                                    \
    nmap=7.70+dfsg1-6+deb10u1                                                    \
    nmap-common=7.70+dfsg1-6+deb10u1                                             \
    openssh-client=1:7.9p1-10+deb10u2                                            \
    parallel=20161222-1.1                                                        \
    postgresql-client=11+200+deb10u4                                             \
    rsync=3.1.3-6                                                                \
    wget=1.20.1-1.1                                                              \
    xmlstarlet=1.6.1-2                                                           \
                                                                                 \
  && export CLOUD_SDK_REPO                                                       \
  && CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"                             \
  && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
  && bash -euxo pipefail -c "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - " \
                                                                                 \
  && DEBIAN_FRONTEND=noninteractive                                              \
      apt-get update && apt-get install --assume-yes --no-install-recommends     \
        google-cloud-sdk=${CLOUD_SDK_VERSION}-0                                  \
        kubectl=1.19.3-00                                                        \
                                                                                 \
  && rm -rf /var/lib/apt/lists/*                                                 \
                                                                                 \
                                                                                    \
  && gcloud config set core/disable_usage_reporting true                            \
  && gcloud config set component_manager/disable_update_check true                  \
  && gcloud config set metrics/environment github_docker_image                      \
  && ssh-keyscan -H github.com gitlab.com bitbucket.org >> /etc/ssh/ssh_known_hosts \
  && useradd -u 1000 -ms /bin/bash jenkins

# Install bats-core
ARG BATS_SHA=18f574c0deaa3f0299fa7aa1120c61f9fb430ad8
# hadolint ignore=DL3003
RUN cd /opt/                                               \
  && git clone https://github.com/bats-core/bats-core.git  \
  && cd bats-core/                                         \
  && git checkout ${BATS_SHA}                              \
  && ./install.sh /usr/local

# Copy binaries from dependencies
COPY --from=dependencies /dependencies/* /usr/local/bin/

# Copy docker
COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker

# Copy built gobuster
COPY --from=builder /go/src/github.com/OJ/gobuster/build/gobuster-linux-amd64/gobuster /usr/local/bin/

# Print versions of all installed tools
RUN gcloud --version                \
    && docker --version             \
    && kubectl version --client     \
    && bats --version               \
    && doctl version                \
    && hub --version                \
    && aws-iam-authenticator --help \
    && notary help                  \
    && docker-compose version       \
    && goss help                    \
    && conftest --version           \
    && jq --version                 \
    && yq --version                 \
    && kustomize version            \
    && cloud-nuke --version

