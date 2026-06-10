// merchant/src/api/index.js
import http from './http'

export const authApi = {
  login:  (phone, code) => http.post('/auth/login',     { phone, code }),
  sendCode:(phone)      => http.post('/auth/send-code', { phone }),
  me:     ()            => http.get('/auth/me'),
  logout: ()            => http.delete('/auth/me'),
}

export const dashApi = {
  index: () => http.get('/merchant/dashboard'),
}

export const profileApi = {
  get:    ()     => http.get('/merchant/profile'),
  update: data   => http.patch('/merchant/profile', data),
}

export const productApi = {
  list:   params       => http.get('/products', { params }),
  create: data         => http.post('/products', data),
  update: (id, data)   => http.patch(`/products/${id}`, data),
  toggle: (id, status) => http.patch(`/products/${id}`, { status }),
}

export const inquiryApi = {
  list:   params       => http.get('/inquiries', { params }),
  detail: id           => http.get(`/inquiries/${id}`),
  quote:  (id, data)   => http.patch(`/inquiries/${id}`, { action:'quote', ...data }),
  close:  id           => http.patch(`/inquiries/${id}`, { action:'close' }),
}

export const orderApi = {
  list:    params      => http.get('/orders', { params }),
  detail:  id          => http.get(`/orders/${id}`),
  action:  (id, data)  => http.patch(`/orders/${id}`, data),
}

export const sampleApi = {
  list:   params     => http.get('/samples', { params }),
  update: (id, data) => http.patch(`/samples/${id}`, data),
}

export const withdrawalApi = {
  list:   ()     => http.get('/withdrawals'),
  create: data   => http.post('/withdrawals', data),
}

export const msgApi = {
  conversations: ()           => http.get('/conversations'),
  createConv:    targetId     => http.post('/conversations', { target_user_id: targetId }),
  messages:      (id, params) => http.get(`/conversations/${id}/messages`, { params }),
  send:          (id, data)   => http.post(`/conversations/${id}/messages`, data),
}

export const certApi = {
  list: () => http.get('/merchant/profile'),
}
