<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header"><h1 class="page-title">样品申请</h1><button class="btn btn-primary" @click="showForm=true">+ 新申请</button></div>
    <div class="status-tabs card" style="margin-bottom:16px;display:flex;padding:4px;gap:4px;">
      <button v-for="t in tabs" :key="t.k" :class="['stab',tab===t.k?'active':'']" @click="tab=t.k;load()">{{t.l}}</button>
    </div>
    <div v-if="loading" class="skel" style="height:200px;border-radius:12px;"/>
    <div v-else-if="list.length" class="card">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>产品</th><th>商家</th><th>数量</th><th>费用</th><th>快递信息</th><th>状态</th><th>申请时间</th></tr></thead>
        <tbody>
          <tr v-for="s in list" :key="s.id">
            <td><div style="display:flex;gap:8px;align-items:center;"><span style="font-size:22px;">{{s.emoji||'🧸'}}</span><div><div style="font-weight:600;font-size:13px;">{{s.product_name}}</div></div></div></td>
            <td style="font-size:12px;color:var(--t3);">{{s.merchant_name}}</td>
            <td style="font-weight:600;">{{s.qty}} 件</td>
            <td class="text-primary" style="font-weight:700;">¥{{s.fee}}</td>
            <td style="font-size:12px;color:var(--t3);">{{s.express_company?`${s.express_company} ${s.express_no}`:'—'}}</td>
            <td><span :class="['badge',{pending:'badge-pending',processing:'badge-info',shipped:'badge-info',delivered:'badge-success',rejected:'badge-danger'}[s.status]||'badge-gray']">{{sL(s.status)}}</span></td>
            <td style="font-size:11px;color:var(--t4);">{{s.created_at?.slice(0,10)}}</td>
          </tr>
        </tbody>
      </table></div>
    </div>
    <div v-else class="empty-state"><div class="empty-icon">🎁</div><div class="empty-text">暂无样品申请</div></div>

    <!-- 申请弹窗 -->
    <div class="modal-overlay" v-if="showForm" @click.self="showForm=false">
      <div class="modal-box">
        <div class="modal-hd"><span class="modal-title">申请样品</span><button class="modal-close" @click="showForm=false">✕</button></div>
        <div class="modal-body">
          <div class="form-group"><label class="form-label">产品ID *</label><input v-model="form.product_id" class="form-input" placeholder="从产品详情页获取"/></div>
          <div class="form-group"><label class="form-label">商家ID *</label><input v-model="form.merchant_id" class="form-input" placeholder=""/></div>
          <div class="form-group"><label class="form-label">申请数量</label><input v-model.number="form.qty" type="number" min="1" class="form-input"/></div>
          <div class="form-group"><label class="form-label">收件人 *</label><input v-model="form.recipient_name" class="form-input" placeholder="收件人姓名"/></div>
          <div class="form-group"><label class="form-label">联系电话 *</label><input v-model="form.recipient_phone" class="form-input" placeholder=""/></div>
          <div class="form-group"><label class="form-label">收件地址 *</label><textarea v-model="form.recipient_address" class="form-input" rows="2" placeholder="详细收件地址"/></div>
          <div class="form-group"><label class="form-label">备注</label><input v-model="form.note" class="form-input" placeholder="特殊要求（选填）"/></div>
        </div>
        <div class="modal-ft">
          <button class="btn btn-ghost" @click="showForm=false">取消</button>
          <button class="btn btn-primary" :disabled="submitting" @click="doSubmit">{{submitting?'提交中…':'提交申请'}}</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, reactive, inject, onMounted } from 'vue'
import { sampleApi } from '@/api'
const toast=inject('toast',()=>{})
const list=ref([]); const loading=ref(false); const tab=ref('all'); const showForm=ref(false); const submitting=ref(false)
const tabs=[{k:'all',l:'全部'},{k:'pending',l:'待处理'},{k:'shipped',l:'已发货'},{k:'delivered',l:'已签收'}]
const form=reactive({product_id:'',merchant_id:'',qty:1,recipient_name:'',recipient_phone:'',recipient_address:'',note:''})
function sL(s){return{pending:'待处理',processing:'处理中',shipped:'已发货',delivered:'已签收',rejected:'已拒绝'}[s]||s}
async function load(){ loading.value=true; const r=await sampleApi.list(tab.value!=='all'?{status:tab.value}:{}); loading.value=false; if(r.code===0)list.value=r.data||[] }
async function doSubmit(){
  if(!form.product_id||!form.recipient_name||!form.recipient_phone||!form.recipient_address){toast('请填写必填项','warning');return}
  submitting.value=true; const r=await sampleApi.create({...form}); submitting.value=false
  if(r.code===0){toast('样品申请已提交 ✅');showForm.value=false;load()}else toast(r.msg,'error')
}
onMounted(load)
</script>
<style scoped>
.stab{padding:8px 16px;border-radius:8px;border:none;background:transparent;font-size:13px;font-weight:500;color:var(--t4);cursor:pointer;transition:all .15s;}
.stab.active{background:var(--blue-xl);color:var(--blue);font-weight:700;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center;}
.modal-box{background:#fff;border-radius:16px;width:480px;max-height:88vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden;}
.modal-hd{display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border);}
.modal-title{font-size:16px;font-weight:700;}.modal-close{background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;}
.modal-body{padding:18px 24px;overflow-y:auto;flex:1;}.modal-ft{padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px;}
</style>