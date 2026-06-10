<!-- src/views/Inquiries.vue -->
<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header">
      <h1 class="page-title">我的询盘</h1>
    </div>

    <div class="status-tabs card" style="margin-bottom:16px;">
      <button v-for="t in tabs" :key="t.key"
              :class="['stab', { active: activeTab===t.key }]"
              @click="activeTab=t.key; load()">{{ t.label }}</button>
    </div>

    <div v-if="loading" class="skel" style="height:300px;border-radius:12px;" />

    <div v-else class="card">
      <div class="table-wrap">
        <table class="table">
          <thead><tr>
            <th>询盘ID</th><th>商家</th><th>产品</th><th>数量</th>
            <th>优先级</th><th>状态</th><th>时间</th><th>操作</th>
          </tr></thead>
          <tbody>
            <tr v-for="inq in inquiries" :key="inq.id">
              <td class="mono">{{ inq.id.slice(-8) }}</td>
              <td style="font-weight:600;">{{ inq.merchant_name }}</td>
              <td style="max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {{ inq.items?.[0]?.product_name }}
                <span v-if="inq.items?.length>1" class="text-muted">+{{ inq.items.length-1 }}</span>
              </td>
              <td class="text-primary">{{ inq.items?.reduce((s,i)=>s+i.qty,0)?.toLocaleString() }} 件</td>
              <td>
                <span :class="['tag', {'tag-red':inq.priority==='high','tag-orange':inq.priority==='medium','tag-gray':inq.priority==='low'}]">
                  {{ {high:'高',medium:'中',low:'低'}[inq.priority] }}
                </span>
              </td>
              <td>
                <span :class="['badge', statusBadge(inq.status)]">{{ statusLabel(inq.status) }}</span>
              </td>
              <td class="text-muted" style="font-size:12px;">{{ inq.created_at?.slice(0,10) }}</td>
              <td>
                <div style="display:flex;gap:6px;">
                  <router-link :to="`/inquiries/${inq.id}`" class="btn btn-sm btn-outline">详情</router-link>
                  <button v-if="['quoted','negotiating'].includes(inq.status)" class="btn btn-sm btn-primary" @click="toOrder(inq)">下单</button>
                </div>
              </td>
            </tr>
            <tr v-if="!inquiries.length">
              <td colspan="8"><div class="empty-state"><div class="empty-icon">📭</div><div class="empty-text">暂无询盘</div></div></td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { inquiryApi, orderApi } from '@/api'
const router = useRouter()
const toast  = inject('toast', ()=>{})
const inquiries = ref([])
const loading   = ref(false)
const activeTab = ref('all')
const tabs = [
  {key:'all',label:'全部'},{key:'pending',label:'待回复'},
  {key:'quoted',label:'已报价'},{key:'negotiating',label:'洽谈中'},{key:'closed',label:'已关闭'}
]
function statusLabel(s){ return {pending:'待回复',quoted:'已报价',negotiating:'洽谈中',converted:'已下单',closed:'已关闭'}[s]||s }
function statusBadge(s){ return {pending:'badge-pending',quoted:'badge-info',negotiating:'badge-info',converted:'badge-success',closed:'badge-gray'}[s]||'badge-gray' }
async function load(){
  loading.value=true
  const res = await inquiryApi.list(activeTab.value!=='all'?{status:activeTab.value}:{})
  loading.value=false
  if(res.code===0) inquiries.value = res.data||[]
}
async function toOrder(inq){
  const res = await orderApi.create({inquiry_id: inq.id})
  if(res.code===0){ toast('订单已创建！'); router.push('/orders') }
  else toast(res.msg,'error')
}
onMounted(load)
</script>

<style scoped>
.status-tabs{display:flex;padding:4px;gap:4px;}
.stab{padding:8px 16px;border-radius:8px;border:none;background:transparent;font-size:13px;font-weight:500;color:var(--t4);cursor:pointer;transition:all .15s;}
.stab:hover{color:var(--t2);}
.stab.active{background:var(--blue-xl);color:var(--blue);font-weight:700;}
</style>
