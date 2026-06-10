<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header"><h1 class="page-title">💱 汇率换算</h1><span class="text-muted" style="font-size:12px;">基准货币：人民币（CNY）· 数据每日更新</span></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:20px;">
      <!-- 换算器 -->
      <div class="card card-body">
        <div class="card-title" style="margin-bottom:16px;">实时换算</div>
        <div class="form-group">
          <label class="form-label">金额</label>
          <div style="display:flex;gap:8px;">
            <input v-model.number="amount" type="number" class="form-input" style="flex:1;" @input="calc"/>
            <select v-model="fromCur" class="form-input form-select" style="width:130px;" @change="calc">
              <option value="CNY">🇨🇳 CNY</option>
              <option v-for="r in rates" :key="r.currency_code" :value="r.currency_code">{{ r.flag }} {{ r.currency_code }}</option>
            </select>
          </div>
        </div>
        <div style="text-align:center;font-size:24px;color:var(--t4);margin:8px 0;">⇅</div>
        <div class="form-group">
          <label class="form-label">换算结果</label>
          <div style="display:flex;gap:8px;">
            <div class="form-input" style="flex:1;font-size:18px;font-weight:800;color:var(--blue);background:var(--bg0);">{{ result }}</div>
            <select v-model="toCur" class="form-input form-select" style="width:130px;" @change="calc">
              <option value="CNY">🇨🇳 CNY</option>
              <option v-for="r in rates" :key="r.currency_code" :value="r.currency_code">{{ r.flag }} {{ r.currency_code }}</option>
            </select>
          </div>
        </div>
        <div style="font-size:12px;color:var(--t4);margin-top:8px;">1 {{ fromCur }} ≈ {{ singleRate }} {{ toCur }}</div>
      </div>

      <!-- 汇率列表 -->
      <div class="card">
        <div class="card-header"><span class="card-title">主要货币对人民币汇率</span></div>
        <div class="table-wrap">
          <table class="table">
            <thead><tr><th>货币</th><th>代码</th><th>汇率（对CNY）</th><th>换算（1CNY=）</th></tr></thead>
            <tbody>
              <tr v-for="r in rates" :key="r.currency_code" style="cursor:pointer;" @click="fromCur=r.currency_code;toCur='CNY';calc()">
                <td><span style="font-size:18px;margin-right:6px;">{{ r.flag }}</span>{{ r.name }}</td>
                <td style="font-weight:700;font-family:monospace;">{{ r.currency_code }}</td>
                <td style="font-weight:800;color:var(--blue);">{{ r.rate_to_cny }}</td>
                <td style="font-size:12px;color:var(--t4);">{{ (1/r.rate_to_cny).toFixed(4) }} {{ r.currency_code }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, onMounted } from 'vue'
import { discoverApi } from '@/api'
const rates=ref([]); const amount=ref(1000); const fromCur=ref('CNY'); const toCur=ref('USD')
const result=ref('—')
const singleRate=computed(()=>{
  if(fromCur.value===toCur.value) return '1.000000'
  const from=fromCur.value==='CNY'?1:rates.value.find(r=>r.currency_code===fromCur.value)?.rate_to_cny||1
  const to=toCur.value==='CNY'?1:rates.value.find(r=>r.currency_code===toCur.value)?.rate_to_cny||1
  return (from/to).toFixed(6)
})
function calc(){
  const from=fromCur.value==='CNY'?1:rates.value.find(r=>r.currency_code===fromCur.value)?.rate_to_cny||1
  const to=toCur.value==='CNY'?1:rates.value.find(r=>r.currency_code===toCur.value)?.rate_to_cny||1
  result.value=(amount.value*from/to).toFixed(2)
}
onMounted(async()=>{ const r=await discoverApi.currencies(); if(r.code===0){rates.value=r.data||[];calc()} })
</script>