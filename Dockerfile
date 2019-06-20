FROM docker:18.09.2 AS static-docker-source

FROM golang:1.12 AS builder

RUN env | grep GO

RUN go get github.com/evilsocket/dirsearch \
  && cd src/github.com/evilsocket/dirsearch && ls -lasp \
  && make get_glide \
  && make install_dependencies \
  && make build \
  && pwd && ls -lasp build/linux_x64/dirsearch

# ---
FROM debian:buster

ENV CLOUD_SDK_VERSION 189.0.0

RUN \
  DEBIAN_FRONTEND=noninteractive \
    apt update && apt install --assume-yes --no-install-recommends \
      apt-transport-https \
      awscli \
      bzip2 \
      ca-certificates \
      curl \
      dnsutils \
      gawk \
      gettext-base \
      git \
      gnupg \
      golang \
      lsb-release \
      lsof \
      make \
      nmap \
      nmap-common \
      ncat \
      openssh-client \
      parallel \
      postgresql-client \
      rsync \
      wget \
      xmlstarlet \
  \
  && export CLOUD_SDK_REPO \
  && CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
  && echo "deb https://packages.cloud.google.com/apt $CLOUD_SDK_REPO main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
  && bash -euxo pipefail -c "curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - " \
  \
  && DEBIAN_FRONTEND=noninteractive \
       apt update && apt install --assume-yes --no-install-recommends \
         google-cloud-sdk=${CLOUD_SDK_VERSION}-0 \
         kubectl \
  \
  && rm -rf /var/lib/apt/lists/* \
  \
  && curl https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64 -Lo /usr/local/bin/jq \
  && chmod +x /usr/local/bin/jq \
  \
  && curl https://github.com/mikefarah/yq/releases/download/2.1.1/yq_linux_amd64 -Lo /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq \
  \
  && curl https://github.com/kubernetes-sigs/kustomize/releases/download/v2.0.2/kustomize_2.0.2_linux_amd64 -Lo /usr/local/bin/kustomize \
  && chmod +x /usr/local/bin/kustomize \
  \
   && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image && \
  ssh-keyscan -H github.com gitlab.com bitbucket.org >> /etc/ssh/ssh_known_hosts && \
  useradd -ms /bin/bash jenkins

# bats-core
RUN cd /opt/ \
  && git clone https://github.com/bats-core/bats-core.git \
  && cd bats-core/ \
  && git checkout 8789f910812afbf6b87dd371ee5ae30592f1423f \
  && ./install.sh /usr/local

# doctl (Digital Ocean CLI)
RUN cd $(mktemp -d) \
  && curl -sL https://github.com/digitalocean/doctl/releases/download/v1.13.0/doctl-1.13.0-linux-amd64.tar.gz \
    | tar -xzv \
  && mv doctl /usr/local/bin/ \
  && doctl version

SHELL ["/bin/bash", "-c"]
# github hub (git subcmomand for PR workflows)
RUN set -euxo pipefail; cd /opt/ \
  && curl -L https://github.com/github/hub/releases/download/v2.6.0/hub-linux-amd64-2.6.0.tgz \
  | tar xzvf - \
  && ./hub-linux-amd64-*/install \
  && hub --version

# AWS IAM authenticator for EKS
RUN curl -o /usr/local/bin/aws-iam-authenticator \
    https://amazon-eks.s3-us-west-2.amazonaws.com/1.11.5/2018-12-06/bin/linux/amd64/aws-iam-authenticator \
  && chmod +x /usr/local/bin/aws-iam-authenticator \
  && aws-iam-authenticator help

# notary
RUN curl -Lo /usr/local/bin/notary \
    https://github.com/theupdateframework/notary/releases/download/v0.6.1/notary-Linux-amd64 \
  && chmod +x /usr/local/bin/notary \
  && notary help

# docker-compose
RUN curl -L "https://github.com/docker/compose/releases/download/1.24.0/docker-compose-$(uname -s)-$(uname -m)" \
      -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose \
    && docker-compose version

# goss
RUN curl -Lo /usr/local/bin/goss \
    https://github.com/aelsabbahy/goss/releases/download/v0.3.7/goss-linux-amd64 \
  && chmod +x /usr/local/bin/goss \
  && goss help

# conftest
RUN wget https://github.com/instrumenta/conftest/releases/download/v0.4.2/conftest_0.4.2_Linux_x86_64.tar.gz \
  && tar xzf conftest_0.4.2_Linux_x86_64.tar.gz \
  && mv conftest /usr/local/bin \
  && conftest --version

COPY --from=builder /go/src/github.com/evilsocket/dirsearch/build/linux_x64/dirsearch /usr/local/bin/dirsearch
COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker

RUN \
    gcloud --version \
    && docker --version \
    && kubectl version --client
