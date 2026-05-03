# Auto Cert

基于 `debian:trixie`、Certbot 和 Cloudflare DNS 插件的通配符证书自动签发工具。适合通过 Docker Compose 自动申请和续期 Let's Encrypt 免费证书，并把证书、日志挂载到宿主机目录，方便给 Nginx、Caddy 或其他服务使用。

## 特性

- 使用 DNS-01 验证签发 `*.example.com` 通配符证书
- 支持 Cloudflare API Token 和 Global API Key
- 使用 cron 每天检查证书并自动续期
- 证书输出到 `./certs`
- 日志输出到 `./logs`
- Certbot 状态持久化到 `./letsencrypt`
- 镜像基于 `debian:trixie`

## 使用

1. 复制环境变量模板：

   ```sh
   cp .env.example .env
   ```

2. 修改 `.env`：

   ```env
   DOMAIN=example.com
   EMAIL=admin@example.com
   CLOUDFLARE_API_TOKEN=你的 Cloudflare API Token
   STAGING=true
   ```

   `DOMAIN` 是必须配置的主域名。默认会申请 `example.com` 和 `*.example.com`。

   Cloudflare Token 至少需要目标 Zone 的 `Zone:DNS:Edit` 权限。

   如果你要用 Cloudflare Global API Key，改成：

   ```env
   CLOUDFLARE_API_TOKEN=
   CLOUDFLARE_EMAIL=you@example.com
   CLOUDFLARE_API_KEY=你的 Global API Key
   ```

3. 先用 Let's Encrypt staging 环境验证：

   ```sh
   docker compose up --build
   ```

4. 成功后把 `.env` 中的 `STAGING=false`，重新运行：

   ```sh
   docker compose up -d --build
   ```

也可以单独构建镜像：

```sh
./build.sh
```

## 定时检查

容器内使用 `supercronic` 执行定时任务，默认每天 03:17 检查一次：

```env
CERT_CRON=17 3 * * *
```

检查时会先读取当前证书过期时间。默认剩余 30 天以内强制续期，不会等证书过期才更换：

```env
RENEW_BEFORE_DAYS=30
```

想更早续期可以改成 `45` 或 `60`。不建议设置太大，否则可能更容易碰到 Let's Encrypt 频率限制。

## 单次执行

只检查/签发一次，执行完容器退出：

```sh
docker compose run --rm -e RUN_ONCE=true certbot-cloudflare
```

也可以用命令形式：

```sh
docker compose run --rm certbot-cloudflare run-once
```

证书会额外挂载输出到：

```text
./certs/example.com/fullchain.pem
./certs/example.com/privkey.pem
./certs/example.com/chain.pem
./certs/example.com/cert.pem
```

Certbot 原始目录也会保留在：

```text
./letsencrypt/live/example.com/fullchain.pem
./letsencrypt/live/example.com/privkey.pem
```

日志会挂载输出到：

```text
./logs/auto-cert.log
./logs/letsencrypt/letsencrypt.log
```

默认会申请 `*.example.com` 和 `example.com` 两个 SAN。需要自定义域名列表时可设置：

```env
CERTBOT_DOMAINS=*.example.com,example.com,*.api.example.com
```
