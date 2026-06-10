// buyer/src/api/http.js
import axios from 'axios'

const TOKEN_KEY = 'xn_token'

const http = axios.create({
  baseURL: '/api',
  timeout: 15000,
  withCredentials: true,
  headers: { 'Content-Type': 'application/json' }
})

// 请求拦截：自动附加 token
http.interceptors.request.use(cfg => {
  const token = localStorage.getItem(TOKEN_KEY)
  if (token) cfg.headers.Authorization = `Bearer ${token}`
  return cfg
}, err => Promise.reject(err))

// 响应拦截：统一处理
http.interceptors.response.use(
  res => {
    const d = res.data
    // 401 自动登出并跳转
    if (d.code === 401) {
      localStorage.removeItem(TOKEN_KEY)
      localStorage.removeItem('xn_user')
      window.location.href = '/login'
    }
    return d
  },
  err => {
    // 网络错误 / 超时 / 非 2xx HTTP
    if (err.code === 'ECONNABORTED') {
      return Promise.reject(new Error('请求超时，请检查网络连接'))
    }
    if (!err.response) {
      return Promise.reject(new Error('无法连接服务器，请检查后端是否启动'))
    }
    const msg = err.response?.data?.msg || `请求失败 (${err.response.status})`
    return Promise.reject(new Error(msg))
  }
)

export default http
