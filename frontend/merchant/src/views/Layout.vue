<template>
  <div class="m-layout">
    <!-- 侧栏 -->
    <aside class="sidebar">
      <div class="sb-logo">
        <span>🐦</span>
        <div>
          <div class="sb-name">霄鸟云</div>
          <div class="sb-sub">商家管理后台</div>
        </div>
      </div>

      <div class="sb-merchant">
        <div class="sm-card">
          <div class="sm-icon">🏭</div>
          <div class="sm-info">
            <div class="sm-name">{{ auth.name || '我的工厂' }}</div>
            <div class="sm-level">🥇 {{ auth.user?.merchant_profile?.level || 'silver' }}</div>
          </div>
        </div>
      </div>

      <nav class="sb-nav">
        <router-link v-for="n in navItems" :key="n.to" :to="n.to" class="nav-link">
          <span class="nav-icon">{{ n.icon }}</span>
          <span class="nav-label">{{ n.label }}</span>
          <span class="nav-badge" v-if="n.badge">{{ n.badge }}</span>
        </router-link>
      </nav>

      <div class="sb-footer">
        <button class="logout-btn" @click="doLogout">
          <span>🚪</span> 退出登录
        </button>
      </div>
    </aside>

    <!-- 主区域 -->
    <div class="m-main">
      <!-- 顶部 -->
      <header class="m-header">
        <div class="mh-title">{{ pageTitle }}</div>
        <div class="mh-right">
          <router-link to="/messages" class="hdr-icon-btn">💬</router-link>
          <div class="hdr-avatar">{{ auth.name?.slice(0,1) || '商' }}</div>
        </div>
      </header>
      <!-- 内容 -->
      <main class="m-content">
        <router-view />
      </main>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()

const titleMap = {
  Dashboard:'概览仪表盘', Inquiries:'询盘管理', Products:'产品管理',
  Orders:'订单管理', Samples:'样品管理', Messages:'消息中心',
  Analytics:'数据分析', Certs:'资质认证', Settings:'账号设置',
}
const pageTitle = computed(() => titleMap[route.name] || '管理后台')

const navItems = [
  { to:'/',            icon:'📊', label:'概览仪表盘' },
  { to:'/inquiries',   icon:'📨', label:'询盘管理',  badge:6 },
  { to:'/products',    icon:'🧸', label:'产品管理' },
  { to:'/orders',      icon:'📦', label:'订单管理',  badge:2 },
  { to:'/samples',     icon:'🎁', label:'样品管理',  badge:3 },
  { to:'/messages',    icon:'💬', label:'消息中心',  badge:5 },
  { to:'/analytics',   icon:'📈', label:'数据分析' },
  { to:'/certs',       icon:'🏅', label:'资质认证',  badge:1 },
  { to:'/settings',    icon:'⚙️', label:'账号设置' },
]

function doLogout() { auth.logout(); router.push('/login') }
</script>

<style scoped>
.m-layout { display:flex; height:100vh; overflow:hidden; }

.sidebar {
  width:220px; flex-shrink:0;
  background:linear-gradient(180deg,#0a0f1e 0%,#111827 100%);
  display:flex; flex-direction:column; overflow:hidden;
}
.sb-logo {
  height:58px; display:flex; align-items:center; gap:10px; padding:0 16px;
  border-bottom:1px solid rgba(255,255,255,.06); flex-shrink:0;
}
.sb-logo > span { font-size:22px; }
.sb-name { font-size:15px; font-weight:800; color:#fff; }
.sb-sub  { font-size:10px; color:rgba(255,255,255,.4); }

.sb-merchant { padding:10px 12px; border-bottom:1px solid rgba(255,255,255,.06); flex-shrink:0; }
.sm-card { background:rgba(22,119,255,.12); border:1px solid rgba(22,119,255,.2); border-radius:9px; padding:9px 11px; display:flex; gap:8px; align-items:center; }
.sm-icon { width:30px; height:30px; border-radius:8px; background:rgba(22,119,255,.3); display:flex; align-items:center; justify-content:center; font-size:15px; flex-shrink:0; }
.sm-name  { font-size:12px; font-weight:600; color:#fff; }
.sm-level { font-size:10px; color:var(--gold); }

.sb-nav { flex:1; overflow-y:auto; padding:8px; }
.sb-nav::-webkit-scrollbar { display:none; }
.nav-link {
  display:flex; align-items:center; gap:9px; padding:9px 10px;
  border-radius:7px; text-decoration:none; margin-bottom:2px;
  transition:background .12s; color:rgba(255,255,255,.55);
}
.nav-link:hover { background:rgba(255,255,255,.06); color:rgba(255,255,255,.85); }
.nav-link.router-link-exact-active { background:rgba(22,119,255,.2); color:#fff; font-weight:600; }
.nav-icon  { font-size:16px; width:18px; text-align:center; flex-shrink:0; }
.nav-label { font-size:12px; font-weight:500; flex:1; }
.nav-badge { min-width:16px; height:16px; background:var(--red); color:#fff; border-radius:8px; font-size:10px; font-weight:700; display:flex; align-items:center; justify-content:center; padding:0 4px; }

.sb-footer { padding:10px 8px; border-top:1px solid rgba(255,255,255,.06); flex-shrink:0; }
.logout-btn { display:flex; align-items:center; gap:8px; padding:8px 10px; border-radius:7px; border:none; background:none; color:rgba(255,255,255,.4); font-size:12px; cursor:pointer; width:100%; transition:all .15s; }
.logout-btn:hover { background:rgba(255,255,255,.06); color:rgba(255,255,255,.7); }

.m-main { flex:1; display:flex; flex-direction:column; overflow:hidden; min-width:0; }
.m-header {
  height:58px; background:#fff; border-bottom:1px solid var(--border);
  display:flex; align-items:center; padding:0 24px; gap:16px; flex-shrink:0;
  box-shadow:var(--sh-sm);
}
.mh-title  { font-size:16px; font-weight:700; color:var(--t1); flex:1; }
.mh-right  { display:flex; align-items:center; gap:10px; }
.hdr-icon-btn { width:32px; height:32px; border-radius:7px; background:var(--t6); display:flex; align-items:center; justify-content:center; font-size:16px; text-decoration:none; transition:background .15s; }
.hdr-icon-btn:hover { background:var(--blue-xl); }
.hdr-avatar { width:32px; height:32px; border-radius:8px; background:linear-gradient(135deg,var(--blue),#5e5ce6); color:#fff; font-size:13px; font-weight:700; display:flex; align-items:center; justify-content:center; }

.m-content { flex:1; overflow-y:auto; background:var(--bg0); }
.m-content::-webkit-scrollbar { width:4px; }
.m-content::-webkit-scrollbar-thumb { background:var(--t5); border-radius:2px; }
</style>
