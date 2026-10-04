FROM nginx:1.27.4-alpine

# Удаляем дефолтный конфиг NGINX (у нас свой)
RUN rm /etc/nginx/conf.d/default.conf

# Копируем собственный конфиг NGINX и переносим Frontend
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf
COPY frontend/ /usr/share/nginx/html/

EXPOSE 80

# Проверяем, что frontend отвечает
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -fs http://127.0.0.1/healthz