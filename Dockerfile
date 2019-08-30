#--------------------------#
# Docker                   #
#--------------------------#
FROM docker:18.09.2 AS static-docker-source

#--------------------------#
# Golang Builder           #
#--------------------------#

FROM golang:1.12 AS builder

ENV GOPATH /go
RUN go get github.com/OJ/gobuster
WORKDIR /go/src/github.com/OJ/gobuster
RUN make linux

#--------------------------#
# Dependencies             #
#--------------------------#
FROM debian:buster-slim AS dependencies

RUN apt-get update                                                               \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash                                                                         \
    ca-certificates                                                              \
    curl                                                                         \
    git                                                                          \
    unzip                                                                        \
    wget

# bash 4 required for `pipefail`
SHELL ["/bin/bash", "-c"]
RUN mkdir /dependencies /downloads
WORKDIR /downloads

# Install doctl (Digital Ocean CLI)
ARG DOCTL_VERSION=1.13.0
RUN cd $(mktemp -d)           \
  && curl -sL https://github.com/digitalocean/doctl/releases/download/v${DOCTL_VERSION}/doctl-${DOCTL_VERSION}-linux-amd64.tar.gz \
    | tar -xzv                \
  && mv doctl /dependencies/

# Install github hub
ARG HUB_VERSION=2.6.0
RUN set -euxo pipefail; cd /opt/ \
  && curl -L https://github.com/github/hub/releases/download/v${HUB_VERSION}/hub-linux-amd64-${HUB_VERSION}.tgz \
  | tar xzvf -                   \
  && mv ./hub-linux-amd64-*/bin/hub /dependencies/

# Install AWS IAM authenticator for EKS
ARG AWS_AUTHENTICATOR_VERSION=1.11.5
RUN curl -o /dependencies/aws-iam-authenticator   \
    https://amazon-eks.s3-us-west-2.amazonaws.com/${AWS_AUTHENTICATOR_VERSION}/2018-12-06/bin/linux/amd64/aws-iam-authenticator \
  && chmod +x /dependencies/aws-iam-authenticator

# Install notary
ARG NOTARY_VERSION=0.6.1
RUN curl -Lo /dependencies/notary                                                           \
    https://github.com/theupdateframework/notary/releases/download/v${NOTARY_VERSION}/notary-Linux-amd64 \
  && chmod +x /dependencies/notary

# Install docker-compose
ARG DOCKER_COMPOSE_VERSION=1.24.0
RUN curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
      -o /dependencies/docker-compose        \
    && chmod +x /dependencies/docker-compose

# Install goss
ARG GOSS_VERSION=0.3.7
RUN curl -Lo /dependencies/goss                                                 \
    https://github.com/aelsabbahy/goss/releases/download/v${GOSS_VERSION}/goss-linux-amd64 \
  && chmod +x /dependencies/goss

# Install conftest
ARG CONFTEST_VERSION=0.4.2
RUN wget https://github.com/instrumenta/conftest/releases/download/v0.4.2/conftest_0.4.2_Linux_x86_64.tar.gz \
  && tar xzf conftest_0.4.2_Linux_x86_64.tar.gz \
  && mv conftest /dependencies/

#--------------------------#
# docker-gcloud-sdk        #
#--------------------------#
FROM debian:buster AS docker-gcloud-sdk

ENV CLOUD_SDK_VERSION 189.0.0

RUN apt-get update                                                               \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      apt-transport-https                                                        \
      awscli                                                                     \
      bzip2                                                                      \
      ca-certificates                                                            \
      curl                                                                       \
      dnsutils                                                                   \
      gawk                                                                       \
      gettext-base                                                               \
      git                                                                        \
      gnupg                                                                      \
      golang                                                                     \
      lsb-release                                                                \
      lsof                                                                       \
      make                                                                       \
      nmap                                                                       \
      nmap-common                                                                \
      ncat                                                                       \
      openssh-client                                                             \
      parallel                                                                   \
      postgresql-client                                                          \
      rsync                                                                      \
      wget                                                                       \
      xmlstarlet                                                                 \
                                                                                 \
  && export CLOUD_SDK_REPO                                                       \
  && CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)"                             \
  && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
  && bash -euxo pipefail -c "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - " \
                                                                                 \
  && DEBIAN_FRONTEND=noninteractive                                              \
       apt update && apt install --assume-yes --no-install-recommends            \
         google-cloud-sdk=${CLOUD_SDK_VERSION}-0                                 \
         kubectl                                                                 \
                                                                                 \
  && rm -rf /var/lib/apt/lists/*                                                 \
                                                                                 \
  && curl https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -Lo /usr/local/bin/jq                                                                                  \
  && chmod +x /usr/local/bin/jq                                                  \
                                                                                 \
  && curl https://github.com/mikefarah/yq/releases/download/2.1.1/yq_linux_amd64 -Lo /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq                                                  \
                                                                                 \
  && curl https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.2/kustomize_2.0.2_linux_amd64 -Lo /usr/local/bin/kustomize  \
  && chmod +x /usr/local/bin/kustomize                                              \
                                                                                    \
  && gcloud config set core/disable_usage_reporting true                            \
  && gcloud config set component_manager/disable_update_check true                  \
  && gcloud config set metrics/environment github_docker_image                      \
  && ssh-keyscan -H github.com gitlab.com bitbucket.org >> /etc/ssh/ssh_known_hosts \
  && useradd -u 1000 -ms /bin/bash jenkins

# Install bats-core
ARG BATS_SHA=8789f910812afbf6b87dd371ee5ae30592f1423f
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
    && conftest --version

