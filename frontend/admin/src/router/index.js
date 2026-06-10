import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  { path: '/login', name: 'Login', component: () => import('@/views/Login.vue'), meta: { guest: true } },
  {
    path: '/',
    component: () => import('@/views/Layout.vue'),
    meta: { auth: true },
    children: [
      { path: '',           name: 'Dashboard',  component: () => import('@/views/Dashboard.vue') },
      { path: 'users',      name: 'Users',      component: () => import('@/views/Users.vue') },
      { path: 'merchants',  name: 'Merchants',  component: () => import('@/views/Merchants.vue') },
      { path: 'products',   name: 'Products',   component: () => import('@/views/Products.vue') },
      { path: 'orders',     name: 'Orders',     component: () => import('@/views/Orders.vue') },
      { path: 'inquiries',  name: 'Inquiries',  component: () => import('@/views/Inquiries.vue') },
      { path: 'ips',        name: 'IPs',        component: () => import('@/views/IPs.vue') },
      { path: 'content',    name: 'Content',    component: () => import('@/views/Content.vue') },
      { path: 'finance',    name: 'Finance',    component: () => import('@/views/Finance.vue'),   meta: { superAdmin: true } },
      { path: 'analytics',  name: 'Analytics',  component: () => import('@/views/Analytics.vue') },
      { path: 'system',     name: 'System',     component: () => import('@/views/System.vue'),    meta: { superAdmin: true } },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({ history: createWebHistory(import.meta.env.BASE_URL), routes, scrollBehavior: () => ({ top: 0 }) })
router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.auth      && !auth.isLoggedIn)   return '/login'
  if (to.meta.guest     &&  auth.isLoggedIn)   return '/'
  if (to.meta.superAdmin && !auth.isSuperAdmin) return '/'
})
export default router
