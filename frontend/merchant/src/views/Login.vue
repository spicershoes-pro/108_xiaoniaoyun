<template>
  <div class="login-page">
    <div class="login-card">
      <div class="login-logo">
        <span>🐦</span>
        <div>
          <div class="app-name">霄鸟云</div>
          <div class="app-tag">商家管理后台</div>
        </div>
      </div>

      <h2 class="login-title">商家登录</h2>

      <div class="form-group">
        <label class="form-label">手机号</label>
        <input v-model="phone" class="form-input" placeholder="请输入商家手机号" maxlength="11" />
      </div>

      <div class="form-group">
        <label class="form-label">验证码</label>
        <div style="display:flex;gap:8px;">
          <input v-model="code" class="form-input" placeholder="6位验证码" maxlength="6" style="letter-spacing:4px;font-weight:700;" />
          <button class="btn btn-outline btn-sm" :disabled="cd>0" @click="sendCode">
            {{ cd > 0 ? `${cd}s` : '获取验证码' }}
          </button>
        </div>
      </div>

      <div v-if="err" class="alert alert-danger" style="font-size:13px;">{{ err }}</div>

      <button class="btn btn-primary btn-full btn-lg" :disabled="loading" @click="doLogin">
        {{ loading ? '登录中…' : '登录' }}
      </button>

      <div class="dev-hint">
        🧪 商家账号：13900000001 / 13900000002 · 验证码 123456
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { authApi } from '@/api'

const router = useRouter()
const auth   = useAuthStore()
const phone  = ref('13900000001')
const code   = ref('123456')
const loading= ref(false)
const err    = ref('')
const cd     = ref(0)

async function sendCode() {
  if (!phone.value || phone.value.length !== 11) {
    err.value = '请输入正确的手机号'
    return
  }
  err.value = ''
  const res = await authApi.sendCode(phone.value)
  if (res.code !== 0) {
    err.value = res.msg || '发送失败'
    return
  }
  cd.value = 60
  const iv = setInterval(() => { if (--cd.value <= 0) clearInterval(iv) }, 1000)
}

async function doLogin() {
  err.value = ''; loading.value = true
  const res = await auth.login(phone.value, code.value)
  loading.value = false
  if (res.ok) router.push('/')
  else err.value = res.msg
}
</script>

<style scoped>
.login-page { min-height:100vh; display:flex; align-items:center; justify-content:center; background:linear-gradient(160deg,#0a0f1e 0%,#1a2340 50%,var(--bg0) 50%); padding:20px; }
.login-card { background:#fff; border-radius:20px; padding:36px 32px; width:100%; max-width:400px; box-shadow:0 20px 60px rgba(0,0,0,.2); }
.login-logo { display:flex; align-items:center; gap:12px; margin-bottom:28px; }
.login-logo > span { font-size:40px; }
.app-name { font-size:22px; font-weight:800; color:var(--t1); }
.app-tag  { font-size:12px; color:var(--blue); font-weight:600; }
.login-title { font-size:16px; font-weight:700; margin-bottom:20px; }
.dev-hint { text-align:center; font-size:12px; color:var(--orange); background:var(--orange-l); border-radius:var(--r8); padding:8px; margin-top:14px; }
</style>
