<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">数据分析</h1></div>
    <div class="kpi-grid">
      <div v-for="k in kpis" :key="k.label" class="kpi-card"><div class="kc-icon" :style="{background:k.color+'18'}">{{k.icon}}</div><div class="kc-val">{{k.val}}</div><div class="kc-label">{{k.label}}</div></div>
    </div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
      <div class="card"><div class="card-header"><span class="card-title">营业额趋势（近6月）</span></div>
        <div class="card-body">
          <div class="bar-wrap">
            <div v-for="(m,i) in trend" :key="i" class="bc-col">
              <div class="bc-bar" :style="{height:barH(m.amount)+'%',background:i===trend.length-1?'var(--blue)':'#91CAFF'}"></div>
              <div class="bc-label">{{m.month}}</div>
            </div>
          </div>
        </div>
      </div>
      <div class="card card-body">
        <div class="card-title" style="margin-bottom:14px;">询盘转化漏斗</div>
        <div v-for="f in funnel" :key="f.label" style="margin-bottom:12px;">
          <div style="display:flex;justify-content:space-between;margin-bottom:4px;font-size:13px;"><span>{{f.label}}</span><span style="font-weight:700;color:var(--blue);">{{f.count}}</span></div>
          <div class="progress"><div class="progress-fill" :style="{width:f.pct+'%',background:f.color}"/></div>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, onMounted } from 'vue'
import { dashApi } from '@/api'
const data=ref(null); const trend=ref([])
const kpis=computed(()=>{const k=data.value?.kpis||{};return[{icon:'💰',label:'本月营业额',val:'¥'+(Number(k.monthRevenue||0)/10000).toFixed(1)+'万',color:'#1677FF'},{icon:'📦',label:'累计订单',val:k.totalOrders||0,color:'#52C41A'},{icon:'📨',label:'累计询盘',val:k.totalInquiries||0,color:'#722ED1'},{icon:'🧸',label:'在售产品',val:k.onlineProducts||0,color:'#FA8C16'}]})
const funnel=computed(()=>{const k=data.value?.kpis||{};const ti=k.totalInquiries||1;return[{label:'收到询盘',count:k.totalInquiries||0,pct:100,color:'var(--blue)'},{label:'已报价',count:Math.round((k.totalInquiries||0)*0.7),pct:70,color:'var(--purple,#722ED1)'},{label:'转化为订单',count:k.totalOrders||0,pct:Math.min(100,Math.round((k.totalOrders||0)/ti*100)),color:'var(--green)'}]})
const maxAmount=computed(()=>Math.max(...trend.value.map(m=>m.amount||0),1))
function barH(v){return Math.max((v/maxAmount.value)*100,4)}
onMounted(async()=>{const r=await dashApi.index();if(r.code===0){data.value=r.data;trend.value=r.data?.monthly_trend||[]}})
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.kpi-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px;}
.kpi-card{background:#fff;border:1px solid var(--border);border-radius:12px;padding:16px;}
.kc-icon{width:36px;height:36px;border-radius:9px;display:flex;align-items:center;justify-content:center;font-size:18px;margin-bottom:10px;}
.kc-val{font-size:24px;font-weight:900;color:var(--t1);}.kc-label{font-size:12px;color:var(--t4);margin-top:3px;}
.bar-wrap{display:flex;align-items:flex-end;gap:8px;height:120px;}
.bc-col{flex:1;display:flex;flex-direction:column;align-items:center;gap:4px;height:100%;justify-content:flex-end;}
.bc-bar{width:100%;border-radius:4px 4px 0 0;min-height:4px;}.bc-label{font-size:10px;color:var(--t4);}
</style>