FROM docker:17.12.0-ce as static-docker-source

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
      openssh-client \
      parallel \
      wget \
  \
  && export CLOUD_SDK_REPO="cloud-sdk-$(lsb_release -c -s)" \
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
   && \
  gcloud config set core/disable_usage_reporting true && \
  gcloud config set component_manager/disable_update_check true && \
  gcloud config set metrics/environment github_docker_image

COPY --from=static-docker-source /usr/local/bin/docker /usr/local/bin/docker

RUN \
    gcloud --version \
    && docker --version \
    && kubectl version --client
