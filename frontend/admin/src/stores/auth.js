// admin/src/stores/auth.js
import { defineStore } from 'pinia'
import { authApi } from '@/api'

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user:  JSON.parse(localStorage.getItem('a_user') || 'null'),
    token: localStorage.getItem('a_token') || '',
  }),
  getters: {
    isLoggedIn: s => !!s.token && !!s.user,
    isAdmin:    s => ['admin','super_admin'].includes(s.user?.role),
    isSuperAdmin: s => s.user?.role === 'super_admin',
    name: s => s.user?.name || '管理员',
  },
  actions: {
    async login(phone, code) {
      const res = await authApi.login(phone, code)
      if (res.code === 0 && ['admin','super_admin'].includes(res.data.user.role)) {
        this.token = res.data.token
        this.user  = res.data.user
        localStorage.setItem('a_token', res.data.token)
        localStorage.setItem('a_user',  JSON.stringify(res.data.user))
        return { ok: true }
      }
      return { ok: false, msg: res.code !== 0 ? res.msg : '该账号没有管理员权限' }
    },
    async fetchMe() {
      const res = await authApi.me()
      if (res.code === 0) { this.user = res.data; localStorage.setItem('a_user', JSON.stringify(res.data)) }
    },
    logout() {
      authApi.logout().catch(() => {})
      this.user = null; this.token = ''
      localStorage.removeItem('a_token'); localStorage.removeItem('a_user')
    },
  },
})
