#!/bin/sh
# cloud-init user-data for CirrOS: serve a tiny HTTP page on port 80 so the
# security-group and floating-IP labs have something to test against.
cat > /tmp/web.sh <<'EOS'
#!/bin/sh
while true; do
  printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello from %s (OpenStack lab)\n' "$(hostname)" | nc -l -p 80
done
EOS
chmod +x /tmp/web.sh
nohup /tmp/web.sh >/dev/null 2>&1 &
