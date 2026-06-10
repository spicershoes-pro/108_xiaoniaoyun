<template>
  <div class="a-layout">
    <aside class="a-sidebar">
      <div class="as-logo">
        <span>🐦</span>
        <div>
          <div class="as-name">霄鸟云</div>
          <div class="as-sub">SUPER ADMIN CONSOLE</div>
        </div>
      </div>

      <div class="as-admin">
        <div class="aa-av">{{ auth.name.slice(0,1) }}</div>
        <div>
          <div class="aa-name">{{ auth.name }}</div>
          <div class="aa-role">{{ auth.isSuperAdmin ? '超级管理员' : '运营管理员' }}</div>
        </div>
        <div class="online-dot"></div>
      </div>

      <nav class="as-nav">
        <div v-for="g in navGroups" :key="g.label">
          <div class="nav-group-label">{{ g.label }}</div>
          <router-link v-for="n in g.items" :key="n.to" :to="n.to" class="a-nav-link">
            <span class="nav-icon">{{ n.icon }}</span>
            <span class="nav-label">{{ n.label }}</span>
            <span class="nav-badge" v-if="n.badge">{{ n.badge }}</span>
          </router-link>
        </div>
      </nav>

      <div class="as-footer">
        <button class="logout-btn" @click="doLogout">🚪 退出登录</button>
      </div>
    </aside>

    <div class="a-main">
      <header class="a-header">
        <div class="ah-breadcrumb">
          <span style="color:var(--t4);">霄鸟云</span>
          <span style="color:var(--t5);margin:0 6px;">/</span>
          <span style="font-weight:700;color:var(--t1);">{{ pageTitle }}</span>
        </div>
        <div class="ah-realtime">● 实时数据</div>
        <div style="display:flex;align-items:center;gap:10px;margin-left:auto;">
          <span class="env-badge">PROD</span>
          <div class="hdr-avatar">{{ auth.name.slice(0,1) }}</div>
        </div>
      </header>
      <main class="a-content">
        <router-view />
      </main>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const route = useRoute(); const router = useRouter(); const auth = useAuthStore()

const titleMap = {
  Dashboard:'运营大盘', Users:'用户管理', Merchants:'商家管理',
  Products:'产品审核', Orders:'订单监控', Inquiries:'询盘管理',
  IPs:'IP授权管理', Content:'内容管理', Finance:'财务结算',
  Analytics:'数据分析', System:'系统设置',
}
const pageTitle = computed(() => titleMap[route.name] || '管理后台')

const navGroups = computed(() => {
  const isSA = auth.isSuperAdmin
  return [
    { label:'OVERVIEW', items:[
      { to:'/', icon:'⬡', label:'运营大盘' },
    ]},
    { label:'USER & MERCHANT', items:[
      { to:'/users',     icon:'👥', label:'用户管理',   badge:1 },
      { to:'/merchants', icon:'🏭', label:'商家管理',   badge:2 },
    ]},
    { label:'BUSINESS', items:[
      { to:'/products',  icon:'🧸', label:'产品审核',   badge:2 },
      { to:'/orders',    icon:'📦', label:'订单监控',   badge:1 },
      { to:'/inquiries', icon:'📨', label:'询盘管理' },
      { to:'/ips',       icon:'🎨', label:'IP授权管理', badge:1 },
    ]},
    { label:'OPERATIONS', items:[
      { to:'/content', icon:'📝', label:'内容管理', badge:2 },
      ...(isSA ? [{ to:'/finance', icon:'💰', label:'财务结算', badge:3 }] : []),
    ]},
    { label:'INSIGHTS', items:[
      { to:'/analytics', icon:'📊', label:'数据分析' },
      ...(isSA ? [{ to:'/system', icon:'⚙️', label:'系统设置' }] : []),
    ]},
  ]
})

function doLogout() { auth.logout(); router.push('/login') }
</script>

<style scoped>
.a-layout { display:flex; height:100vh; overflow:hidden; }
.a-sidebar { width:220px; flex-shrink:0; background:#080e1a; display:flex; flex-direction:column; overflow:hidden; box-shadow:2px 0 12px rgba(0,0,0,.2); }
.as-logo { height:58px; display:flex; align-items:center; gap:10px; padding:0 16px; border-bottom:1px solid rgba(255,255,255,.05); flex-shrink:0; background:linear-gradient(135deg,#0a1628,#111827); }
.as-logo > span { font-size:22px; }
.as-name { font-size:14px; font-weight:800; color:#fff; }
.as-sub  { font-size:9px; color:rgba(255,255,255,.3); letter-spacing:.5px; }

.as-admin { padding:10px 12px; border-bottom:1px solid rgba(255,255,255,.05); display:flex; align-items:center; gap:8px; flex-shrink:0; }
.aa-av { width:28px; height:28px; border-radius:7px; background:linear-gradient(135deg,var(--blue),#5e5ce6); color:#fff; font-size:12px; font-weight:700; display:flex; align-items:center; justify-content:center; flex-shrink:0; }
.aa-name { font-size:12px; font-weight:600; color:#fff; }
.aa-role { font-size:10px; color:var(--gold); }
.online-dot { width:7px; height:7px; background:var(--green); border-radius:50%; margin-left:auto; flex-shrink:0; }

.as-nav { flex:1; overflow-y:auto; padding:8px; }
.as-nav::-webkit-scrollbar { display:none; }
.nav-group-label { font-size:9px; font-weight:700; color:rgba(255,255,255,.2); padding:10px 8px 4px; letter-spacing:1px; }
.a-nav-link { display:flex; align-items:center; gap:8px; padding:8px 10px; border-radius:7px; text-decoration:none; margin-bottom:1px; color:rgba(255,255,255,.5); font-size:12px; font-weight:500; transition:background .12s; }
.a-nav-link:hover { background:rgba(255,255,255,.06); color:rgba(255,255,255,.8); }
.a-nav-link.router-link-exact-active { background:rgba(22,119,255,.2); color:#fff; font-weight:700; }
.nav-icon  { font-size:14px; width:18px; text-align:center; flex-shrink:0; }
.nav-label { flex:1; }
.nav-badge { min-width:16px; height:16px; background:var(--red); color:#fff; border-radius:8px; font-size:9px; font-weight:700; display:flex; align-items:center; justify-content:center; padding:0 4px; }

.as-footer { padding:10px 8px; border-top:1px solid rgba(255,255,255,.05); flex-shrink:0; }
.logout-btn { display:flex; align-items:center; gap:8px; padding:8px 10px; border-radius:7px; border:none; background:none; color:rgba(255,255,255,.35); font-size:12px; cursor:pointer; width:100%; transition:all .15s; }
.logout-btn:hover { background:rgba(255,255,255,.06); color:rgba(255,255,255,.6); }

.a-main { flex:1; display:flex; flex-direction:column; overflow:hidden; min-width:0; }
.a-header { height:58px; background:#fff; border-bottom:1px solid var(--border); display:flex; align-items:center; padding:0 24px; gap:12px; flex-shrink:0; box-shadow:var(--sh-sm); }
.ah-breadcrumb { display:flex; align-items:center; font-size:13px; flex:1; }
.ah-realtime { display:inline-flex; align-items:center; gap:5px; font-size:11px; font-weight:600; color:var(--green); background:var(--green-l); padding:3px 10px; border-radius:20px; flex-shrink:0; }
.env-badge { padding:3px 8px; background:var(--green-l); border:1px solid #b7eb8f; border-radius:20px; font-size:10px; font-weight:700; color:#389E0D; letter-spacing:.5px; }
.hdr-avatar { width:30px; height:30px; border-radius:8px; background:linear-gradient(135deg,var(--red),#fa541c); color:#fff; font-size:12px; font-weight:700; display:flex; align-items:center; justify-content:center; }

.a-content { flex:1; overflow-y:auto; background:var(--bg0); }
.a-content::-webkit-scrollbar { width:4px; }
.a-content::-webkit-scrollbar-thumb { background:var(--t5); border-radius:2px; }
</style>
