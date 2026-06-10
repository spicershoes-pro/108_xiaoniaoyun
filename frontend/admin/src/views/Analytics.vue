<template>
  <div class="page-pad">
    <div class="page-header">
      <h1 class="page-title">数据分析</h1>
      <div class="pill-group">
        <button v-for="r in ranges" :key="r.k"
                :class="['pill', range===r.k?'active':'']"
                @click="range=r.k">{{ r.l }}</button>
      </div>
    </div>

    <!-- 核心指标 -->
    <div class="kpi-grid">
      <div v-for="k in kpis" :key="k.label" class="kpi-card">
        <div class="kc-top">
          <div class="kc-icon" :style="{background:k.color+'18'}">{{ k.icon }}</div>
          <span :class="['kc-badge', k.up?'up':'down']">{{ k.up?'↑':'↓' }}{{ k.change }}</span>
        </div>
        <div class="kc-val">{{ k.val }}</div>
        <div class="kc-label">{{ k.label }}</div>
      </div>
    </div>

    <div class="chart-row">
      <!-- GMV vs 收益 -->
      <div class="card chart-card">
        <div class="card-header">
          <span class="card-title">GMV vs 平台收益（近12月）</span>
        </div>
        <div class="card-body">
          <div class="legend">
            <div class="legend-item"><div class="legend-dot" style="background:var(--blue)"></div>GMV</div>
            <div class="legend-item"><div class="legend-dot" style="background:var(--green)"></div>平台收益</div>
          </div>
          <div class="bar-area">
            <div v-for="(m,i) in monthlyData" :key="i" class="bar-col">
              <div class="bar-gmv"     :style="{height: pct(m.gmv, maxGmv)+'%', background: i===monthlyData.length-1?'var(--blue)':'#91CAFF'}"></div>
              <div class="bar-revenue" :style="{height: pct(m.revenue, maxGmv)+'%', background: i===monthlyData.length-1?'var(--green)':'#B7EB8F'}"></div>
              <div class="bar-label">{{ m.month }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- 品类分布 -->
      <div class="card chart-card">
        <div class="card-header"><span class="card-title">品类成交分布</span></div>
        <div class="card-body">
          <div v-for="c in catDist" :key="c.n" style="margin-bottom:14px;">
            <div style="display:flex;justify-content:space-between;margin-bottom:5px;">
              <span style="font-size:13px;display:flex;align-items:center;gap:6px;">
                <span>{{ c.em }}</span>{{ c.n }}
              </span>
              <span style="font-size:13px;font-weight:700;">{{ c.p }}%</span>
            </div>
            <div class="progress">
              <div class="progress-fill" :style="{width:c.p+'%', background:c.color}"></div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="chart-row" style="margin-top:16px;">
      <!-- 用户活跃时段 -->
      <div class="card chart-card">
        <div class="card-header"><span class="card-title">用户活跃时段</span></div>
        <div class="card-body">
          <div class="heatmap">
            <div v-for="(v,i) in hourData" :key="i" class="hour-col">
              <div class="hour-bar" :style="{height: pct(v, 100)+'%', background: i>=8&&i<=21?'var(--blue)':'var(--blue-l)'}"></div>
              <div class="hour-label" v-if="i%3===0">{{ i }}时</div>
              <div class="hour-label" v-else></div>
            </div>
          </div>
          <div style="font-size:12px;color:var(--t4);margin-top:8px;text-align:center;">峰值：9:00 - 21:00</div>
        </div>
      </div>

      <!-- 平台健康度 -->
      <div class="card chart-card">
        <div class="card-header"><span class="card-title">平台健康度指标</span></div>
        <div class="card-body">
          <div v-for="h in healthMetrics" :key="h.label" style="margin-bottom:16px;">
            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:5px;">
              <span style="font-size:13px;color:var(--t2);">{{ h.label }}</span>
              <span style="font-size:14px;font-weight:800;" :style="{color:h.color}">{{ h.val }}</span>
            </div>
            <div class="progress">
              <div class="progress-fill" :style="{width:h.pct+'%', background:h.color}"></div>
            </div>
          </div>
        </div>
      </div>

      <!-- 买家地区 -->
      <div class="card chart-card">
        <div class="card-header"><span class="card-title">买家地区分布</span></div>
        <div class="card-body">
          <div v-for="r in regionDist" :key="r.n" style="margin-bottom:12px;">
            <div style="display:flex;justify-content:space-between;margin-bottom:4px;">
              <span style="font-size:13px;">{{ r.n }}</span>
              <span style="font-size:13px;font-weight:700;">{{ r.p }}%</span>
            </div>
            <div class="progress">
              <div class="progress-fill" :style="{width:r.p+'%', background:r.c}"></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { adminApi } from '@/api'

const range       = ref('12m')
const monthlyData = ref([])
const ranges = [{ k:'7d', l:'近7日' }, { k:'30d', l:'近30日' }, { k:'12m', l:'近12月' }]

const kpis = [
  { icon:'📈', label:'用户增长率',   val:'+6.2%',  change:'1.2%',  up:true,  color:'#1677FF' },
  { icon:'🔄', label:'询盘转化率',   val:'58.3%',  change:'3.2%',  up:true,  color:'#52C41A' },
  { icon:'💰', label:'平均订单金额', val:'¥3.82万', change:'12%',   up:true,  color:'#722ED1' },
  { icon:'⚡', label:'商家响应率',   val:'98.1%',  change:'0.3%',  up:true,  color:'#FA8C16' },
]

const catDist = [
  { n:'遥控玩具', em:'🚗', p:42, color:'#1677FF' },
  { n:'益智玩具', em:'🧩', p:31, color:'#52C41A' },
  { n:'科技玩具', em:'📱', p:18, color:'#722ED1' },
  { n:'户外玩具', em:'🏃', p:9,  color:'#FA8C16' },
]

const regionDist = [
  { n:'🇺🇸 北美', p:38, c:'#1677FF' },
  { n:'🇪🇺 欧洲', p:29, c:'#52C41A' },
  { n:'🇯🇵 日本', p:16, c:'#722ED1' },
  { n:'🌏 东南亚',p:11, c:'#FA8C16' },
  { n:'🇦🇪 中东', p:6,  c:'#13C2C2' },
]

const hourData = [20,25,30,35,42,55,70,85,92,98,95,90,88,85,82,80,88,95,98,92,80,65,45,30]

const healthMetrics = [
  { label:'询盘响应率', val:'98.1%', pct:98.1, color:'var(--green)' },
  { label:'产品合格率', val:'94.3%', pct:94.3, color:'var(--blue)'  },
  { label:'纠纷解决率', val:'86.7%', pct:86.7, color:'var(--purple,#722ED1)' },
  { label:'商家活跃率', val:'91.2%', pct:91.2, color:'var(--orange)' },
]

const maxGmv = computed(() => Math.max(...monthlyData.value.map(m => m.gmv || 0), 1))
function pct(v, max) { return Math.max((v / max) * 100, 3) }

onMounted(async () => {
  const res = await adminApi.dashboard()
  if (res.code === 0) {
    monthlyData.value = (res.data?.monthly_stats || []).map(m => ({
      month:   m.month,
      gmv:     m.gmv     || 0,
      revenue: m.revenue || 0,
    }))
  }
})
</script>

<style scoped>
.page-pad { padding: 22px 24px; }

.pill-group { display: flex; background: var(--t6); border-radius: 7px; padding: 2px; gap: 2px; }
.pill { padding: 5px 12px; border-radius: 5px; font-size: 12px; font-weight: 600; color: var(--t4); cursor: pointer; border: none; background: transparent; transition: all .15s; }
.pill.active { background: #fff; color: var(--blue); box-shadow: var(--sh-sm); }

.kpi-grid { display: grid; grid-template-columns: repeat(4,1fr); gap: 12px; margin-bottom: 16px; }
.kpi-card { background: #fff; border: 1px solid var(--border); border-radius: 12px; padding: 16px; }
.kc-top   { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 10px; }
.kc-icon  { width: 36px; height: 36px; border-radius: 9px; display: flex; align-items: center; justify-content: center; font-size: 18px; }
.kc-badge { font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 12px; }
.kc-badge.up   { background: var(--green-l); color: #389E0D; }
.kc-badge.down { background: var(--red-l);   color: #CF1322; }
.kc-val   { font-size: 24px; font-weight: 900; color: var(--t1); }
.kc-label { font-size: 12px; color: var(--t4); margin-top: 3px; }

.chart-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.chart-card .card-body { padding: 16px 18px; }

.legend { display: flex; gap: 16px; margin-bottom: 12px; }
.legend-item { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--t3); }
.legend-dot  { width: 10px; height: 10px; border-radius: 3px; }

.bar-area { display: flex; align-items: flex-end; gap: 4px; height: 110px; }
.bar-col  { flex: 1; display: flex; flex-direction: column; align-items: stretch; gap: 2px; height: 100%; justify-content: flex-end; }
.bar-gmv, .bar-revenue { min-height: 3px; border-radius: 2px 2px 0 0; transition: height .4s ease; }
.bar-label { font-size: 9px; color: var(--t4); text-align: center; margin-top: 3px; }

.chart-row:last-child { grid-template-columns: 1fr 1fr 1fr; }

.heatmap { display: flex; align-items: flex-end; gap: 3px; height: 80px; }
.hour-col  { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: flex-end; gap: 3px; height: 100%; }
.hour-bar  { width: 100%; min-height: 3px; border-radius: 2px 2px 0 0; }
.hour-label{ font-size: 8px; color: var(--t4); }
</style>
