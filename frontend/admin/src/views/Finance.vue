<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">财务结算</h1></div>
    <div class="summary-grid">
      <div v-for="s in summaryCards" :key="s.label" class="summary-card"><div class="sc-icon" :style="{background:s.color+'18'}">{{s.icon}}</div><div class="sc-val" :style="{color:s.color}">{{s.val}}</div><div class="sc-label">{{s.label}}</div></div>
    </div>
    <div class="tab-row"><button v-for="t in tabs" :key="t.k" :class="['tab-btn',curTab===t.k?'active':'']" @click="curTab=t.k;load()">{{t.l}}<span v-if="t.k==='withdrawals'&&pendingWdCount>0" style="margin-left:4px;background:var(--orange);color:#fff;font-size:9px;padding:1px 5px;border-radius:8px;font-weight:700;">{{pendingWdCount}}</span></button></div>
    <div class="card" v-if="curTab==='withdrawals'">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>商家</th><th>提现金额</th><th>收款银行</th><th>申请时间</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="w in withdrawals" :key="w.id">
            <td style="font-weight:600;font-size:13px;">{{w.merchant_name}}</td>
            <td style="font-size:16px;font-weight:800;color:var(--blue);">¥{{Number(w.amount).toLocaleString()}}</td>
            <td style="font-size:12px;color:var(--t3);">{{w.bank_name||'—'}}</td>
            <td style="font-size:12px;color:var(--t4);">{{w.applied_at?.slice(0,10)}}</td>
            <td><span :class="['badge',{pending:'badge-pending',processing:'badge-info',completed:'badge-success',rejected:'badge-danger'}[w.status]||'badge-gray']">{{sL(w.status)}}</span></td>
            <td><div style="display:flex;gap:5px;">
              <button v-if="w.status==='pending'" class="btn btn-sm btn-primary" @click="review(w,'approve')">批准</button>
              <button v-if="w.status==='pending'" class="btn btn-sm btn-danger"  @click="review(w,'reject')">拒绝</button>
            </div></td>
          </tr>
          <tr v-if="!withdrawals.length"><td colspan="6"><div class="empty-state"><div class="empty-icon">💰</div><div class="empty-text">暂无提现申请</div></div></td></tr>
        </tbody>
      </table></div>
    </div>
    <div class="card" v-if="curTab==='commissions'">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>商家</th><th>月度GMV</th><th>佣金率</th><th>应付佣金</th><th>结算周期</th></tr></thead>
        <tbody>
          <tr v-for="c in commissions" :key="c.merchant_id">
            <td style="font-weight:600;">{{c.merchant_name}}</td>
            <td class="text-primary" style="font-weight:700;">¥{{Number(c.gmv).toLocaleString()}}</td>
            <td style="font-weight:600;">5%</td>
            <td style="font-size:16px;font-weight:800;color:var(--green);">¥{{Number(c.platform_fee).toLocaleString()}}</td>
            <td style="font-size:12px;color:var(--t3);">本月</td>
          </tr>
          <tr v-if="!commissions.length"><td colspan="5"><div class="empty-state"><div class="empty-icon">📊</div><div class="empty-text">暂无佣金数据</div></div></td></tr>
        </tbody>
      </table></div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, inject, onMounted } from 'vue'
import { adminApi } from '@/api'
const toast=inject('toast',()=>{})
const summary=ref({});const withdrawals=ref([]);const commissions=ref([]);const curTab=ref('withdrawals')
const tabs=[{k:'withdrawals',l:'提现审批'},{k:'commissions',l:'佣金明细'}]
const pendingWdCount=computed(()=>withdrawals.value.filter(w=>w.status==='pending').length)
function sL(s){return{pending:'待审批',processing:'处理中',completed:'已完成',rejected:'已拒绝'}[s]||s}
function fmtM(v){v=Number(v)||0;return v>=10000000?'¥'+(v/10000).toFixed(0)+'万':v>=10000?'¥'+(v/10000).toFixed(1)+'万':'¥'+v.toLocaleString()}
const summaryCards=computed(()=>[
  {icon:'💹',label:'平台总GMV',val:fmtM(summary.value.total_gmv),color:'#1677FF'},
  {icon:'💰',label:'平台总收益',val:fmtM(summary.value.platform_revenue),color:'#52C41A'},
  {icon:'⏳',label:'待结算金额',val:fmtM(summary.value.pending_settlement),color:'#FA8C16'},
  {icon:'✅',label:'已提现金额',val:fmtM(summary.value.withdrawn),color:'#722ED1'},
])
async function load(){
  if(curTab.value==='withdrawals'){const r=await adminApi.finance({tab:'withdrawals'});if(r.code===0)withdrawals.value=r.data||[]}
  else{const r=await adminApi.finance({tab:'commissions'});if(r.code===0)commissions.value=r.data||[]}
}
async function review(w,action){const r=await adminApi.reviewWithdrawal(w.id,{action});if(r.code===0){toast(action==='approve'?'提现已批准':'提现已拒绝',action==='approve'?'success':'warning');load()}else toast(r.msg,'error')}
onMounted(async()=>{const r=await adminApi.finance({tab:'summary'});if(r.code===0)summary.value=r.data||{};load()})
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.summary-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin-bottom:16px;}
.summary-card{background:#fff;border:1px solid var(--border);border-radius:12px;padding:16px;display:flex;flex-direction:column;gap:6px;}
.sc-icon{width:36px;height:36px;border-radius:9px;display:flex;align-items:center;justify-content:center;font-size:18px;}
.sc-val{font-size:22px;font-weight:900;}
.sc-label{font-size:12px;color:var(--t4);}
.tab-row{display:flex;border-bottom:1px solid var(--border);margin-bottom:16px;background:#fff;border-radius:10px 10px 0 0;padding:0 16px;}
.tab-btn{padding:11px 16px;border:none;background:none;font-size:13px;font-weight:500;color:var(--t4);cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;}
.tab-btn.active{color:var(--blue);border-bottom-color:var(--blue);font-weight:700;}
</style>