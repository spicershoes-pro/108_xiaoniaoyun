<template>
  <div class="page-pad">
    <!-- 预警栏 -->
    <div class="alert-bar" v-if="alerts.length">
      <span>⚠️</span>
      <div class="ab-content">
        <div class="ab-title">平台预警 · 需要处理</div>
        <div style="font-size:12px;">{{ alerts.join(' · ') }}</div>
      </div>
      <button class="btn btn-sm btn-warning">立即处理</button>
    </div>

    <!-- KPI 8格 -->
    <div class="kpi-grid-8">
      <div v-for="k in kpis" :key="k.label" class="kpi-card">
        <div class="kc-accent" :style="{ background: k.color }"></div>
        <div class="kc-hd">
          <div class="kc-icon" :style="{ background: k.color+'18' }">{{ k.icon }}</div>
          <span :class="['kc-change', k.up?'up':'down']">{{ k.up?'↑':'↓' }} {{ k.change }}</span>
        </div>
        <div class="kc-val">{{ k.val }}</div>
        <div class="kc-label">{{ k.label }}</div>
      </div>
    </div>

    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px;">
      <!-- GMV 趋势 -->
      <div class="card">
        <div class="card-header"><span class="card-title">平台GMV趋势（近12月）</span><span class="tag tag-green">↑ +24%</span></div>
        <div class="card-body">
          <div class="bar-chart-wrap">
            <div v-for="(m,i) in monthlyStats" :key="i" class="bc-col">
              <div class="bc-bar" :style="{ height: barH(m.gmv)+'%', background: i===monthlyStats.length-1?'var(--blue)':'#91CAFF' }"></div>
              <div class="bc-label">{{ m.month }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- 紧急待办 -->
      <div class="card">
        <div class="card-header"><span class="card-title">⚡ 紧急待办</span><span class="tag tag-red">{{ todos.length }} 项</span></div>
        <div>
          <router-link v-for="t in todos" :key="t.to" :to="t.to" class="todo-item">
            <div class="todo-icon" :style="{ background: t.color+'20' }">{{ t.icon }}</div>
            <div class="todo-text">{{ t.text }}</div>
            <span :class="['tag', t.urgent?'tag-red':'tag-orange']">{{ t.count }}</span>
            <span style="color:var(--t4);">›</span>
          </router-link>
        </div>
      </div>
    </div>

    <!-- 地区分布 + 商家排行 -->
    <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:16px;">
      <div class="card">
        <div class="card-header"><span class="card-title">买家地区分布</span></div>
        <div class="card-body">
          <div v-for="r in regions" :key="r.n" style="margin-bottom:12px;">
            <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
              <span style="font-size:12px;">{{ r.n }}</span>
              <span style="font-size:12px;font-weight:700;">{{ r.p }}%</span>
            </div>
            <div class="progress"><div class="progress-fill" :style="{ width: r.p+'%', background: r.c }"></div></div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-header"><span class="card-title">商家GMV排行</span><router-link to="/merchants" class="card-act">全部 ›</router-link></div>
        <div style="padding:8px 0;">
          <div v-for="(m,i) in topMerchants" :key="m.id" style="display:flex;align-items:center;gap:10px;padding:9px 16px;border-bottom:1px solid var(--t6);">
            <div :class="['rno', `rno-${i}`]">{{ i+1 }}</div>
            <div style="flex:1;font-size:12px;font-weight:600;color:var(--t1);">{{ m.short_name }}</div>
            <div class="text-primary" style="font-weight:700;font-size:13px;">{{ fmtMoney(m.total_gmv) }}</div>
          </div>
        </div>
      </div>

      <div class="card">
        <div class="card-header"><span class="card-title">品类销售占比</span></div>
        <div class="card-body">
          <div v-for="c in catStats" :key="c.n" style="margin-bottom:12px;">
            <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
              <span style="font-size:12px;">{{ c.n }}</span>
              <span style="font-size:12px;font-weight:700;">{{ c.p }}%</span>
            </div>
            <div class="progress"><div class="progress-fill" :style="{ width: c.p+'%', background: c.c }"></div></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { adminApi } from '@/api'

const dashData    = ref(null)
const monthlyStats= ref([])

const kpis = computed(() => {
  const k = dashData.value?.kpis || {}
  return [
    { icon:'💰', label:'今日GMV',   val: fmtMoney(k.today_gmv||0), change:'+18%', up:true,  color:'#1677FF' },
    { icon:'📈', label:'月度GMV',   val: fmtMoney(k.month_gmv||0), change:'+24%', up:true,  color:'#52C41A' },
    { icon:'👥', label:'活跃用户',  val: (k.total_users||0).toLocaleString(), change:'+6%', up:true, color:'#722ED1' },
    { icon:'🏦', label:'平台收益',  val: fmtMoney(k.month_revenue||0), change:'+22%', up:true, color:'#FA8C16' },
    { icon:'📨', label:'待处理询盘',val: k.pending_inquiries||0, change: k.pending_inquiries>0?'需处理':'', up:false, color:'#13C2C2' },
    { icon:'📦', label:'活跃订单',  val: k.active_orders||0, change:'+15%', up:true, color:'#1677FF' },
    { icon:'⚠️', label:'纠纷订单',  val: k.dispute_orders||0, change: k.dispute_orders>0?'需介入':'', up:false, color:'#FF4D4F' },
    { icon:'🏭', label:'待审商家',  val: k.pending_merchants||0, change: k.pending_merchants>0?'待审核':'', up:false, color:'#FA8C16' },
  ]
})

const alerts = computed(() => {
  const k = dashData.value?.kpis || {}
  const a = []
  if (k.dispute_orders > 0)    a.push(`纠纷订单 ${k.dispute_orders} 单`)
  if (k.pending_merchants > 0) a.push(`${k.pending_merchants} 家商家待审核`)
  if (k.pending_products > 0)  a.push(`${k.pending_products} 个产品待审核`)
  return a
})

const todos = computed(() => {
  const k = dashData.value?.kpis || {}
  const t = []
  if (k.dispute_orders > 0)    t.push({ icon:'🚨', text:'纠纷订单待介入',   to:'/orders?status=dispute',  count:k.dispute_orders,    color:'#FF4D4F', urgent:true })
  if (k.pending_merchants > 0) t.push({ icon:'🏭', text:'商家入驻待审核',   to:'/merchants?status=reviewing', count:k.pending_merchants, color:'#1677FF', urgent:true })
  if (k.pending_products > 0)  t.push({ icon:'🧸', text:'产品上架待审核',   to:'/products?status=pending', count:k.pending_products, color:'#1677FF', urgent:false })
  if (k.pending_inquiries > 0) t.push({ icon:'📨', text:'未回复询盘',       to:'/inquiries',               count:k.pending_inquiries, color:'#FA8C16', urgent:false })
  return t
})

const topMerchants = ref([])
const regions = [
  {n:'🇺🇸 北美',p:38,c:'#1677FF'},{n:'🇪🇺 欧洲',p:29,c:'#52C41A'},
  {n:'🇯🇵 日本',p:16,c:'#722ED1'},{n:'🌏 东南亚',p:11,c:'#FA8C16'},{n:'🇦🇪 中东',p:6,c:'#13C2C2'}
]
const catStats = [
  {n:'遥控玩具',p:42,c:'#1677FF'},{n:'益智玩具',p:31,c:'#52C41A'},
  {n:'科技玩具',p:18,c:'#722ED1'},{n:'户外玩具',p:9,c:'#FA8C16'}
]

const maxGmv = computed(() => Math.max(...monthlyStats.value.map(m => m.gmv || 0), 1))
function barH(v){ return Math.max((v/maxGmv.value)*100, 4) }
function fmtMoney(v){ v=Number(v)||0; return v>=10000000?'¥'+(v/10000).toFixed(0)+'万':v>=10000?'¥'+(v/10000).toFixed(1)+'万':'¥'+v.toLocaleString() }

onMounted(async () => {
  const [dRes, mRes] = await Promise.all([
    adminApi.dashboard(),
    adminApi.merchants({ per_page: 4 }),
  ])
  if (dRes.code === 0) {
    dashData.value    = dRes.data
    monthlyStats.value= dRes.data.monthly_stats || []
  }
  if (mRes.code === 0) topMerchants.value = (mRes.data||[]).sort((a,b)=>b.total_gmv-a.total_gmv).slice(0,4)
})
</script>

<style scoped>
.page-pad { padding:22px 24px; }
.alert-bar { display:flex; align-items:center; gap:12px; background:var(--orange-l); border:1px solid #ffd591; border-radius:10px; padding:11px 16px; margin-bottom:16px; }
.ab-content { flex:1; }
.ab-title { font-size:13px; font-weight:700; color:var(--orange); }

.kpi-grid-8 { display:grid; grid-template-columns:repeat(4,1fr); gap:12px; margin-bottom:16px; }
.kpi-card { background:#fff; border:1px solid var(--border); border-radius:12px; padding:16px; position:relative; overflow:hidden; }
.kc-accent { position:absolute; top:0; right:0; width:60px; height:60px; border-radius:50%; opacity:.08; transform:translate(15px,-15px); }
.kc-hd { display:flex; justify-content:space-between; align-items:flex-start; margin-bottom:10px; }
.kc-icon { width:36px; height:36px; border-radius:9px; display:flex; align-items:center; justify-content:center; font-size:18px; }
.kc-change { font-size:11px; font-weight:600; padding:2px 7px; border-radius:12px; }
.kc-change.up   { background:var(--green-l); color:#389E0D; }
.kc-change.down { background:var(--red-l);   color:#CF1322; }
.kc-val   { font-size:24px; font-weight:900; color:var(--t1); line-height:1; }
.kc-label { font-size:12px; color:var(--t4); margin-top:4px; }

.bar-chart-wrap { display:flex; align-items:flex-end; gap:6px; height:110px; }
.bc-col { flex:1; display:flex; flex-direction:column; align-items:center; gap:4px; height:100%; justify-content:flex-end; }
.bc-bar { width:100%; border-radius:4px 4px 0 0; min-height:4px; }
.bc-label { font-size:9px; color:var(--t4); }

.todo-item { display:flex; align-items:center; gap:10px; padding:11px 16px; border-bottom:1px solid var(--t6); text-decoration:none; transition:background .12s; }
.todo-item:last-child { border:none; }
.todo-item:hover { background:var(--bg0); }
.todo-icon { width:30px; height:30px; border-radius:8px; display:flex; align-items:center; justify-content:center; font-size:15px; flex-shrink:0; }
.todo-text { flex:1; font-size:13px; color:var(--t2); font-weight:500; }

.rno { width:24px; height:24px; border-radius:6px; display:flex; align-items:center; justify-content:center; font-size:10px; font-weight:800; background:var(--t6); color:var(--t4); flex-shrink:0; }
.rno-0 { background:#FFF7E6; color:#D48806; }
.rno-1 { background:#f0f0f0; color:#595959; }
.rno-2 { background:#FFF2E8; color:#D46B08; }

.card-act { font-size:12px; color:var(--blue); text-decoration:none; }
</style>
