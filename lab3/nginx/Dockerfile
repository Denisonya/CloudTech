# Актуальный стабильный NGINX на Alpine, закрепленный по digest.
FROM nginx:1.30.6-alpine@sha256:0e52bd054126cdc040b1276c0af347aeb02a41b9cfe305d6094767ac30e97949

# Обновляем системные пакеты и убираем стандартный конфиг.
RUN apk upgrade --no-cache \
    && rm /etc/nginx/conf.d/default.conf

COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY frontend/ /usr/share/nginx/html/
EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fs http://127.0.0.1/healthz
