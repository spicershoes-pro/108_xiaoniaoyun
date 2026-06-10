<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">订单管理</h1><span style="font-size:13px;color:var(--t4);">共 {{ total }} 个订单</span></div>
    <div class="filter-bar card" style="margin-bottom:14px;display:flex;gap:6px;padding:10px 14px;">
      <button v-for="t in tabs" :key="t.k" :class="['btn btn-sm',tab===t.k?'btn-primary':'btn-ghost']" @click="tab=t.k;load()">{{t.l}}</button>
    </div>
    <div class="card">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>订单号</th><th>买家</th><th>产品</th><th>金额</th><th>进度</th><th>截止日期</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="o in orders" :key="o.id">
            <td class="mono" style="font-size:12px;">{{ o.order_no }}</td>
            <td><div style="font-weight:600;font-size:13px;">{{ o.buyer_country }} {{ o.buyer_name }}</div><div style="font-size:11px;color:var(--t4);">{{ o.buyer_company }}</div></td>
            <td style="font-size:12px;color:var(--t3);max-width:130px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{ o.items?.[0]?.product_name }}</td>
            <td><div class="text-primary" style="font-weight:700;">¥{{ Number(o.total_amount).toLocaleString() }}</div><div style="font-size:11px;color:var(--t4);">已付 ¥{{ Number(o.deposit).toLocaleString() }}</div></td>
            <td>
              <div style="display:flex;align-items:center;gap:2px;">
                <div v-for="i in 6" :key="i" :class="['ms', o.step>i?'ms-done':o.step===i?'ms-cur':'ms-todo']">{{ o.step>i?'✓':i }}</div>
              </div>
            </td>
            <td :style="{fontSize:'12px',color:isOverdue(o.deadline)?'var(--red)':'var(--t3)',fontWeight:isOverdue(o.deadline)?700:400}">{{ o.deadline||'—' }}</td>
            <td><span :class="['badge',sB(o.status)]">{{ sL(o.status) }}</span></td>
            <td>
              <div style="display:flex;gap:5px;flex-wrap:wrap;">
                <button v-if="o.status==='paid'"       class="btn btn-sm btn-outline" @click="act(o,'start_material')">开始备料</button>
                <button v-if="o.status==='material'"   class="btn btn-sm btn-outline" @click="act(o,'start_production')">开始生产</button>
                <button v-if="o.status==='production'" class="btn btn-sm btn-primary" @click="openShip(o)">录入发货</button>
                <span v-if="['completed','cancelled'].includes(o.status)" style="font-size:12px;color:var(--t4);">已结束</span>
              </div>
            </td>
          </tr>
          <tr v-if="!orders.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">📦</div><div class="empty-text">暂无订单</div></div></td></tr>
        </tbody>
      </table></div>
      <div class="pagination" v-if="totalPages>1"><button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;load()">上一页</button><span class="page-info">{{page}} / {{totalPages}}</span><button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;load()">下一页</button></div>
    </div>

    <!-- 发货弹窗 -->
    <div class="modal-ov" v-if="shipTarget" @click.self="shipTarget=null">
      <div class="modal-box">
        <div class="modal-hd"><span class="modal-title">录入发货信息</span><button class="modal-close" @click="shipTarget=null">✕</button></div>
        <div class="modal-body">
          <div style="background:var(--bg0);border-radius:10px;padding:12px;margin-bottom:14px;font-size:13px;"><div style="font-weight:700;">{{ shipTarget?.order_no }}</div><div class="text-muted">{{ shipTarget?.buyer_name }} · ¥{{ Number(shipTarget?.total_amount).toLocaleString() }}</div></div>
          <div class="form-group"><label class="form-label">快递公司 *</label>
            <select v-model="express" class="form-input form-select"><option value="">请选择</option><option v-for="e in expressList" :key="e">{{e}}</option></select>
          </div>
          <div class="form-group"><label class="form-label">快递单号 *</label><input v-model="expressNo" class="form-input" placeholder="请输入快递单号"/></div>
        </div>
        <div class="modal-ft"><button class="btn btn-ghost" @click="shipTarget=null">取消</button><button class="btn btn-primary" :disabled="!express||!expressNo||sending" @click="doShip">{{sending?'提交中…':'确认发货'}}</button></div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { orderApi } from '@/api'
const toast=inject('toast',()=>{})
const orders=ref([]);const total=ref(0);const totalPages=ref(1);const page=ref(1);const tab=ref('all')
const shipTarget=ref(null);const express=ref('');const expressNo=ref('');const sending=ref(false)
const tabs=[{k:'all',l:'全部'},{k:'paid',l:'待备料'},{k:'material',l:'备料中'},{k:'production',l:'生产中'},{k:'shipping',l:'运输中'},{k:'completed',l:'已完成'}]
const expressList=['顺丰国际','DHL','FedEx','UPS','EMS','中通国际','TNT']
function sL(s){return{pending_payment:'待付款',paid:'已付款',material:'备料中',production:'生产中',shipping:'运输中',delivered:'已送达',completed:'已完成',cancelled:'已取消',dispute:'纠纷中'}[s]||s}
function sB(s){return{pending_payment:'badge-pending',paid:'badge-info',material:'badge-info',production:'badge-info',shipping:'badge-info',completed:'badge-success',cancelled:'badge-gray',dispute:'badge-danger'}[s]||'badge-gray'}
function isOverdue(d){return d&&new Date(d)<new Date()}
async function load(){const p={page:page.value};if(tab.value!=='all')p.status=tab.value;const r=await orderApi.list(p);if(r.code===0){orders.value=r.data||[];total.value=r.total||0;totalPages.value=r.total_pages||1}}
async function act(o,action){const r=await orderApi.action(o.id,{action});if(r.code===0){toast('状态已更新');load()}else toast(r.msg,'error')}
function openShip(o){shipTarget.value=o;express.value='';expressNo.value=''}
async function doShip(){sending.value=true;const r=await orderApi.action(shipTarget.value.id,{action:'ship',express_company:express.value,express_no:expressNo.value});sending.value=false;if(r.code===0){toast('发货信息已录入 ✅');shipTarget.value=null;load()}else toast(r.msg,'error')}
onMounted(load)
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.ms{width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:9px;font-weight:700;flex-shrink:0;}
.ms-done{background:var(--blue);color:#fff;}.ms-cur{background:var(--blue);color:#fff;box-shadow:0 0 0 3px var(--blue-l);}.ms-todo{background:var(--t6);color:var(--t4);border:1px solid var(--border);}
.pagination{display:flex;align-items:center;justify-content:center;gap:12px;padding:14px;}.page-info{font-size:13px;color:var(--t3);}
.modal-ov{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center;}
.modal-box{background:#fff;border-radius:16px;width:440px;max-height:85vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden;}
.modal-hd{display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border);}
.modal-title{font-size:16px;font-weight:700;}.modal-close{background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;}
.modal-body{padding:18px 24px;overflow-y:auto;flex:1;}.modal-ft{padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px;}
</style>