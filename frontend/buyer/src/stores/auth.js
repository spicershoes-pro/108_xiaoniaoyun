// src/stores/auth.js
import { defineStore } from 'pinia'
import { authApi } from '@/api'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user:    JSON.parse(localStorage.getItem('xn_user') || 'null'),
    token:   localStorage.getItem('xn_token') || '',
    loading: false,
  }),

  getters: {
    isLoggedIn: s => !!s.token && !!s.user,
    isBuyer:    s => s.user?.role === 'buyer',
    displayName: s => s.user?.buyer_profile?.company_name || s.user?.name || s.user?.phone || '',
    level: s => s.user?.buyer_profile?.level || 'bronze',
  },

  actions: {
    async login(phone, code) {
      this.loading = true
      try {
        const res = await authApi.login(phone, code)
        if (res.code === 0) {
          this.token = res.data.token
          this.user  = res.data.user
          localStorage.setItem('xn_token', res.data.token)
          localStorage.setItem('xn_user',  JSON.stringify(res.data.user))
          return { ok: true, isNew: res.data.is_new }
        }
        return { ok: false, msg: res.msg }
      } catch (e) {
        return { ok: false, msg: e.message }
      } finally {
        this.loading = false
      }
    },

    async fetchMe() {
      try {
        const res = await authApi.me()
        if (res.code === 0) {
          this.user = res.data
          localStorage.setItem('xn_user', JSON.stringify(res.data))
        }
      } catch {}
    },

    logout() {
      authApi.logout().catch(() => {})
      this.user  = null
      this.token = ''
      localStorage.removeItem('xn_token')
      localStorage.removeItem('xn_user')
    },
  },
})
