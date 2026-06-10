<template>
  <div class="dash-page">
    <!-- KPI 卡片 -->
    <div class="kpi-grid">
      <div v-for="k in kpis" :key="k.label" class="kpi-card">
        <div class="kpi-icon" :style="{ background: k.bg }">{{ k.icon }}</div>
        <div class="kpi-val">{{ k.val }}</div>
        <div class="kpi-label">{{ k.label }}</div>
        <span v-if="k.change" :class="['kpi-badge', k.up ? 'up' : 'warn']">{{ k.change }}</span>
      </div>
    </div>

    <div class="dash-grid">
      <!-- 营收趋势 -->
      <div class="card">
        <div class="card-header">
          <span class="card-title">营业额趋势（近6月）</span>
        </div>
        <div class="card-body">
          <div class="bar-chart-wrap">
            <div v-for="(m, i) in trend" :key="i" class="bc-col">
              <div class="bc-bar" :style="{ height: barHeight(m.amount) + '%', background: i===trend.length-1?'var(--blue)':'#91CAFF' }">
                <div class="bc-tooltip">¥{{ (m.amount/10000).toFixed(0) }}万</div>
              </div>
              <div class="bc-label">{{ m.month }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- 待办 -->
      <div class="card">
        <div class="card-header">
          <span class="card-title">⚡ 待办事项</span>
          <span class="tag tag-red">{{ todos.length }} 项</span>
        </div>
        <div>
          <router-link v-for="t in todos" :key="t.to" :to="t.to" class="todo-item">
            <div class="todo-icon" :style="{ background: t.color + '18' }">{{ t.icon }}</div>
            <div class="todo-text">{{ t.text }}</div>
            <span class="tag" :class="t.urgent ? 'tag-red' : 'tag-orange'">{{ t.count }}</span>
            <span style="color:var(--t4);">›</span>
          </router-link>
        </div>
      </div>
    </div>

    <!-- 最近询盘 -->
    <div class="card" style="margin-top:16px;">
      <div class="card-header">
        <span class="card-title">最近询盘</span>
        <router-link to="/inquiries" class="card-act">查看全部 ›</router-link>
      </div>
      <div class="table-wrap">
        <table class="table">
          <thead><tr>
            <th>买家</th><th>国家</th><th>产品</th><th>数量</th><th>优先级</th><th>状态</th><th>时间</th>
          </tr></thead>
          <tbody>
            <tr v-for="inq in recentInquiries" :key="inq.id">
              <td style="font-weight:600;">{{ inq.buyer_name }}</td>
              <td>{{ inq.buyer_country }}</td>
              <td style="color:var(--t3);max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{ inq.items?.[0]?.product_name }}</td>
              <td class="text-primary" style="font-weight:700;">{{ inq.items?.[0]?.qty?.toLocaleString() }} 件</td>
              <td>
                <span :class="['tag', {'tag-red':inq.priority==='high','tag-orange':inq.priority==='medium','tag-gray':inq.priority==='low'}]">
                  {{ {high:'高',medium:'中',low:'低'}[inq.priority] }}
                </span>
              </td>
              <td>
                <span :class="['badge', {'badge-pending':inq.status==='pending','badge-info':inq.status==='quoted','badge-success':inq.status==='converted','badge-gray':inq.status==='closed'}]">
                  {{ {pending:'待回复',quoted:'已报价',negotiating:'洽谈中',converted:'已转化',closed:'已关闭'}[inq.status] }}
                </span>
              </td>
              <td class="text-muted" style="font-size:12px;">{{ inq.created_at?.slice(0,10) }}</td>
            </tr>
            <tr v-if="!recentInquiries.length">
              <td colspan="7"><div class="empty-state" style="padding:24px;"><div class="empty-icon" style="font-size:32px;">📭</div><div class="empty-text">暂无询盘</div></div></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { dashApi, inquiryApi } from '@/api'

const data   = ref(null)
const trend  = ref([])
const recentInquiries = ref([])

const kpis = computed(() => {
  const k = data.value?.kpis || {}
  return [
    { icon:'💰', label:'本月营业额', val: k.monthRevenue ? '¥'+(k.monthRevenue/10000).toFixed(1)+'万' : '—', bg:'#E6F4FF', up:true },
    { icon:'📨', label:'待处理询盘', val: k.pendingInquiries || 0, bg:'#FFF7E6', change: k.pendingInquiries>0?'需处理':null },
    { icon:'📦', label:'进行中订单', val: k.activeOrders || 0, bg:'#F9F0FF' },
    { icon:'🎁', label:'待处理样品', val: k.pendingSamples || 0, bg:'#F6FFED' },
    { icon:'🧸', label:'在售产品',   val: k.onlineProducts || 0, bg:'#FFF1F0' },
    { icon:'✅', label:'本月订单',   val: k.monthOrders || 0, bg:'#F6FFED', up:true },
  ]
})

const todos = computed(() => {
  const k = data.value?.kpis || {}
  const items = []
  if (k.pendingInquiries > 0) items.push({ icon:'📨', text:`${k.pendingInquiries}条询盘待回复`, to:'/inquiries', count:k.pendingInquiries, color:'var(--red)', urgent:true })
  if (k.activeOrders > 0)     items.push({ icon:'📦', text:`${k.activeOrders}个订单进行中`, to:'/orders', count:k.activeOrders, color:'var(--blue)', urgent:false })
  if (k.pendingSamples > 0)   items.push({ icon:'🎁', text:`${k.pendingSamples}个样品申请待处理`, to:'/samples', count:k.pendingSamples, color:'var(--orange)', urgent:false })
  const expiringCerts = data.value?.expiring_certs || []
  if (expiringCerts.length > 0) items.push({ icon:'🏅', text:'有认证即将到期', to:'/certs', count:expiringCerts.length, color:'var(--orange)', urgent:true })
  return items
})

const maxAmount = computed(() => Math.max(...trend.value.map(m => m.amount || 0), 1))
function barHeight(v) { return Math.max((v / maxAmount.value) * 100, 4) }

onMounted(async () => {
  const [dRes, iRes] = await Promise.all([
    dashApi.index(),
    inquiryApi.list({ per_page: 5 }),
  ])
  if (dRes.code === 0) {
    data.value  = dRes.data
    trend.value = dRes.data.monthly_trend || []
  }
  if (iRes.code === 0) recentInquiries.value = iRes.data || []
})
</script>

<style scoped>
.dash-page { padding:22px 24px; }
.kpi-grid { display:grid; grid-template-columns:repeat(6,1fr); gap:12px; margin-bottom:16px; }
.kpi-card { background:#fff; border:1px solid var(--border); border-radius:12px; padding:16px; }
.kpi-icon { width:36px; height:36px; border-radius:9px; display:flex; align-items:center; justify-content:center; font-size:18px; margin-bottom:10px; }
.kpi-val  { font-size:24px; font-weight:900; color:var(--t1); line-height:1; margin-bottom:4px; }
.kpi-label{ font-size:12px; color:var(--t4); margin-bottom:6px; }
.kpi-badge { font-size:11px; font-weight:600; padding:2px 8px; border-radius:12px; display:inline-block; }
.kpi-badge.up   { background:var(--green-l); color:#389E0D; }
.kpi-badge.warn { background:var(--orange-l); color:#D46B08; }

.dash-grid { display:grid; grid-template-columns:1fr 340px; gap:16px; }

.bar-chart-wrap { display:flex; align-items:flex-end; gap:8px; height:120px; padding:0 4px; }
.bc-col  { flex:1; display:flex; flex-direction:column; align-items:center; gap:4px; height:100%; justify-content:flex-end; }
.bc-bar  { width:100%; border-radius:4px 4px 0 0; min-height:4px; position:relative; cursor:pointer; transition:opacity .15s; }
.bc-bar:hover { opacity:.8; }
.bc-bar:hover .bc-tooltip { display:block; }
.bc-tooltip { display:none; position:absolute; bottom:100%; left:50%; transform:translateX(-50%); background:var(--t1); color:#fff; font-size:11px; padding:3px 8px; border-radius:5px; white-space:nowrap; margin-bottom:4px; }
.bc-label { font-size:10px; color:var(--t4); }

.todo-item { display:flex; align-items:center; gap:10px; padding:12px 16px; border-bottom:1px solid var(--t6); text-decoration:none; transition:background .12s; cursor:pointer; }
.todo-item:last-child { border:none; }
.todo-item:hover { background:var(--bg0); }
.todo-icon { width:32px; height:32px; border-radius:8px; display:flex; align-items:center; justify-content:center; font-size:16px; flex-shrink:0; }
.todo-text { flex:1; font-size:13px; color:var(--t2); font-weight:500; }

.card-act { font-size:13px; color:var(--blue); text-decoration:none; }
.card-act:hover { color:var(--blue2); }
</style>
