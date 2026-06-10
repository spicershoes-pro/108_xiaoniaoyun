<!-- src/views/Cart.vue -->
<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header">
      <h1 class="page-title">采购清单</h1>
      <button class="btn btn-ghost btn-sm" @click="cart.clear()">清空</button>
    </div>

    <div v-if="cart.loading" class="skel" style="height:200px;border-radius:12px;" />

    <div v-else-if="cart.items.length">
      <div class="card" style="margin-bottom:16px;">
        <div class="cart-header">
          <label class="check-wrap">
            <input type="checkbox" :checked="allSelected" @change="cart.toggleAll($event.target.checked)" />
            全选
          </label>
          <span class="text-muted" style="font-size:13px;">已选 {{ selectedCount }} 件产品</span>
        </div>

        <div class="cart-item" v-for="item in cart.items" :key="item.id">
          <label class="check-wrap">
            <input type="checkbox" :checked="item._selected" @change="cart.toggleSelect(item.product_id)" />
          </label>
          <div class="ci-cover" :style="{background: item.cover_color||'#EFF6FF'}">{{ item.emoji||'🧸' }}</div>
          <div class="ci-info">
            <div class="ci-name">{{ item.name }}</div>
            <div class="text-muted" style="font-size:12px;">{{ item.merchant_name }} · MOQ {{ item.moq }}件</div>
            <div class="ci-price text-primary">¥{{ item.current_price }}/件</div>
          </div>
          <div class="ci-qty">
            <button @click="updateQty(item, -item.moq)">－</button>
            <span>{{ item.qty }}</span>
            <button @click="updateQty(item, item.moq)">＋</button>
          </div>
          <div class="ci-subtotal text-primary" style="font-weight:800;font-size:16px;">
            ¥{{ item.subtotal?.toFixed(0) }}
          </div>
          <button class="btn btn-ghost btn-sm" @click="cart.remove(item.product_id)">删除</button>
        </div>
      </div>

      <div class="cart-footer card">
        <div class="cf-info">
          <div class="text-muted" style="font-size:13px;">已选 {{ selectedCount }} 个产品</div>
          <div class="cf-total">
            合计：<span class="text-primary" style="font-size:22px;font-weight:900;">¥{{ cart.selectedTotal.toFixed(0) }}</span>
          </div>
        </div>
        <button class="btn btn-primary btn-lg" :disabled="selectedCount===0 || batchSending" @click="openBatchModal">
          📨 批量发送询盘 ({{ selectedCount }})
        </button>
      </div>
    </div>

    <div v-else class="empty-state">
      <div class="empty-icon">🛒</div>
      <div class="empty-text">采购清单为空</div>
      <router-link to="/products" class="btn btn-primary" style="margin-top:12px;">去选品</router-link>
    </div>

    <!-- 批量询盘弹窗 -->
    <div class="modal-overlay" v-if="showBatch" @click.self="showBatch=false">
      <div class="modal-box">
        <div class="modal-hd">
          <span class="modal-title">批量发送询盘</span>
          <button class="modal-close" @click="showBatch=false">✕</button>
        </div>
        <div class="modal-body">
          <p class="text-muted" style="font-size:13px;margin-bottom:12px;">
            将向 <b>{{ batchMerchants.length }}</b> 家工厂分别发送询盘（已选 {{ selectedCount }} 个 SKU）
          </p>
          <ul class="batch-merchants">
            <li v-for="m in batchMerchants" :key="m.merchant_id">
              {{ m.merchant_name }} · {{ m.items.length }} 个产品
            </li>
          </ul>
          <div class="form-group" style="margin-top:14px;">
            <label class="form-label">询盘说明</label>
            <textarea v-model="batchMsg" class="form-input" rows="4"
                      placeholder="描述采购需求、认证、交期等…" />
          </div>
        </div>
        <div class="modal-ft">
          <button class="btn btn-ghost" @click="showBatch=false">取消</button>
          <button class="btn btn-primary" :disabled="batchSending || !batchMsg.trim()" @click="submitBatch">
            {{ batchSending ? '发送中…' : '确认发送' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, inject } from 'vue'
import { useRouter } from 'vue-router'
import { useCartStore } from '@/stores/cart'
import { inquiryApi } from '@/api'

const router = useRouter()
const cart   = useCartStore()
const toast  = inject('toast', ()=>{})

const showBatch    = ref(false)
const batchMsg     = ref('您好，我们对以下产品感兴趣，请提供报价与交期，谢谢。')
const batchSending = ref(false)
const batchMerchants = ref([])

const allSelected   = computed(() => cart.items.length > 0 && cart.items.every(i => i._selected))
const selectedCount = computed(() => cart.items.filter(i => i._selected).length)

async function updateQty(item, delta) {
  const newQty = Math.max(item.moq, item.qty + delta)
  await cart.upsert(item.product_id, newQty)
}

function groupSelectedByMerchant() {
  const map = new Map()
  for (const item of cart.items.filter(i => i._selected)) {
    if (!item.merchant_id) continue
    if (!map.has(item.merchant_id)) {
      map.set(item.merchant_id, {
        merchant_id: item.merchant_id,
        merchant_name: item.merchant_name,
        items: [],
      })
    }
    map.get(item.merchant_id).items.push({
      product_id: item.product_id,
      qty: item.qty,
    })
  }
  return [...map.values()]
}

function openBatchModal() {
  const groups = groupSelectedByMerchant()
  if (!groups.length) {
    toast('请先选择产品', 'warning')
    return
  }
  batchMerchants.value = groups
  showBatch.value = true
}

async function submitBatch() {
  if (!batchMsg.value.trim()) return
  batchSending.value = true
  let ok = 0
  let fail = 0
  for (const m of batchMerchants.value) {
    const res = await inquiryApi.create({
      merchant_id: m.merchant_id,
      message: batchMsg.value.trim(),
      items: m.items,
    })
    if (res.code === 0) ok++
    else fail++
  }
  batchSending.value = false
  showBatch.value = false
  if (ok) {
    toast(fail ? `已发送 ${ok} 条询盘，${fail} 条失败` : `已向 ${ok} 家工厂发送询盘 ✅`, fail ? 'warning' : 'success')
    router.push('/inquiries')
  } else {
    toast('发送失败，请稍后重试', 'error')
  }
}

onMounted(() => cart.fetch())
</script>

<style scoped>
.cart-header{display:flex;align-items:center;gap:12px;padding:12px 16px;border-bottom:1px solid var(--t6);}
.check-wrap{display:flex;align-items:center;gap:6px;font-size:13px;cursor:pointer;}
.check-wrap input{width:16px;height:16px;cursor:pointer;}
.cart-item{display:flex;align-items:center;gap:12px;padding:14px 16px;border-bottom:1px solid var(--t6);}
.cart-item:last-child{border:none;}
.ci-cover{width:56px;height:56px;border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:28px;flex-shrink:0;}
.ci-info{flex:1;}
.ci-name{font-size:13px;font-weight:600;color:var(--t1);}
.ci-price{font-size:13px;font-weight:700;margin-top:4px;}
.ci-qty{display:flex;align-items:center;gap:8px;background:var(--t6);border-radius:8px;padding:4px 8px;}
.ci-qty button{background:none;border:none;font-size:18px;cursor:pointer;color:var(--t2);width:24px;height:24px;}
.ci-qty span{font-size:14px;font-weight:700;min-width:40px;text-align:center;}
.cart-footer{display:flex;align-items:center;justify-content:space-between;padding:16px 20px;position:sticky;bottom:0;background:#fff;box-shadow:0 -4px 16px rgba(0,0,0,.08);}
.cf-info{display:flex;flex-direction:column;gap:4px;}
.cf-total{font-size:14px;color:var(--t3);}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center;}
.modal-box{background:#fff;border-radius:16px;width:480px;max-height:85vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden;}
.modal-hd{display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border);}
.modal-title{font-size:16px;font-weight:700;}
.modal-close{background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;}
.modal-body{padding:18px 24px;overflow-y:auto;flex:1;}
.modal-ft{padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px;}
.batch-merchants{margin:0;padding-left:18px;font-size:13px;color:var(--t2);line-height:1.8;}
</style>
