// merchant/src/stores/auth.js
import { defineStore } from 'pinia'
import { authApi } from '@/api'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user:  JSON.parse(localStorage.getItem('m_user') || 'null'),
    token: localStorage.getItem('m_token') || '',
  }),
  getters: {
    isLoggedIn: s => !!s.token && !!s.user,
    isMerchant: s => s.user?.role === 'merchant',
    merchantId: s => s.user?.merchant_profile?.id,
    name:       s => s.user?.merchant_profile?.short_name || s.user?.name || '',
  },
  actions: {
    async login(phone, code) {
      const res = await authApi.login(phone, code)
      if (res.code === 0 && res.data.user.role === 'merchant') {
        this.token = res.data.token
        this.user  = res.data.user
        localStorage.setItem('m_token', res.data.token)
        localStorage.setItem('m_user', JSON.stringify(res.data.user))
        return { ok: true }
      }
      return { ok: false, msg: res.code !== 0 ? res.msg : '该账号不是商家账号' }
    },
    async fetchMe() {
      const res = await authApi.me()
      if (res.code === 0) {
        this.user = res.data
        localStorage.setItem('m_user', JSON.stringify(res.data))
      }
    },
    logout() {
      authApi.logout().catch(() => {})
      this.user = null; this.token = ''
      localStorage.removeItem('m_token'); localStorage.removeItem('m_user')
    },
  },
})
