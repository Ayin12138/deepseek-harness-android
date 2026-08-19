#!/data/data/com.termux/files/usr/bin/bash
# DeepSeek Harness · 交互式配置（API Key / 模型 / 端口）
# 写入 $DSH_HOME/.credentials.yaml（DSH 自管理密钥库，chmod 600）
# 用法: bash configure.sh
set -euo pipefail

DSH_HOME_DIR="${DSH_HOME:-$HOME/.dsh}"
CRED_FILE="$DSH_HOME_DIR/.credentials.yaml"
mkdir -p "$DSH_HOME_DIR"

# 读取已有密钥（若存在），用于显示与「回车保留」
read_existing_key() {
  [ -f "$CRED_FILE" ] || return 0
  sed -nE 's/^[[:space:]]*DEEPSEEK_API_KEY:[[:space:]]*"?([^"#]+)"?[[:space:]]*$/\1/p' "$CRED_FILE" | head -n1
}
EXISTING_KEY="$(read_existing_key || true)"

echo "════════════════════════════════════════════"
echo " DeepSeek Harness 配置向导"
echo " （直接回车 = 保留当前值 / 使用默认值）"
echo "════════════════════════════════════════════"

hint=""
[ -n "$EXISTING_KEY" ] && hint=" (已配置，回车保留)"
read -r -p "DEEPSEEK_API_KEY${hint}: " api_key
api_key="${api_key//[[:space:]]/}"   # 去空白

# 空输入则保留旧密钥
if [ -z "$api_key" ] && [ -n "$EXISTING_KEY" ]; then
  api_key="$EXISTING_KEY"
  echo "    → 保留已有密钥"
fi

read -r -p "模型 (默认 deepseek-v4-pro，可选 deepseek-v4-flash): " model
model="${model:-deepseek-v4-pro}"

read -r -p "Web 端口 (默认 3080): " port
port="${port:-3080}"

read -r -p "DeepSeek 端点 baseURL (默认 https://api.deepseek.com): " base_url
base_url="${base_url:-https://api.deepseek.com}"

# ── 写密钥库（主配置层）────────────────────────────
{
  echo "# DeepSeek Harness 密钥库（DSH 自管理，请勿提交到版本控制）"
  if [ -n "$api_key" ]; then
    echo "DEEPSEEK_API_KEY: \"$api_key\""
  fi
} > "$CRED_FILE"
chmod 600 "$CRED_FILE"

# ── 写 .env（回退层：端点 / 端口等非敏感项）────────
ENV_FILE="$DSH_HOME_DIR/.env"
touch "$ENV_FILE"; chmod 600 "$ENV_FILE"

upsert_env() { # $1=key $2=value
  local k="$1" v="$2"
  if grep -qE "^[[:space:]]*${k}=" "$ENV_FILE"; then
    sed -i "s|^[[:space:]]*${k}=.*|${k}=${v}|" "$ENV_FILE"
  else
    printf '%s=%s\n' "$k" "$v" >> "$ENV_FILE"
  fi
}
if [ -n "$base_url" ]; then upsert_env "DEEPSEEK_BASE_URL" "$base_url"; fi
upsert_env "DSH_PORT" "$port"

echo
echo "✅ 配置已写入："
echo "   密钥库: $CRED_FILE  (chmod 600)"
echo "   环境:   $ENV_FILE"
echo "   模型:   $model  （首次打开 Web UI 后可在 Settings → Models 里确认/切换）"
echo
echo "   下一步: bash start.sh  →  浏览器打开 http://127.0.0.1:$port"
