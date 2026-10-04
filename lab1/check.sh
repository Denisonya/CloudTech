#!/bin/bash


echo "Проверка редиректа HTTP -> HTTPS:"
curl -I http://notes.local/


echo "Проверка работы сайта по HTTPS:"
curl -sk -I https://notes.local/


echo "Проверка балансировки между двумя инстансами backend:"
for i in {1..6}
do
  curl -sk -i https://notes.local/api/notes | grep "backend-instance"
  sleep 1
done


echo "Проверка доступа к /admin без авторизации:"
curl -sk -I https://notes.local/admin/


echo "Проверка ограничения количества запросов к /api:"
for i in {1..6}
do
  curl -sk -I https://notes.local/api/notes &
done

wait


echo "Проверка виртуального хоста notes.local:"
curl -sk https://notes.local/ | grep "<title>"


echo "Проверка виртуального хоста site2.local:"
curl -sk https://site2.local/ | grep "<title>"


echo "Проверка неизвестного домена:"
curl -sk -i -H "Host: unknown.local" https://127.0.0.1/ | grep "HTTP/"


echo "Проверка собственной страницы 404:"
curl -sk -i https://notes.local/not-existing-page | grep "Ошибка 404"


echo "Проверка отказоустойчивости при падении одного инстанса backend:"
pkill -f "uvicorn.*--port 8001"
sleep 1

for i in {1..6}
do
  curl -sk -i https://notes.local/api/notes | grep "backend-instance"
  sleep 1
done