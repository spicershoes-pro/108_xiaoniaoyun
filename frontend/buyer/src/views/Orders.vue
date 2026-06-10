<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header">
      <h1 class="page-title">我的订单</h1>
    </div>

    <!-- 状态筛选 -->
    <div class="status-tabs card" style="margin-bottom:16px;">
      <button v-for="t in tabs" :key="t.key"
              :class="['stab', { active: activeTab === t.key }]"
              @click="activeTab = t.key; page = 1; load()">
        {{ t.label }}
      </button>
    </div>

    <!-- 列表 -->
    <div v-if="loading" class="loading-wrap">
      <div v-for="i in 3" :key="i" class="skel order-skel" />
    </div>

    <div v-else-if="orders.length" class="order-list">
      <div v-for="o in orders" :key="o.id" class="order-card card">
        <div class="oc-header">
          <span class="mono">{{ o.order_no }}</span>
          <span class="text-muted" style="font-size:12px;">{{ o.created_at?.slice(0,10) }}</span>
          <span :class="['badge', statusBadge(o.status)]" style="margin-left:auto;">{{ statusLabel(o.status) }}</span>
        </div>

        <!-- 进度条 -->
        <div class="oc-steps">
          <template v-for="(step, i) in stepLabels" :key="i">
            <div :class="['step-node', stepClass(o.step, i+1)]">
              {{ o.step > i+1 ? '✓' : i+1 }}
            </div>
            <div v-if="i < stepLabels.length-1" :class="['step-line', o.step > i+1 ? 'step-line-done' : '']" />
          </template>
        </div>
        <div class="step-names">
          <span v-for="l in stepLabels" :key="l">{{ l }}</span>
        </div>

        <!-- 产品 -->
        <div class="oc-items">
          <div v-for="item in o.items" :key="item.id" class="oc-item">
            <span class="item-em">{{ item.emoji || '🧸' }}</span>
            <div class="item-info">
              <div class="item-name">{{ item.product_name }}</div>
              <div class="text-muted" style="font-size:12px;">× {{ item.qty }} 件</div>
            </div>
            <div class="item-price text-primary">¥{{ Number(item.unit_price).toFixed(2) }}/件</div>
          </div>
        </div>

        <div class="oc-footer">
          <div>
            <span class="text-muted">商家：</span>{{ o.merchant_name }}
            <span v-if="o.express_no" class="text-muted" style="margin-left:12px;">
              快递：{{ o.express_company }} {{ o.express_no }}
            </span>
          </div>
          <div class="oc-total">
            合计 <span class="text-primary" style="font-size:18px;font-weight:800;">¥{{ Number(o.total_amount).toLocaleString() }}</span>
          </div>
        </div>

        <div class="oc-actions">
          <router-link :to="`/orders/${o.id}`" class="btn btn-outline btn-sm">订单详情</router-link>
          <button v-if="o.status === 'pending_payment'" class="btn btn-primary btn-sm" @click="doPay(o)">立即付款</button>
          <button v-if="o.status === 'shipping'" class="btn btn-primary btn-sm" @click="doConfirm(o)">确认收货</button>
          <button v-if="['shipping','delivered'].includes(o.status)" class="btn btn-ghost btn-sm" @click="doDispute(o)">发起纠纷</button>
          <router-link to="/products" v-if="o.status === 'completed'" class="btn btn-ghost btn-sm">再次下单</router-link>
        </div>
      </div>
    </div>

    <div v-else class="empty-state">
      <div class="empty-icon">📦</div>
      <div class="empty-text">暂无订单</div>
      <router-link to="/products" class="btn btn-primary" style="margin-top:12px;">去选品</router-link>
    </div>

    <!-- 分页 -->
    <div class="pagination" v-if="totalPages > 1">
      <button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;load()">上一页</button>
      <span class="page-info">{{ page }} / {{ totalPages }}</span>
      <button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;load()">下一页</button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, inject } from 'vue'
import { orderApi } from '@/api'

const toast = inject('toast', () => {})
const orders     = ref([])
const loading    = ref(false)
const activeTab  = ref('all')
const page       = ref(1)
const totalPages = ref(1)

const tabs = [
  { key: 'all',             label: '全部' },
  { key: 'pending_payment', label: '待付款' },
  { key: 'production',      label: '生产中' },
  { key: 'shipping',        label: '运输中' },
  { key: 'completed',       label: '已完成' },
]

const stepLabels = ['下单','付款','备料','生产','运输','完成']

function stepClass(step, i) {
  if (step > i)  return 'step-done'
  if (step === i) return 'step-current'
  return 'step-todo'
}

function statusLabel(s) {
  return { pending_payment:'待付款', paid:'已付款', material:'备料中', production:'生产中', shipping:'运输中', delivered:'已送达', completed:'已完成', cancelled:'已取消', dispute:'纠纷中' }[s] || s
}

function statusBadge(s) {
  const m = { pending_payment:'badge-pending', paid:'badge-info', material:'badge-info', production:'badge-info', shipping:'badge-info', completed:'badge-success', cancelled:'badge-gray', dispute:'badge-danger' }
  return m[s] || 'badge-gray'
}

async function load() {
  loading.value = true
  const params = { page: page.value }
  if (activeTab.value !== 'all') params.status = activeTab.value
  const res = await orderApi.list(params)
  loading.value = false
  if (res.code === 0) {
    orders.value     = res.data || []
    totalPages.value = res.total_pages || 1
  }
}

async function doPay(o) {
  const res = await orderApi.action(o.id, { action: 'pay', deposit_ratio: 0.5 })
  if (res.code === 0) { toast('付款成功！已付50%定金'); load() }
  else toast(res.msg, 'error')
}

async function doConfirm(o) {
  const res = await orderApi.action(o.id, { action: 'confirm_receipt' })
  if (res.code === 0) { toast('已确认收货，订单完成 ✅'); load() }
  else toast(res.msg, 'error')
}

async function doDispute(o) {
  const reason = prompt('请描述纠纷原因（至少5个字）：')
  if (!reason || reason.length < 5) return
  const res = await orderApi.action(o.id, { action: 'dispute', reason })
  if (res.code === 0) { toast('纠纷已发起，平台将在3个工作日内介入处理'); load() }
  else toast(res.msg, 'error')
}

onMounted(load)
</script>

<style scoped>
.status-tabs { display: flex; padding: 4px; gap: 4px; }
.stab { padding: 8px 16px; border-radius: 8px; border: none; background: transparent; font-size: 13px; font-weight: 500; color: var(--t4); cursor: pointer; transition: all .15s; }
.stab:hover  { color: var(--t2); }
.stab.active { background: var(--blue-xl); color: var(--blue); font-weight: 700; }

.loading-wrap { display: flex; flex-direction: column; gap: 14px; }
.order-skel   { height: 220px; border-radius: var(--r12); }

.order-list { display: flex; flex-direction: column; gap: 14px; }
.order-card { overflow: visible; }

.oc-header  { display: flex; align-items: center; gap: 10px; padding: 14px 16px; border-bottom: 1px solid var(--t6); }
.oc-steps   { display: flex; align-items: center; padding: 16px 20px 4px; }
.step-names { display: flex; padding: 0 20px 10px; }
.step-names span { flex: 1; text-align: center; font-size: 10px; color: var(--t4); }

.oc-items { padding: 0 16px; }
.oc-item  { display: flex; align-items: center; gap: 10px; padding: 10px 0; border-bottom: 1px solid var(--t6); }
.oc-item:last-child { border: none; }
.item-em   { font-size: 28px; flex-shrink: 0; }
.item-info { flex: 1; }
.item-name { font-size: 13px; font-weight: 600; color: var(--t1); }
.item-price{ font-weight: 700; }

.oc-footer  { display: flex; justify-content: space-between; align-items: center; padding: 12px 16px; background: var(--bg0); font-size: 13px; color: var(--t3); }
.oc-total   { font-size: 13px; color: var(--t3); }
.oc-actions { display: flex; gap: 8px; padding: 12px 16px; justify-content: flex-end; }

.pagination { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 24px; }
.page-info  { font-size: 13px; color: var(--t3); }
</style>
