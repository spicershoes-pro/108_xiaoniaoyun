# 霄鸟云 · Makefile 快捷命令
# 使用：make <target>

.PHONY: dev test staging check-env reset-db gen-secret install build

## 环境切换
dev:
	@bash scripts/switch-env.sh development

test:
	@bash scripts/switch-env.sh testing

staging:
	@bash scripts/switch-env.sh staging

production:
	@bash scripts/switch-env.sh production

## 环境检查
check-env:
	@bash scripts/check-env.sh

## 数据库
reset-db:
	@bash scripts/reset-db.sh

reset-db-seed:
	@bash scripts/reset-db.sh --seed

## 密钥生成
gen-secret:
	@bash scripts/gen-jwt-secret.sh

## 前端安装
install:
	cd frontend/buyer    && npm install
	cd frontend/merchant && npm install
	cd frontend/admin    && npm install

## 前端构建（生产）
build:
	cd frontend/buyer    && npm run build
	cd frontend/merchant && npm run build
	cd frontend/admin    && npm run build

## 启动开发服务器（需先切换开发环境）
start-backend:
	cd backend && php -S localhost:8080 -t public

start-buyer:
	cd frontend/buyer && npm run dev

start-merchant:
	cd frontend/merchant && npm run dev

start-admin:
	cd frontend/admin && npm run dev

## Docker 操作
docker-build:
	bash docker/scripts/build.sh dev

docker-build-prod:
	bash docker/scripts/build.sh prod

docker-up:
	docker compose up -d

docker-down:
	docker compose down

docker-down-v:
	docker compose down -v

docker-logs:
	docker compose logs -f

docker-ps:
	docker compose ps

docker-restart:
	docker compose restart

docker-shell-backend:
	docker compose exec backend sh

docker-shell-db:
	docker compose exec db mysql -u root -p

docker-migrate:
	docker compose exec backend sh -c "mysql -h db -u $$DB_USER -p$$DB_PASS $$DB_NAME < /var/www/html/database/schema.sql"

docker-seed:
	docker compose exec backend sh -c "mysql -h db -u $$DB_USER -p$$DB_PASS $$DB_NAME < /var/www/html/database/seed.sql"

docker-prune:
	docker system prune -f

## 运维操作
backup:
	bash deploy/ops/backup-full.sh

backup-oss:
	bash deploy/ops/backup-full.sh --upload-oss

restore-db:
	bash deploy/ops/restore.sh db

monitor:
	bash deploy/ops/monitor.sh

inspect:
	bash deploy/ops/inspect.sh weekly

inspect-monthly:
	bash deploy/ops/inspect.sh monthly

security-scan:
	bash deploy/ops/security-scan.sh

release:
	bash deploy/ops/release.sh deploy latest

rollback:
	bash deploy/ops/release.sh rollback
