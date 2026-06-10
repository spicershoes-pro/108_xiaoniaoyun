<template>
  <div class="page-container" style="padding:28px 0 40px;">
    <div class="page-header">
      <h1 class="page-title">📊 全球热销榜</h1>
      <span class="text-muted" style="font-size:13px;">数据来源：海关出口 + 亚马逊BSR · 每周更新</span>
    </div>
    <div style="display:flex;gap:10px;margin-bottom:20px;">
      <button v-for="r in regions" :key="r.key"
              :class="['btn btn-sm', region===r.key?'btn-primary':'btn-ghost']"
              @click="region=r.key; load()">{{ r.label }}</button>
    </div>
    <div class="card">
      <div class="table-wrap">
        <table class="table">
          <thead><tr><th>排名</th><th>产品</th><th>月销量</th><th>增长率</th></tr></thead>
          <tbody>
            <tr v-for="(item,i) in list" :key="i">
              <td><div :class="['rno', i<3?'rno-'+i:'']">{{ i+1 }}</div></td>
              <td>
                <div style="display:flex;align-items:center;gap:10px;">
                  <span style="font-size:24px;">{{ item.em }}</span>
                  <span style="font-size:13px;font-weight:600;color:var(--t1);">{{ item.n }}</span>
                </div>
              </td>
              <td style="font-weight:700;color:var(--blue);">{{ item.s }}</td>
              <td><span class="tag tag-green">{{ item.g }}</span></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue'
import { discoverApi } from '@/api'
const list   = ref([])
const region = ref('US')
const regions = [{key:'US',label:'🇺🇸 北美'},{key:'EU',label:'🇪🇺 欧洲'},{key:'JP',label:'🇯🇵 日本'},{key:'SEA',label:'🌏 东南亚'}]
function fmtSales(n) {
  if (!n) return '—'
  const v = Number(n)
  return v >= 10000 ? `${(v / 10000).toFixed(1)}w` : v.toLocaleString()
}
function fmtGrowth(g) {
  if (g == null || g === '') return '—'
  const v = Number(g)
  return `${v >= 0 ? '+' : ''}${v.toFixed(0)}%`
}
async function load() {
  const res = await discoverApi.ranking(region.value)
  if (res.code === 0) {
    list.value = (res.data?.list || []).map(item => ({
      em: item.emoji || '📦',
      n: item.name || '',
      s: fmtSales(item.monthly_sales),
      g: fmtGrowth(item.growth_rate),
    }))
  }
}
onMounted(load)
</script>
<style scoped>
.rno{width:28px;height:28px;border-radius:7px;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:800;background:var(--t6);color:var(--t4);}
.rno-0{background:#FFF7E6;color:#D48806;} .rno-1{background:#f0f0f0;color:#595959;} .rno-2{background:#FFF2E8;color:#D46B08;}
</style>
