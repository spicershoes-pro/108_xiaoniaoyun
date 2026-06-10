<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;" v-if="order">
    <div class="breadcrumb">
      <router-link to="/orders">我的订单</router-link> / <span>{{ order.order_no }}</span>
    </div>

    <!-- 状态进度 -->
    <div class="card card-body" style="margin-bottom:16px;">
      <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:20px;">
        <div>
          <div class="page-title">订单 {{ order.order_no }}</div>
          <div class="text-muted" style="font-size:12px;margin-top:4px;">下单时间：{{ order.created_at?.slice(0,16).replace('T',' ') }}</div>
        </div>
        <span :class="['badge', statusBadge(order.status)]" style="font-size:13px;padding:6px 14px;">{{ statusLabel(order.status) }}</span>
      </div>
      <div class="steps">
        <template v-for="(step, i) in stepConfig" :key="i">
          <div :class="['step-node', stepClass(order.step, i+1)]">{{ order.step > i+1 ? '✓' : i+1 }}</div>
          <div v-if="i < stepConfig.length-1" :class="['step-line', order.step > i+1 ? 'step-line-done':'']" />
        </template>
      </div>
      <div style="display:flex;margin-top:6px;">
        <div v-for="s in stepConfig" :key="s.label" style="flex:1;text-align:center;font-size:11px;color:var(--t4);">{{ s.label }}</div>
      </div>
    </div>

    <div style="display:grid;grid-template-columns:1fr 360px;gap:16px;">
      <!-- 左：产品 + 状态日志 -->
      <div>
        <div class="card" style="margin-bottom:14px;">
          <div class="card-header"><span class="card-title">产品明细</span></div>
          <div v-for="item in order.items" :key="item.id" style="display:flex;gap:12px;align-items:center;padding:14px 16px;border-bottom:1px solid var(--t6);">
            <div :style="{width:'48px',height:'48px',borderRadius:'10px',background:item.cover_color||'#EFF6FF',display:'flex',alignItems:'center',justifyContent:'center',fontSize:'24px',flexShrink:0}">{{ item.emoji||'🧸' }}</div>
            <div style="flex:1;"><div style="font-size:13px;font-weight:600;color:var(--t1);">{{ item.product_name }}</div><div style="font-size:12px;color:var(--t4);">× {{ item.qty }} 件</div></div>
            <div style="text-align:right;"><div class="text-primary" style="font-weight:700;">¥{{ Number(item.unit_price).toFixed(2) }}/件</div><div style="font-size:12px;font-weight:700;color:var(--t1);">¥{{ Number(item.subtotal).toLocaleString() }}</div></div>
          </div>
        </div>

        <div class="card">
          <div class="card-header"><span class="card-title">状态记录</span></div>
          <div style="padding:16px;">
            <div v-for="log in order.status_logs" :key="log.id" class="log-item">
              <div class="log-dot"></div>
              <div style="flex:1;"><div style="font-size:13px;font-weight:600;color:var(--t1);">{{ log.note || log.to_status }}</div><div style="font-size:11px;color:var(--t4);margin-top:2px;">{{ log.created_at?.slice(0,16).replace('T',' ') }}</div></div>
            </div>
          </div>
        </div>
      </div>

      <!-- 右：汇总 + 操作 -->
      <div>
        <div class="card card-body" style="margin-bottom:14px;">
          <div class="card-title" style="margin-bottom:12px;">订单汇总</div>
          <div v-for="r in summaryRows" :key="r[0]" style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid var(--t6);">
            <span style="font-size:13px;color:var(--t4);">{{ r[0] }}</span>
            <span :style="{fontSize:'13px',fontWeight:r[2]?700:500,color:r[2]?'var(--blue)':'var(--t1)'}">{{ r[1] }}</span>
          </div>
        </div>

        <div class="card card-body" style="margin-bottom:14px;" v-if="order.express_no">
          <div class="card-title" style="margin-bottom:10px;">📦 物流信息</div>
          <div style="font-size:13px;"><span style="color:var(--t4);">快递公司：</span><span style="font-weight:600;">{{ order.express_company }}</span></div>
          <div style="font-size:13px;margin-top:6px;"><span style="color:var(--t4);">快递单号：</span><span style="font-weight:600;font-family:monospace;">{{ order.express_no }}</span></div>
          <div style="font-size:12px;color:var(--t4);margin-top:6px;">{{ order.shipped_at?.slice(0,10) }} 发出</div>
        </div>

        <div class="card card-body">
          <div class="card-title" style="margin-bottom:12px;">可执行操作</div>
          <div style="display:flex;flex-direction:column;gap:8px;">
            <button v-if="order.status==='pending_payment'" class="btn btn-primary btn-full" @click="doAction('pay')">💳 立即付款（50%定金）</button>
            <button v-if="order.status==='shipping'" class="btn btn-primary btn-full" @click="doAction('confirm_receipt')">✅ 确认收货</button>
            <button v-if="['shipping','delivered'].includes(order.status)" class="btn btn-ghost btn-full" @click="doDispute">⚠️ 发起纠纷</button>
            <button v-if="['pending_payment','paid'].includes(order.status)" class="btn btn-ghost btn-full" @click="doAction('cancel')">取消订单</button>
            <router-link to="/orders" class="btn btn-ghost btn-full" style="text-align:center;">返回订单列表</router-link>
          </div>
        </div>
      </div>
    </div>
  </div>
  <div v-else-if="!loading" class="empty-state" style="margin-top:60px;">
    <div class="empty-icon">😕</div><div class="empty-text">订单不存在</div>
    <router-link to="/orders" class="btn btn-primary" style="margin-top:12px;">返回订单列表</router-link>
  </div>
</template>
<script setup>
import { ref, computed, inject, onMounted } from 'vue'
import { useRoute } from 'vue-router'
import { orderApi } from '@/api'
const route=useRoute(); const toast=inject('toast',()=>{})
const order=ref(null); const loading=ref(true)
const stepConfig=[{label:'下单'},{label:'付款'},{label:'备料'},{label:'生产'},{label:'运输'},{label:'完成'}]
function statusLabel(s){return{pending_payment:'待付款',paid:'已付款',material:'备料中',production:'生产中',shipping:'运输中',delivered:'已送达',completed:'已完成',cancelled:'已取消',dispute:'纠纷中'}[s]||s}
function statusBadge(s){return{pending_payment:'badge-pending',paid:'badge-info',material:'badge-info',production:'badge-info',shipping:'badge-info',completed:'badge-success',cancelled:'badge-gray',dispute:'badge-danger'}[s]||'badge-gray'}
function stepClass(step,i){return step>i?'step-done':step===i?'step-current':'step-todo'}
const summaryRows=computed(()=>{
  const o=order.value; if(!o) return []
  return [['商家',o.merchant_name],['产品件数',`${o.items?.reduce((s,i)=>s+i.qty,0)||0} 件`],['订单总额','¥'+Number(o.total_amount).toLocaleString(),true],['已付定金','¥'+Number(o.deposit).toLocaleString()],['截止日期',o.deadline||'—'],['创建时间',o.created_at?.slice(0,10)]]
})
async function doAction(action){ const r=await orderApi.action(order.value.id,{action}); if(r.code===0){toast('操作成功 ✅');loadOrder()}else toast(r.msg,'error') }
async function doDispute(){ const reason=prompt('请描述纠纷原因（至少5字）：'); if(!reason||reason.length<5) return; const r=await orderApi.action(order.value.id,{action:'dispute',reason}); if(r.code===0){toast('纠纷已发起');loadOrder()}else toast(r.msg,'error') }
async function loadOrder(){ const r=await orderApi.detail(route.params.id); loading.value=false; if(r.code===0)order.value=r.data }
onMounted(loadOrder)
</script>
<style scoped>
.breadcrumb{font-size:13px;color:var(--t4);margin-bottom:20px;} .breadcrumb a{color:var(--t4);text-decoration:none;} .breadcrumb a:hover{color:var(--blue);}
.log-item{display:flex;gap:12px;align-items:flex-start;padding-bottom:14px;position:relative;}
.log-item:not(:last-child)::before{content:'';position:absolute;left:5px;top:14px;bottom:0;width:2px;background:var(--t6);}
.log-dot{width:12px;height:12px;border-radius:50%;background:var(--blue);flex-shrink:0;margin-top:2px;}
</style>