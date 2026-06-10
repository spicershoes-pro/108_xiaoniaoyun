<template>
  <div class="page-pad">
    <div class="page-header">
      <h1 class="page-title">询盘管理</h1>
      <div style="display:flex;gap:12px;align-items:center;">
        <div class="stat-pill">转化率 <b>{{ convRate }}%</b></div>
        <div class="stat-pill">平均响应 <b>{{ avgResp }}h</b></div>
      </div>
    </div>

    <!-- KPI -->
    <div class="kpi-row">
      <div v-for="k in kpis" :key="k.label" class="kpi-sm">
        <div class="kpi-sm-val" :style="{color:k.color}">{{ k.val }}</div>
        <div class="kpi-sm-label">{{ k.label }}</div>
      </div>
    </div>

    <div class="card">
      <div class="filter-bar">
        <div class="pill-group">
          <button v-for="t in tabs" :key="t.k"
                  :class="['pill', tab===t.k?'active':'']"
                  @click="tab=t.k; load()">{{ t.l }}</button>
        </div>
        <div style="margin-left:auto;display:flex;gap:8px;">
          <input v-model="q" class="form-input" placeholder="搜索买家/商家…"
                 style="width:180px;padding:6px 11px;" @keyup.enter="load" />
        </div>
      </div>

      <div class="table-wrap">
        <table class="table">
          <thead>
            <tr>
              <th>买家</th><th>商家</th><th>产品</th><th>数量</th>
              <th>优先级</th><th>响应时长</th><th>状态</th><th>创建时间</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="inq in inquiries" :key="inq.id">
              <td>
                <div style="font-weight:600;font-size:13px;">{{ inq.buyer_country }} {{ inq.buyer_name }}</div>
                <div style="font-size:11px;color:var(--t4);">{{ inq.buyer_company }}</div>
              </td>
              <td style="font-size:12px;color:var(--t3);">{{ inq.merchant_name }}</td>
              <td style="font-size:12px;color:var(--t3);max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {{ inq.items?.[0]?.product_name || '—' }}
              </td>
              <td style="font-weight:700;color:var(--blue);">
                {{ (inq.items?.[0]?.qty || 0).toLocaleString() }} 件
              </td>
              <td>
                <span :class="['tag', {high:'tag-red',medium:'tag-orange',low:'tag-gray'}[inq.priority]||'tag-gray']">
                  {{ {high:'高',medium:'中',low:'低'}[inq.priority] || inq.priority }}
                </span>
              </td>
              <td :style="{fontSize:'12px',fontWeight:600,color:parseFloat(inq.response_time)>3?'var(--orange)':inq.quoted_at?'var(--green)':'var(--t4)'}">
                {{ inq.quoted_at ? calcResp(inq.created_at, inq.quoted_at) : '—' }}
              </td>
              <td>
                <span :class="['badge', statusBadge(inq.status)]">{{ statusLabel(inq.status) }}</span>
              </td>
              <td style="font-size:11px;color:var(--t4);">{{ inq.created_at?.slice(0,10) }}</td>
            </tr>
            <tr v-if="!inquiries.length">
              <td colspan="8">
                <div class="empty-state">
                  <div class="empty-icon">📨</div>
                  <div class="empty-text">暂无询盘</div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="pagination" v-if="totalPages > 1">
        <button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;load()">上一页</button>
        <span class="page-info">{{ page }} / {{ totalPages }}</span>
        <button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;load()">下一页</button>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue'
import { adminApi } from '@/api'

const inquiries  = ref([])
const total      = ref(0)
const totalPages = ref(1)
const page       = ref(1)
const tab        = ref('all')
const q          = ref('')

const tabs = [
  { k:'all',         l:'全部' },
  { k:'pending',     l:'待回复' },
  { k:'quoted',      l:'已报价' },
  { k:'negotiating', l:'洽谈中' },
  { k:'converted',   l:'已转化' },
  { k:'closed',      l:'已关闭' },
]

const convRate = computed(() => {
  if (!inquiries.value.length) return 0
  const n = inquiries.value.filter(i => i.status === 'converted').length
  return ((n / inquiries.value.length) * 100).toFixed(1)
})

const avgResp = computed(() => {
  const quoted = inquiries.value.filter(i => i.quoted_at && i.created_at)
  if (!quoted.length) return '—'
  const avg = quoted.reduce((sum, i) => {
    const diff = (new Date(i.quoted_at) - new Date(i.created_at)) / 3600000
    return sum + diff
  }, 0) / quoted.length
  return avg.toFixed(1)
})

const kpis = computed(() => {
  const all = inquiries.value
  return [
    { label:'总询盘数',   val: total.value,                                                        color:'var(--blue)' },
    { label:'待回复',     val: all.filter(i=>i.status==='pending').length,                         color:'var(--orange)' },
    { label:'已报价',     val: all.filter(i=>i.status==='quoted').length,                          color:'var(--purple,#722ED1)' },
    { label:'已转化订单', val: all.filter(i=>i.status==='converted').length,                       color:'var(--green)' },
  ]
})

function statusLabel(s) {
  return { pending:'待回复', quoted:'已报价', negotiating:'洽谈中', converted:'已转化', closed:'已关闭' }[s] || s
}
function statusBadge(s) {
  return { pending:'badge-pending', quoted:'badge-info', negotiating:'badge-info', converted:'badge-success', closed:'badge-gray' }[s] || 'badge-gray'
}
function calcResp(created, quoted) {
  const diff = (new Date(quoted) - new Date(created)) / 3600000
  return diff < 1 ? `${Math.round(diff*60)}min` : `${diff.toFixed(1)}h`
}

async function load() {
  const params = { page: page.value }
  if (tab.value !== 'all') params.status = tab.value
  const res = await adminApi.inquiries(params)
  if (res.code === 0) {
    inquiries.value  = res.data || []
    total.value      = res.total || 0
    totalPages.value = res.total_pages || 1
  }
}

onMounted(load)
</script>

<style scoped>
.page-pad { padding: 22px 24px; }
.stat-pill { background: var(--blue-xl); border: 1px solid #91caff; border-radius: 20px; padding: 4px 12px; font-size: 12px; color: var(--t3); }
.stat-pill b { color: var(--blue); }

.kpi-row { display: flex; gap: 12px; margin-bottom: 16px; }
.kpi-sm  { flex: 1; background: #fff; border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; }
.kpi-sm-val   { font-size: 24px; font-weight: 900; line-height: 1; margin-bottom: 4px; }
.kpi-sm-label { font-size: 12px; color: var(--t4); }

.filter-bar { display: flex; align-items: center; gap: 8px; padding: 12px 16px; border-bottom: 1px solid var(--t6); }
.pill-group  { display: flex; background: var(--t6); border-radius: 7px; padding: 2px; gap: 2px; }
.pill { padding: 5px 12px; border-radius: 5px; font-size: 12px; font-weight: 600; color: var(--t4); cursor: pointer; border: none; background: transparent; transition: all .15s; }
.pill.active { background: #fff; color: var(--blue); box-shadow: var(--sh-sm); }

.pagination { display: flex; align-items: center; justify-content: center; gap: 12px; padding: 14px; }
.page-info  { font-size: 13px; color: var(--t3); }
</style>
