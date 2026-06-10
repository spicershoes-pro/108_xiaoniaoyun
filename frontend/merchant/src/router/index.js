import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  { path: '/login', name: 'Login', component: () => import('@/views/Login.vue'), meta: { guest: true } },
  {
    path: '/',
    component: () => import('@/views/Layout.vue'),
    meta: { auth: true },
    children: [
      { path: '',          name: 'Dashboard',  component: () => import('@/views/Dashboard.vue') },
      { path: 'inquiries', name: 'Inquiries',  component: () => import('@/views/Inquiries.vue') },
      { path: 'products',  name: 'Products',   component: () => import('@/views/Products.vue') },
      { path: 'orders',    name: 'Orders',     component: () => import('@/views/Orders.vue') },
      { path: 'samples',   name: 'Samples',    component: () => import('@/views/Samples.vue') },
      { path: 'messages',  name: 'Messages',   component: () => import('@/views/Messages.vue') },
      { path: 'analytics', name: 'Analytics',  component: () => import('@/views/Analytics.vue') },
      { path: 'certs',     name: 'Certs',      component: () => import('@/views/Certs.vue') },
      { path: 'settings',  name: 'Settings',   component: () => import('@/views/Settings.vue') },
    ],
  },
  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({ history: createWebHistory(import.meta.env.BASE_URL), routes, scrollBehavior: () => ({ top: 0 }) })

router.beforeEach((to) => {
  const auth = useAuthStore()
  if (to.meta.auth  && !auth.isLoggedIn) return '/login'
  if (to.meta.guest &&  auth.isLoggedIn) return '/'
})

export default router
