# 108_霄鸟云 · 生产部署（宝塔 · 单域名）

> **域名**：`xiaoniaoyun.dowima.com`（仅此一个）  
> **服务器**：108 · 内网 `192.168.1.184` · SSH `59.57.32.193:50025`  
> **宝塔**：`http://bt108.estar.plus/5edd0dbe` · 内网 `http://192.168.1.184:11160/5edd0dbe`

## 路径规划

| 路径 | 端 |
|------|-----|
| `/` | 用户端（buyer） |
| `/merchant/` | 商家端 |
| `/admin/` | 管理端 |
| `/api/` | PHP API |

## 服务器目录

```
/www/wwwroot/xiaoniaoyun.dowima.com/
  index.html          # 用户端静态
  assets/
  merchant/           # 商家端 dist
  admin/              # 管理端 dist
  backend/            # PHP API + .env
```

Nginx 扩展路由：`/www/server/panel/vhost/nginx/extension/xiaoniaoyun.dowima.com/108_xiaoniaoyun_routes.conf`

## 本地打包上传

```bash
bash scripts/pack-baota-prod.sh
# 生成 108_xiaoniaoyun-baota-prod.tar.gz
# 上传至服务器 /root/ 解压后 rsync 到 wwwroot
```

## 测试账号（万能验证码 123456，生产暂开 ALLOW_UNIVERSAL_CODE）

| 端 | 手机号 |
|----|--------|
| 用户端 | 18888888888 |
| 商家端 | 13900000001 |
| 管理端 | 13800000000 |

## 凭证

服务器本地：`/root/.108_xny_prod.env`（chmod 600，勿提交 Git）

## 待收尾

1. DNS `xiaoniaoyun.dowima.com` → 公网 IP
2. 路由器/安全组 **80/443** 转发至 `192.168.1.184`
3. 宝塔申请 HTTPS 证书
4. 上线前关闭 `ALLOW_UNIVERSAL_CODE`，配置真实短信/OSS
