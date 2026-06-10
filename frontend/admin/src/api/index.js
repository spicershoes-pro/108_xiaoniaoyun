// admin/src/api/index.js
import http from './http'

export const authApi = {
  login:   (phone, code) => http.post('/auth/login', { phone, code }),
  sendCode: phone        => http.post('/auth/send-code', { phone }),
  me:      ()            => http.get('/auth/me'),
  logout:  ()            => http.delete('/auth/me'),
}

export const adminApi = {
  dashboard: ()          => http.get('/admin/dashboard'),

  // 用户
  users:      params     => http.get('/admin/users',      { params }),
  updateUser: (id, data) => http.patch(`/admin/users/${id}`, data),

  // 商家
  merchants:      params     => http.get('/admin/merchants', { params }),
  updateMerchant: (id, data) => http.patch(`/admin/merchants/${id}`, data),

  // 产品
  products:      params     => http.get('/admin/products', { params }),
  updateProduct: (id, data) => http.patch(`/admin/products/${id}`, data),

  // 订单
  orders:   params => http.get('/admin/orders',    { params }),
  inquiries:params => http.get('/admin/inquiries', { params }),

  // 内容
  content:       params     => http.get('/admin/content', { params }),
  updateContent: (id, data) => http.patch(`/admin/content/${id}`, data),

  // 财务
  finance: params => http.get('/admin/finance', { params }),
  reviewWithdrawal: (id, data) => http.patch(`/admin/finance/withdrawals/${id}`, data),

  // IP
  ips:      params     => http.get('/admin/ips', { params }),
  updateIp: (id, data) => http.patch(`/admin/ips/${id}`, data),

  // 系统
  logs:         params => http.get('/admin/logs',   { params }),
  config:       ()     => http.get('/admin/config'),
  updateConfig: data   => http.patch('/admin/config', data),
}

export const msgApi = {
  conversations: ()           => http.get('/conversations'),
  createConv:    targetId     => http.post('/conversations', { target_user_id: targetId }),
  messages:      (id, params) => http.get(`/conversations/${id}/messages`, { params }),
  send:          (id, data)   => http.post(`/conversations/${id}/messages`, data),
}

export const discoverApi = {
  banners: () => http.get('/banners'),
}
