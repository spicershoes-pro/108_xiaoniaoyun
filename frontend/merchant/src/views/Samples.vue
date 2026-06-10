<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">样品管理</h1><span style="font-size:13px;color:var(--t4);">共 {{ total }} 个样品申请</span></div>
    <div class="filter-bar card" style="margin-bottom:14px;display:flex;gap:6px;padding:10px 14px;">
      <button v-for="t in tabs" :key="t.k" :class="['btn btn-sm',tab===t.k?'btn-primary':'btn-ghost']" @click="tab=t.k;load()">{{t.l}}</button>
    </div>
    <div class="card">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>产品</th><th>买家</th><th>数量</th><th>收件信息</th><th>快递信息</th><th>状态</th><th>申请时间</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="s in samples" :key="s.id">
            <td><div style="display:flex;gap:8px;align-items:center;"><span style="font-size:20px;">{{s.emoji||'🧸'}}</span><div style="font-size:13px;font-weight:600;color:var(--t1);">{{s.product_name}}</div></div></td>
            <td><div style="font-weight:600;font-size:13px;">{{s.buyer_name}}</div><div style="font-size:11px;color:var(--t4);">{{s.buyer_company}} · {{s.country}}</div></td>
            <td style="font-weight:700;">{{s.qty}} 件</td>
            <td style="font-size:12px;color:var(--t3);">
              <div>{{s.recipient_name}}</div>
              <div class="text-muted" style="font-size:11px;max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{s.recipient_address}}</div>
            </td>
            <td style="font-size:12px;color:var(--t3);">{{ s.express_company?`${s.express_company} ${s.express_no}`:'—' }}</td>
            <td><span :class="['badge',{pending:'badge-pending',processing:'badge-info',shipped:'badge-info',delivered:'badge-success',rejected:'badge-danger'}[s.status]||'badge-gray']">{{sL(s.status)}}</span></td>
            <td style="font-size:11px;color:var(--t4);">{{s.created_at?.slice(0,10)}}</td>
            <td>
              <div style="display:flex;gap:5px;flex-wrap:wrap;">
                <button v-if="s.status==='pending'"    class="btn btn-sm btn-outline" @click="act(s,'process')">受理</button>
                <button v-if="s.status==='processing'" class="btn btn-sm btn-primary" @click="openShip(s)">发货</button>
                <button v-if="s.status==='pending'"    class="btn btn-sm btn-danger"  @click="act(s,'reject')">拒绝</button>
              </div>
            </td>
          </tr>
          <tr v-if="!samples.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">🎁</div><div class="empty-text">暂无样品申请</div></div></td></tr>
        </tbody>
      </table></div>
    </div>

    <!-- 发货弹窗 -->
    <div class="modal-ov" v-if="shipTarget" @click.self="shipTarget=null">
      <div class="modal-box">
        <div class="modal-hd"><span class="modal-title">样品发货</span><button class="modal-close" @click="shipTarget=null">✕</button></div>
        <div class="modal-body">
          <div style="background:var(--bg0);border-radius:10px;padding:12px;margin-bottom:14px;font-size:13px;"><div style="font-weight:700;">{{shipTarget?.product_name}}</div><div class="text-muted">收件：{{shipTarget?.recipient_name}} · {{shipTarget?.recipient_phone}}</div></div>
          <div class="form-group"><label class="form-label">快递公司 *</label><select v-model="express" class="form-input form-select"><option value="">请选择</option><option v-for="e in expressList" :key="e">{{e}}</option></select></div>
          <div class="form-group"><label class="form-label">快递单号 *</label><input v-model="expressNo" class="form-input" placeholder="请输入快递单号"/></div>
        </div>
        <div class="modal-ft"><button class="btn btn-ghost" @click="shipTarget=null">取消</button><button class="btn btn-primary" :disabled="!express||!expressNo||sending" @click="doShip">{{sending?'提交中…':'确认发货'}}</button></div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { sampleApi } from '@/api'
const toast=inject('toast',()=>{})
const samples=ref([]);const total=ref(0);const tab=ref('all');const shipTarget=ref(null);const express=ref('');const expressNo=ref('');const sending=ref(false)
const tabs=[{k:'all',l:'全部'},{k:'pending',l:'待处理'},{k:'processing',l:'处理中'},{k:'shipped',l:'已发货'},{k:'delivered',l:'已签收'}]
const expressList=['顺丰国际','DHL','FedEx','UPS','EMS','中通国际']
function sL(s){return{pending:'待处理',processing:'处理中',shipped:'已发货',delivered:'已签收',rejected:'已拒绝'}[s]||s}
async function load(){const p=tab.value!=='all'?{status:tab.value}:{};const r=await sampleApi.list(p);if(r.code===0){samples.value=r.data||[];total.value=r.total||0}}
async function act(s,action){const r=await sampleApi.update(s.id,{action});if(r.code===0){toast('操作成功');load()}else toast(r.msg,'error')}
function openShip(s){shipTarget.value=s;express.value='';expressNo.value=''}
async function doShip(){sending.value=true;const r=await sampleApi.update(shipTarget.value.id,{action:'ship',express_company:express.value,express_no:expressNo.value});sending.value=false;if(r.code===0){toast('样品已发货 ✅');shipTarget.value=null;load()}else toast(r.msg,'error')}
onMounted(load)
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.modal-ov{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center;}
.modal-box{background:#fff;border-radius:16px;width:440px;max-height:85vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden;}
.modal-hd{display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border);}
.modal-title{font-size:16px;font-weight:700;}.modal-close{background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;}
.modal-body{padding:18px 24px;overflow-y:auto;flex:1;}.modal-ft{padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px;}
</style>