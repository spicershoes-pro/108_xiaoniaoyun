// src/api/index.js
import http from './http'

/* ── 认证 ── */
export const authApi = {
  sendCode: (phone, purpose = 'login') => http.post('/auth/send-code', { phone, purpose }),
  login:    (phone, code)             => http.post('/auth/login', { phone, code }),
  me:       ()                        => http.get('/auth/me'),
  logout:   ()                        => http.delete('/auth/me'),
}

/* ── 产品 ── */
export const productApi = {
  list:   params => http.get('/products', { params }),
  detail: id     => http.get(`/products/${id}`),
}

/* ── 工厂 ── */
export const merchantApi = {
  list:   params => http.get('/merchants', { params }),
  detail: id     => http.get(`/merchants/${id}`),
}

/* ── 询盘 ── */
export const inquiryApi = {
  list:   params => http.get('/inquiries', { params }),
  detail: id     => http.get(`/inquiries/${id}`),
  create: data   => http.post('/inquiries', data),
  update: (id, data) => http.patch(`/inquiries/${id}`, data),
}

/* ── 订单 ── */
export const orderApi = {
  list:   params => http.get('/orders', { params }),
  detail: id     => http.get(`/orders/${id}`),
  create: data   => http.post('/orders', data),
  action: (id, data) => http.patch(`/orders/${id}`, data),
}

/* ── 消息 ── */
export const msgApi = {
  conversations: ()          => http.get('/conversations'),
  createConv:    targetId    => http.post('/conversations', { target_user_id: targetId }),
  messages:      (id, params)=> http.get(`/conversations/${id}/messages`, { params }),
  send:          (id, data)  => http.post(`/conversations/${id}/messages`, data),
}

/* ── 采购清单 ── */
export const cartApi = {
  list:   ()           => http.get('/cart'),
  upsert: data         => http.post('/cart', data),
  remove: productId    => http.delete('/cart', { params: { product_id: productId } }),
  clear:  ()           => http.delete('/cart'),
}

/* ── 收藏 ── */
export const favApi = {
  list:   ()  => http.get('/favorites'),
  toggle: pid => http.post('/favorites', { product_id: pid }),
}

/* ── 样品 ── */
export const sampleApi = {
  list:   params => http.get('/samples', { params }),
  create: data   => http.post('/samples', data),
}

/* ── 发现 ── */
export const discoverApi = {
  search:      q       => http.get('/search', { params: { q } }),
  banners:     ()      => http.get('/banners'),
  currencies:  ()      => http.get('/currencies'),
  ips:         params  => http.get('/ips', { params }),
  applyIp:     data    => http.post('/ips/apply', data),
  posts:       params  => http.get('/posts', { params }),
  createPost:  data    => http.post('/posts', data),
  ranking:     region  => http.get('/ranking', { params: { region } }),
  notifications: params => http.get('/notifications', { params }),
  markRead:    id      => http.patch('/notifications', null, { params: { id } }),
}
