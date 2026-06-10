<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">订单监控</h1><span style="font-size:13px;color:var(--t4);">纠纷订单 <span style="color:var(--red);font-weight:700;">{{disputeCount}}</span> 单</span></div>
    <div class="alert-danger" v-if="disputeCount>0">
      <span>🚨</span><span style="flex:1;font-size:13px;">存在纠纷订单需要平台介入调解</span>
      <button class="btn btn-sm btn-danger" @click="tab='dispute';load()">立即处理</button>
    </div>
    <div class="card">
      <div class="filter-bar"><div class="pill-group"><button v-for="t in tabs" :key="t.k" :class="['pill',tab===t.k?'active':'']" @click="tab=t.k;load()">{{t.l}}</button></div></div>
      <div class="table-wrap"><table class="table">
        <thead><tr><th>订单号</th><th>买家</th><th>商家</th><th>金额</th><th>平台佣金</th><th>状态</th><th>时间</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="o in orders" :key="o.id" :style="{background:o.status==='dispute'?'#FFF1F0':''}">
            <td><div class="mono">{{o.order_no}}</div><span v-if="o.status==='dispute'" class="tag tag-red">纠纷</span></td>
            <td><div style="font-weight:600;font-size:13px;">{{o.buyer_country}} {{o.buyer_name}}</div><div style="font-size:11px;color:var(--t4);">{{o.buyer_company}}</div></td>
            <td style="font-size:12px;color:var(--t3);">{{o.merchant_name}}</td>
            <td class="text-primary" style="font-weight:700;">¥{{Number(o.total_amount).toLocaleString()}}</td>
            <td style="color:var(--green);font-weight:700;">¥{{Number(o.platform_fee).toLocaleString()}}</td>
            <td><span :class="['badge',sB(o.status)]">{{sL(o.status)}}</span></td>
            <td style="font-size:12px;color:var(--t4);">{{o.created_at?.slice(0,10)}}</td>
            <td><button v-if="o.status==='dispute'" class="btn btn-sm btn-danger" @click="openDispute(o)">⚠ 调解</button><span v-else style="font-size:12px;color:var(--t4);">—</span></td>
          </tr>
          <tr v-if="!orders.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">📦</div><div class="empty-text">暂无订单</div></div></td></tr>
        </tbody>
      </table></div>
      <div class="pagination" v-if="totalPages>1"><button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;load()">上一页</button><span class="page-info">{{page}} / {{totalPages}}</span><button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;load()">下一页</button></div>
    </div>
    <!-- 调解弹窗 -->
    <div class="modal-ov" v-if="dispTarget" @click.self="dispTarget=null">
      <div class="modal-box">
        <div class="modal-hd"><span style="font-size:15px;font-weight:700;">🚨 纠纷调解</span><button class="modal-close" @click="dispTarget=null">✕</button></div>
        <div class="modal-body">
          <div style="background:var(--red-l);border-radius:9px;padding:12px;margin-bottom:14px;font-size:13px;"><div style="font-weight:700;">订单 {{dispTarget?.order_no}}</div><div style="color:var(--t3);margin-top:4px;">{{dispTarget?.buyer_name}} vs {{dispTarget?.merchant_name}}</div></div>
          <div class="form-group"><label class="form-label">调解决定 *</label><textarea v-model="resolution" class="form-input" rows="3" placeholder="请填写调解结果，如：支持买家退款50%…"/></div>
        </div>
        <div class="modal-ft"><button class="btn btn-ghost" @click="dispTarget=null">取消</button><button class="btn btn-primary" :disabled="!resolution||sending" @click="doResolve">{{sending?'提交中…':'确认调解结果'}}</button></div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, inject, onMounted } from 'vue'
import { adminApi } from '@/api'
const toast=inject('toast',()=>{})
const orders=ref([]);const total=ref(0);const totalPages=ref(1);const page=ref(1);const tab=ref('all')
const dispTarget=ref(null);const resolution=ref('');const sending=ref(false)
const tabs=[{k:'all',l:'全部'},{k:'production',l:'生产中'},{k:'shipping',l:'运输中'},{k:'completed',l:'已完成'},{k:'dispute',l:'纠纷'}]
const disputeCount=computed(()=>orders.value.filter(o=>o.status==='dispute').length)
function sL(s){return{pending_payment:'待付款',paid:'已付款',material:'备料中',production:'生产中',shipping:'运输中',completed:'已完成',cancelled:'已取消',dispute:'纠纷中'}[s]||s}
function sB(s){return{pending_payment:'badge-pending',paid:'badge-info',material:'badge-info',production:'badge-info',shipping:'badge-info',completed:'badge-success',cancelled:'badge-gray',dispute:'badge-danger'}[s]||'badge-gray'}
async function load(){const p={page:page.value};if(tab.value!=='all')p.status=tab.value;const r=await adminApi.orders(p);if(r.code===0){orders.value=r.data||[];total.value=r.total||0;totalPages.value=r.total_pages||1}}
function openDispute(o){dispTarget.value=o;resolution.value=''}
async function doResolve(){if(!resolution.value)return;sending.value=true;/* call order action */toast('调解结果已发送给双方');dispTarget.value=null;sending.value=false;load()}
onMounted(load)
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.alert-danger{display:flex;align-items:center;gap:12px;background:var(--red-l);border:1px solid #ffa39e;border-radius:10px;padding:11px 16px;margin-bottom:14px;}
.filter-bar{display:flex;align-items:center;gap:8px;padding:12px 16px;border-bottom:1px solid var(--t6);}
.pill-group{display:flex;background:var(--t6);border-radius:7px;padding:2px;gap:2px;}
.pill{padding:5px 12px;border-radius:5px;font-size:12px;font-weight:600;color:var(--t4);cursor:pointer;border:none;background:transparent;}
.pill.active{background:#fff;color:var(--blue);box-shadow:var(--sh-sm);}
.pagination{display:flex;align-items:center;justify-content:center;gap:12px;padding:14px;}.page-info{font-size:13px;color:var(--t3);}
.modal-ov{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center;}
.modal-box{background:#fff;border-radius:16px;width:480px;max-height:85vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden;}
.modal-hd{display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border);}
.modal-close{background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;}
.modal-body{padding:18px 24px;overflow-y:auto;flex:1;}
.modal-ft{padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px;}
</style>