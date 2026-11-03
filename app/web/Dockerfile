# syntax=docker/dockerfile:1
# Imagen del frontend de tablero. Multi-stage: Node y pnpm solo existen en la etapa de build.
# Construir desde app/:  docker build -t tablero-web:dev web

FROM node:26.13.0-trixie-slim AS build
# pnpm autónomo con checksum fijado: sin npm, sin corepack (ya no viene con Node 26) y sin
# curl | bash. ADD --checksum falla el build si el archivo no es el esperado.
ADD --checksum=sha256:565ff81174a14f6f7bd5d84c1b17e51031a80230d370a1fe24be5d16bd02a825 \
    https://github.com/pnpm/pnpm/releases/download/v12.16.1/pnpm-linux-x64.tar.gz /tmp/pnpm.tar.gz
RUN mkdir -p /opt/pnpm && tar -xzf /tmp/pnpm.tar.gz -C /opt/pnpm && ln -s /opt/pnpm/pnpm /usr/local/bin/pnpm
WORKDIR /app
# Primero solo el lockfile: esta capa se reutiliza mientras pnpm-lock.yaml no cambie.
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile
COPY . .
RUN pnpm build

FROM nginxinc/nginx-unprivileged:1.31.7-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
