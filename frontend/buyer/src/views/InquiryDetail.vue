<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;" v-if="inquiry">
    <div class="breadcrumb"><router-link to="/inquiries">我的询盘</router-link> / <span>{{ inquiry.id?.slice(-8) }}</span></div>
    <div style="display:grid;grid-template-columns:1fr 340px;gap:16px;">
      <!-- 左 -->
      <div>
        <div class="card card-body" style="margin-bottom:14px;">
          <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:16px;">
            <div><div style="font-size:18px;font-weight:800;color:var(--t1);">询盘详情</div><div class="text-muted" style="font-size:12px;">{{ inquiry.created_at?.slice(0,16).replace('T',' ') }}</div></div>
            <span :class="['badge',sB(inquiry.status)]" style="font-size:13px;padding:6px 14px;">{{ sL(inquiry.status) }}</span>
          </div>
          <div style="background:var(--bg0);border-radius:10px;padding:14px;margin-bottom:14px;">
            <div style="font-size:13px;font-weight:600;color:var(--t4);margin-bottom:6px;">我的询盘内容</div>
            <div style="font-size:14px;color:var(--t1);line-height:1.7;">{{ inquiry.message }}</div>
            <div v-if="inquiry.budget" style="margin-top:8px;font-size:13px;"><span style="color:var(--t4);">目标价格：</span><span style="font-weight:600;color:var(--blue);">{{ inquiry.budget }}</span></div>
          </div>
          <div v-if="inquiry.quote_price" style="background:var(--green-l);border:1px solid #b7eb8f;border-radius:10px;padding:14px;">
            <div style="font-size:13px;font-weight:700;color:#389E0D;margin-bottom:6px;">📋 商家报价</div>
            <div style="font-size:16px;font-weight:800;color:var(--t1);">{{ inquiry.quote_price }}</div>
            <div v-if="inquiry.quote_note" style="font-size:13px;color:var(--t3);margin-top:6px;line-height:1.6;">{{ inquiry.quote_note }}</div>
            <div style="font-size:11px;color:#389E0D;margin-top:8px;">报价时间：{{ inquiry.quoted_at?.slice(0,16).replace('T',' ') }}</div>
          </div>
          <div v-else-if="inquiry.status==='pending'" style="background:var(--orange-l);border:1px solid #ffd591;border-radius:10px;padding:12px;text-align:center;font-size:13px;color:#D46B08;">
            ⏳ 等待商家回复中，通常在 24 小时内响应
          </div>
        </div>

        <!-- 产品明细 -->
        <div class="card">
          <div class="card-header"><span class="card-title">询盘产品</span></div>
          <div v-for="item in inquiry.items" :key="item.id" style="display:flex;gap:12px;align-items:center;padding:14px 16px;border-bottom:1px solid var(--t6);">
            <div :style="{width:'44px',height:'44px',borderRadius:'9px',background:item.cover_color||'#EFF6FF',display:'flex',alignItems:'center',justifyContent:'center',fontSize:'22px',flexShrink:0}">{{ item.emoji||'🧸' }}</div>
            <div style="flex:1;"><div style="font-size:13px;font-weight:600;color:var(--t1);">{{ item.product_name }}</div><div style="font-size:12px;color:var(--t4);">¥{{ item.base_price }}/件</div></div>
            <div class="text-primary" style="font-size:15px;font-weight:800;">× {{ item.qty?.toLocaleString() }} 件</div>
          </div>
        </div>
      </div>

      <!-- 右 -->
      <div>
        <div class="card card-body" style="margin-bottom:14px;">
          <div class="card-title" style="margin-bottom:12px;">商家信息</div>
          <div style="display:flex;gap:10px;align-items:center;margin-bottom:12px;">
            <div style="width:40px;height:40px;border-radius:10px;background:var(--blue-xl);display:flex;align-items:center;justify-content:center;font-size:20px;flex-shrink:0;">🏭</div>
            <div><div style="font-size:14px;font-weight:700;">{{ inquiry.merchant_name }}</div><div style="font-size:12px;color:var(--t4);">响应时间：{{ inquiry.response_time||'—' }}</div></div>
          </div>
          <button class="btn btn-outline btn-full" @click="toMsg">💬 发消息给商家</button>
        </div>

        <div class="card card-body">
          <div class="card-title" style="margin-bottom:12px;">可执行操作</div>
          <div style="display:flex;flex-direction:column;gap:8px;">
            <button v-if="['quoted','negotiating'].includes(inquiry.status)" class="btn btn-primary btn-full" @click="toOrder">📦 确认报价并下单</button>
            <button v-if="['pending','quoted','negotiating'].includes(inquiry.status)" class="btn btn-ghost btn-full" @click="doClose">关闭询盘</button>
            <router-link to="/inquiries" class="btn btn-ghost btn-full" style="text-align:center;">返回询盘列表</router-link>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { inquiryApi, orderApi } from '@/api'
import { openChat } from '@/utils/chat'
const route=useRoute(); const router=useRouter(); const toast=inject('toast',()=>{})
const inquiry=ref(null)
function sL(s){return{pending:'待回复',quoted:'已报价',negotiating:'洽谈中',converted:'已下单',closed:'已关闭'}[s]||s}
function sB(s){return{pending:'badge-pending',quoted:'badge-info',negotiating:'badge-info',converted:'badge-success',closed:'badge-gray'}[s]||'badge-gray'}
async function doClose(){ const r=await inquiryApi.update(inquiry.value.id,{action:'close'}); if(r.code===0){toast('询盘已关闭');loadData()}else toast(r.msg,'error') }
async function toOrder(){ const r=await orderApi.create({inquiry_id:inquiry.value.id}); if(r.code===0){toast('订单已创建！');router.push('/orders')}else toast(r.msg,'error') }
async function toMsg(){ await openChat(inquiry.value?.merchant_user_id, toast) }
async function loadData(){ const r=await inquiryApi.detail(route.params.id); if(r.code===0)inquiry.value=r.data }
onMounted(loadData)
</script>
<style scoped>
.breadcrumb{font-size:13px;color:var(--t4);margin-bottom:20px;}.breadcrumb a{color:var(--t4);text-decoration:none;}.breadcrumb a:hover{color:var(--blue);}
</style>