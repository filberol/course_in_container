# Воркспейс Лаб 2: весь инструментарий + Docker-in-Docker + фронт (code-server).
# Студент поднимает контейнер и выполняет работу внутри, ничего не ставя на хост.
# Требует запуска с --privileged (см. docker-compose.yml) — kind крутит кластер
# во встроенном dockerd, поэтому kubectl достаёт API по 127.0.0.1 без хостовой сети.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV KIND_VERSION=v0.24.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git jq make bats \
        python3 python3-yaml \
        docker.io iptables \
    && rm -rf /var/lib/apt/lists/*

# kubectl (архитектура определяется автоматически: amd64 / arm64)
RUN arch="$(dpkg --print-architecture)"; \
    curl -fsSLo /usr/local/bin/kubectl \
      "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${arch}/kubectl" \
    && chmod +x /usr/local/bin/kubectl

# kind
RUN arch="$(dpkg --print-architecture)"; \
    curl -fsSLo /usr/local/bin/kind \
      "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${arch}" \
    && chmod +x /usr/local/bin/kind

# code-server — веб-фронт (VS Code в браузере)
RUN curl -fsSL https://code-server.dev/install.sh | sh

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /work
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
