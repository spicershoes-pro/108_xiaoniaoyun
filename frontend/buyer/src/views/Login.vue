<template>
  <div class="login-page">
    <div class="login-card">
      <div class="login-logo">
        <span>🐦</span>
        <div>
          <div class="app-name">霄鸟云</div>
          <div class="app-tag">跨境玩具选品 · 供应链协作平台</div>
        </div>
      </div>

      <h2 class="login-title">手机号登录 / 注册</h2>

      <div class="form-group">
        <label class="form-label">手机号</label>
        <div class="phone-wrap">
          <span class="country-code">🇨🇳 +86</span>
          <input v-model="phone" class="form-input" placeholder="请输入手机号"
                 maxlength="11" inputmode="numeric" />
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">验证码</label>
        <div class="code-wrap">
          <input v-model="code" class="form-input" placeholder="6位验证码"
                 maxlength="6" inputmode="numeric" style="letter-spacing:4px;font-weight:700;" />
          <button class="btn btn-outline btn-sm" :disabled="cdLeft > 0 || sending"
                  @click="sendCode">
            {{ cdLeft > 0 ? `${cdLeft}s` : sent ? '重新发送' : '获取验证码' }}
          </button>
        </div>
      </div>

      <div v-if="errMsg" class="login-err">{{ errMsg }}</div>

      <button class="btn btn-primary btn-full btn-lg" :disabled="loading || !phone || !code"
              @click="doLogin">
        <span v-if="loading">登录中…</span>
        <span v-else>登录 / 注册</span>
      </button>

      <div class="login-hint">
        登录即代表同意《用户协议》及《隐私政策》
      </div>

      <div class="dev-hint">
        🧪 开发测试：任意手机号 + 验证码 <b>123456</b>
      </div>

      <div class="quick-btns">
        <button class="btn btn-ghost" @click="quickFill('18888888888')">
          👤 买家测试账号
        </button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore }  from '@/stores/auth'
import { useCartStore }  from '@/stores/cart'
import { authApi } from '@/api'

const router = useRouter()
const auth   = useAuthStore()
const cart   = useCartStore()

const phone   = ref('')
const code    = ref('')
const loading = ref(false)
const sending = ref(false)
const sent    = ref(false)
const cdLeft  = ref(0)
const errMsg  = ref('')

async function sendCode() {
  if (!phone.value || phone.value.length !== 11) {
    errMsg.value = '请输入正确的手机号'; return
  }
  sending.value = true
  errMsg.value = ''
  try {
    const res = await authApi.sendCode(phone.value)
    if (res.code !== 0) {
      errMsg.value = res.msg || '发送失败'
      return
    }
    sent.value = true
    cdLeft.value = 60
    const iv = setInterval(() => {
      cdLeft.value--
      if (cdLeft.value <= 0) clearInterval(iv)
    }, 1000)
  } catch (e) {
    errMsg.value = e.message
  } finally {
    sending.value = false
  }
}

async function doLogin() {
  if (!phone.value || !code.value) return
  loading.value = true
  const res = await auth.login(phone.value, code.value)
  loading.value = false
  if (res.ok) {
    await cart.fetch()
    router.push('/')
  } else {
    errMsg.value = res.msg
  }
}

function quickFill(p) { phone.value = p; code.value = '123456' }
</script>

<style scoped>
.login-page {
  min-height: 100vh; display: flex; align-items: center; justify-content: center;
  background: linear-gradient(160deg, #1677FF 0%, #0958D9 40%, var(--bg0) 40%);
  padding: 20px;
}
.login-card {
  background: #fff; border-radius: 20px; padding: 36px 32px;
  width: 100%; max-width: 420px; box-shadow: 0 20px 60px rgba(0,0,0,.15);
}
.login-logo {
  display: flex; align-items: center; gap: 12px; margin-bottom: 28px;
}
.login-logo > span { font-size: 40px; }
.app-name { font-size: 24px; font-weight: 800; color: var(--t1); }
.app-tag  { font-size: 12px; color: var(--t4); margin-top: 2px; }
.login-title { font-size: 16px; font-weight: 700; color: var(--t1); margin-bottom: 20px; }

.phone-wrap { display: flex; gap: 8px; align-items: center; border: 1.5px solid var(--border); border-radius: var(--r8); padding: 2px 12px 2px 2px; transition: border-color .15s; }
.phone-wrap:focus-within { border-color: var(--blue); }
.phone-wrap .form-input { border: none; padding-left: 8px; }
.country-code { font-size: 13px; color: var(--t3); white-space: nowrap; padding: 0 8px; }
.code-wrap { display: flex; gap: 8px; }
.code-wrap .form-input { flex: 1; }

.login-err  { background: var(--red-l,#fff1f0); color: var(--red,#cf1322); border-radius: var(--r8); padding: 8px 12px; font-size: 13px; margin-bottom: 12px; }
.login-hint { text-align: center; font-size: 11px; color: var(--t4); margin-top: 14px; }
.dev-hint   { text-align: center; font-size: 12px; color: var(--orange); background: var(--orange-l); border-radius: var(--r8); padding: 8px; margin-top: 12px; }
.quick-btns { display: flex; gap: 8px; margin-top: 12px; }
.quick-btns .btn { flex: 1; justify-content: center; }
</style>
