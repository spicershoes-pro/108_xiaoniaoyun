// src/router/index.js
import { createRouter, createWebHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const routes = [
  { path: '/login',    name: 'Login',    component: () => import('@/views/Login.vue'),    meta: { guest: true } },

  { path: '/',         name: 'Home',     component: () => import('@/views/Home.vue') },
  { path: '/products', name: 'Products', component: () => import('@/views/Products.vue') },
  { path: '/products/:id', name: 'ProductDetail', component: () => import('@/views/ProductDetail.vue') },
  { path: '/factories',name: 'Factories',component: () => import('@/views/Factories.vue') },
  { path: '/factories/:id', name: 'FactoryDetail', component: () => import('@/views/FactoryDetail.vue') },
  { path: '/search',   name: 'Search',   component: () => import('@/views/Search.vue') },
  { path: '/ranking',  name: 'Ranking',  component: () => import('@/views/Ranking.vue') },
  { path: '/ips',      name: 'IPs',      component: () => import('@/views/IPs.vue') },
  { path: '/circle',   name: 'Circle',   component: () => import('@/views/Circle.vue') },
  { path: '/currency', name: 'Currency', component: () => import('@/views/Currency.vue') },

  // 需登录
  { path: '/cart',     name: 'Cart',     component: () => import('@/views/Cart.vue'),     meta: { auth: true } },
  { path: '/inquiries',name: 'Inquiries',component: () => import('@/views/Inquiries.vue'),meta: { auth: true } },
  { path: '/inquiries/:id', name: 'InquiryDetail', component: () => import('@/views/InquiryDetail.vue'), meta: { auth: true } },
  { path: '/orders',   name: 'Orders',   component: () => import('@/views/Orders.vue'),   meta: { auth: true } },
  { path: '/orders/:id',name:'OrderDetail',component: () => import('@/views/OrderDetail.vue'), meta: { auth: true } },
  { path: '/messages', name: 'Messages', component: () => import('@/views/Messages.vue'), meta: { auth: true } },
  { path: '/samples',  name: 'Samples',  component: () => import('@/views/Samples.vue'),  meta: { auth: true } },
  { path: '/favorites',name: 'Favorites',component: () => import('@/views/Favorites.vue'),meta: { auth: true } },
  { path: '/profile',  name: 'Profile',  component: () => import('@/views/Profile.vue'),  meta: { auth: true } },

  { path: '/:pathMatch(.*)*', redirect: '/' },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior: () => ({ top: 0 }),
})

router.beforeEach((to, from, next) => {
  const auth = useAuthStore()
  if (to.meta.auth && !auth.isLoggedIn) return next('/login')
  if (to.meta.guest && auth.isLoggedIn)  return next('/')
  next()
})

export default router
