FROM docker:17.12.0-ce AS static-docker-source

FROM debian:buster

ENV CLOUD_SDK_VERSION 189.0.0

RUN \
  DEBIAN_FRONTEND=noninteractive \
    apt update && apt install --assume-yes --no-install-recommends \
      apt-transport-https \
      bzip2 \
      ca-certificates \
      curl \
      gettext-base \
      git \
      gnupg \
      golang \
      lsb-release \
      make \
      nmap \
      nmap-common \
      openssh-client \
      parallel \
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
  && curl https://github.com/kubernetes-sigs/kustomize/releases/download/v1.0.8/kustomize_1.0.8_linux_amd64 -Lo /usr/local/bin/kustomize \
  && chmod +x /usr/local/bin/kustomize \
  \
   && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image && \
  ssh-keyscan -H github.com gitlab.com bitbucket.org >> /etc/ssh/ssh_known_hosts && \
  useradd -ms /bin/bash jenkins

RUN cd /opt/ \
      && git clone https://github.com/bats-core/bats-core.git \
      && cd bats-core \
      && git checkout v1.1.0
      && ./install.sh /usr/local

COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker

RUN \
    gcloud --version \
    && docker --version \
    && kubectl version --client
