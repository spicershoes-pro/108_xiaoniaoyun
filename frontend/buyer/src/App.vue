<template>
  <div id="xn-app">
    <!-- 顶部导航 -->
    <header class="topbar" v-if="!isAuthPage">
      <div class="page-container topbar-inner">
        <router-link to="/" class="topbar-logo">
          <span class="logo-icon">🐦</span>
          <span class="logo-text">霄鸟云</span>
          <span class="logo-sub">跨境玩具选品</span>
        </router-link>

        <div class="topbar-search">
          <span class="search-icon">🔍</span>
          <input v-model="searchQ" @keyup.enter="doSearch"
                 placeholder="搜索产品、工厂、品类…" />
        </div>

        <nav class="topbar-nav">
          <router-link to="/products">选品中心</router-link>
          <router-link to="/factories">工厂库</router-link>
          <router-link to="/ranking">热销榜</router-link>
          <router-link to="/ips">IP授权</router-link>
          <router-link to="/circle">玩具圈</router-link>
        </nav>

        <div class="topbar-actions">
          <router-link to="/cart" class="action-btn" v-if="auth.isLoggedIn">
            🛒<span class="badge-num" v-if="cart.count">{{ cart.count }}</span>
          </router-link>
          <router-link to="/messages" class="action-btn" v-if="auth.isLoggedIn">💬</router-link>

          <div v-if="auth.isLoggedIn" class="user-menu" @click="toggleUser">
            <div class="user-av">{{ (auth.displayName || '我').slice(0,1) }}</div>
            <div class="user-dropdown" v-show="showUser">
              <router-link to="/profile">👤 我的账号</router-link>
              <router-link to="/orders">📦 我的订单</router-link>
              <router-link to="/inquiries">📨 我的询盘</router-link>
              <router-link to="/favorites">❤️ 我的收藏</router-link>
              <router-link to="/samples">🎁 样品申请</router-link>
              <div class="divider" />
              <a @click="doLogout">🚪 退出登录</a>
            </div>
          </div>
          <template v-else>
            <router-link to="/login" class="btn btn-primary btn-sm">登录 / 注册</router-link>
          </template>
        </div>
      </div>
    </header>

    <!-- 主内容 -->
    <main :class="{ 'has-topbar': !isAuthPage }">
      <router-view />
    </main>

    <!-- Toast -->
    <div class="toast-wrapper">
      <transition-group name="toast-fade">
        <div v-for="t in toasts" :key="t.id" :class="['toast', `toast-${t.type}`]">
          {{ t.msg }}
        </div>
      </transition-group>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, provide, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
import { useCartStore }  from '@/stores/cart'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const cart   = useCartStore()

const isAuthPage = computed(() => route.name === 'Login')
const searchQ    = ref('')
const showUser   = ref(false)

// Toast 系统
const toasts = ref([])
function showToast(msg, type = 'success', duration = 2500) {
  const id = Date.now()
  toasts.value.push({ id, msg, type })
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, duration)
}
provide('toast', showToast)

function doSearch() {
  if (searchQ.value.trim()) {
    router.push({ name: 'Search', query: { q: searchQ.value.trim() } })
    searchQ.value = ''
  }
}
function toggleUser() { showUser.value = !showUser.value }
function doLogout()   { auth.logout(); router.push('/') }

onMounted(async () => {
  if (auth.token) {
    await auth.fetchMe()
    if (auth.isLoggedIn) cart.fetch()
  }
  document.addEventListener('click', e => {
    if (!e.target.closest('.user-menu')) showUser.value = false
  })
})
</script>

<style scoped>
.topbar {
  position: fixed; top: 0; left: 0; right: 0; z-index: 100;
  height: 58px; background: #fff; border-bottom: 1px solid var(--border);
  box-shadow: var(--sh-sm);
}
.topbar-inner {
  height: 100%; display: flex; align-items: center; gap: 20px;
}
.topbar-logo {
  display: flex; align-items: center; gap: 6px; text-decoration: none; flex-shrink: 0;
}
.logo-icon { font-size: 22px; }
.logo-text { font-size: 17px; font-weight: 800; color: var(--t1); }
.logo-sub  { font-size: 11px; color: var(--t4); }

.topbar-search {
  flex: 1; max-width: 360px;
  display: flex; align-items: center; gap: 8px;
  background: var(--bg0); border: 1.5px solid var(--border);
  border-radius: var(--r8); padding: 7px 12px;
  transition: border-color .15s;
}
.topbar-search:focus-within { border-color: var(--blue); background: #fff; }
.search-icon { font-size: 15px; color: var(--t4); flex-shrink: 0; }
.topbar-search input { flex: 1; border: none; background: transparent; outline: none; font-size: 13px; color: var(--t2); }
.topbar-search input::placeholder { color: var(--t4); }

.topbar-nav { display: flex; gap: 2px; flex-shrink: 0; }
.topbar-nav a {
  padding: 6px 10px; border-radius: 6px; font-size: 13px; font-weight: 500;
  color: var(--t3); text-decoration: none; transition: all .15s;
}
.topbar-nav a:hover,
.topbar-nav a.router-link-active { color: var(--blue); background: var(--blue-xl); }

.topbar-actions { display: flex; align-items: center; gap: 8px; flex-shrink: 0; }
.action-btn {
  position: relative; width: 34px; height: 34px;
  display: flex; align-items: center; justify-content: center;
  border-radius: var(--r8); font-size: 18px;
  text-decoration: none; transition: background .15s;
}
.action-btn:hover { background: var(--bg0); }
.badge-num {
  position: absolute; top: 2px; right: 2px;
  min-width: 16px; height: 16px; padding: 0 4px;
  background: var(--red); color: #fff;
  border-radius: 8px; font-size: 10px; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
  border: 1.5px solid #fff;
}

.user-menu { position: relative; cursor: pointer; }
.user-av {
  width: 32px; height: 32px; border-radius: var(--r8);
  background: linear-gradient(135deg, var(--blue), #5e5ce6);
  color: #fff; font-size: 13px; font-weight: 700;
  display: flex; align-items: center; justify-content: center;
}
.user-dropdown {
  position: absolute; top: calc(100% + 8px); right: 0;
  background: #fff; border: 1px solid var(--border);
  border-radius: var(--r12); box-shadow: var(--sh-md);
  padding: 6px; min-width: 160px; z-index: 200;
}
.user-dropdown a {
  display: flex; align-items: center; gap: 8px;
  padding: 8px 12px; border-radius: var(--r8);
  font-size: 13px; color: var(--t2); text-decoration: none;
  transition: background .12s; cursor: pointer;
}
.user-dropdown a:hover { background: var(--bg0); color: var(--blue); }
.user-dropdown .divider { height: 1px; background: var(--t6); margin: 4px 8px; }

main.has-topbar { padding-top: 58px; min-height: 100vh; }

.toast-fade-enter-active,
.toast-fade-leave-active { transition: all .2s ease; }
.toast-fade-enter-from   { opacity: 0; transform: translateY(-10px); }
.toast-fade-leave-to     { opacity: 0; transform: translateY(-10px); }
</style>
