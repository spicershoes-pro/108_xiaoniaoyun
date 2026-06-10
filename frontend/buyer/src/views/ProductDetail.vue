<template>
  <div class="detail-page" v-if="product">
    <div class="page-container">
      <div class="breadcrumb">
        <router-link to="/">首页</router-link> /
        <router-link to="/products">选品中心</router-link> /
        <span>{{ product.name }}</span>
      </div>

      <div class="detail-main">
        <!-- 左侧：产品封面 -->
        <div class="detail-cover" :style="{ background: product.cover_color || '#EFF6FF' }">
          <span class="cover-emoji">{{ product.emoji || '🧸' }}</span>
        </div>

        <!-- 右侧：产品信息 -->
        <div class="detail-info">
          <div class="di-tags">
            <span v-for="c in product.certs" :key="c" class="tag tag-green">{{ c }}</span>
            <span class="tag tag-blue" v-if="product.status === 'online'">在售</span>
          </div>

          <h1 class="di-name">{{ product.name }}</h1>

          <div class="di-meta">
            <span class="star-gold">{{ '★'.repeat(Math.round(product.rating || 0)) }}</span>
            <span class="text-muted">{{ product.rating }} ({{ product.review_count }}条评价)</span>
            <span class="text-muted">· 销量 {{ fmtNum(product.sales_count) }}</span>
          </div>

          <!-- 价格 -->
          <div class="price-block">
            <span class="price-big">¥{{ currentPrice }}</span>
            <span class="price-unit">/件起 · MOQ {{ product.moq }}件</span>
          </div>

          <!-- 阶梯价 -->
          <div class="tier-grid" v-if="product.price_tiers?.length">
            <div v-for="t in product.price_tiers" :key="t.min_qty"
                 :class="['tier-item', { active: qty >= t.min_qty }]"
                 @click="qty = t.min_qty">
              <div class="tier-qty">{{ t.min_qty }}件+</div>
              <div class="tier-price">¥{{ t.price }}</div>
            </div>
          </div>

          <!-- 数量 -->
          <div class="qty-row">
            <label>采购数量</label>
            <div class="qty-stepper">
              <button @click="qty = Math.max(product.moq, qty - product.moq)">－</button>
              <input v-model.number="qty" type="number" :min="product.moq" />
              <button @click="qty += product.moq">＋</button>
            </div>
            <span class="text-muted">起订量 {{ product.moq }} 件</span>
          </div>

          <!-- 操作 -->
          <div class="di-actions">
            <button class="btn btn-outline" @click="toMessage">💬 联系商家</button>
            <button class="btn btn-ghost" @click="applySample">🎁 申请样品</button>
            <button class="btn btn-primary" @click="addToCart">
              🛒 加入采购清单
            </button>
          </div>

          <button class="btn btn-danger btn-full" style="margin-top:8px;" @click="sendInquiry">
            📨 立即询价
          </button>
        </div>
      </div>

      <!-- 详情标签页 -->
      <div class="detail-tabs card" style="margin-top:20px;">
        <div class="tab-nav">
          <button v-for="t in tabs" :key="t.key"
                  :class="['tab-btn', { active: activeTab === t.key }]"
                  @click="activeTab = t.key">{{ t.label }}</button>
        </div>

        <!-- 产品信息 -->
        <div class="tab-body" v-show="activeTab === 'info'">
          <p class="desc-text">{{ product.description }}</p>
          <table class="spec-table">
            <tr v-for="r in specRows" :key="r[0]">
              <td class="spec-key">{{ r[0] }}</td>
              <td class="spec-val">{{ r[1] || '—' }}</td>
            </tr>
          </table>
        </div>

        <!-- 工厂 -->
        <div class="tab-body" v-show="activeTab === 'factory'">
          <div class="factory-brief" v-if="product.merchant_name">
            <div class="fb-header">
              <div class="av" style="width:48px;height:48px;font-size:24px;background:var(--blue-xl);">🏭</div>
              <div>
                <div style="font-size:15px;font-weight:700;">{{ product.company_name }}</div>
                <div style="font-size:12px;color:var(--t4);">{{ product.merchant_city }}</div>
                <span class="tag tag-green" v-if="product.merchant_verified">✓ 已认证</span>
              </div>
            </div>
            <div class="fb-stats">
              <div class="fbs-item"><b>{{ product.merchant_rating }}</b> 评分</div>
              <div class="fbs-item"><b>{{ product.response_rate }}%</b> 响应率</div>
              <div class="fbs-item"><b>{{ product.response_time }}</b> 响应时间</div>
            </div>
            <div class="fb-certs">
              <span v-for="c in product.merchant_certs" :key="c" class="tag tag-green">{{ c }}</span>
            </div>
            <router-link :to="`/factories/${product.merchant_id}`" class="btn btn-outline btn-full" style="margin-top:12px;">查看工厂详情</router-link>
          </div>
        </div>

        <!-- 评价 -->
        <div class="tab-body" v-show="activeTab === 'reviews'">
          <div v-if="product.reviews?.length">
            <div v-for="r in product.reviews" :key="r.id" class="review-item">
              <div class="review-hd">
                <span class="star-gold">{{ '★'.repeat(r.stars) }}{{ '☆'.repeat(5-r.stars) }}</span>
                <span style="font-weight:600;">{{ r.buyer_name }}</span>
                <span class="text-muted" style="margin-left:auto;">{{ r.created_at?.slice(0,10) }}</span>
              </div>
              <p style="font-size:13px;color:var(--t2);margin-top:6px;">{{ r.content }}</p>
            </div>
          </div>
          <div v-else class="empty-state">
            <div class="empty-icon">💬</div>
            <div class="empty-text">暂无评价</div>
          </div>
        </div>
      </div>
    </div>

    <!-- 询盘弹窗 -->
    <div class="modal-overlay" v-if="showInquiry" @click.self="showInquiry=false">
      <div class="modal-box">
        <div class="modal-hd">
          <span class="modal-title">发送询盘</span>
          <button class="modal-close" @click="showInquiry=false">✕</button>
        </div>
        <div class="modal-body">
          <div class="product-brief">
            <span style="font-size:28px;">{{ product.emoji }}</span>
            <div>
              <div style="font-weight:600;">{{ product.name }}</div>
              <div style="font-size:12px;color:var(--blue);">¥{{ currentPrice }}/件 · MOQ {{ product.moq }}</div>
            </div>
          </div>
          <div class="form-group">
            <label class="form-label">采购数量</label>
            <input v-model.number="inquiryQty" type="number" class="form-input" :min="product.moq" />
          </div>
          <div class="form-group">
            <label class="form-label">目标价格（选填）</label>
            <input v-model="inquiryBudget" class="form-input" placeholder="例：¥80-85/件" />
          </div>
          <div class="form-group">
            <label class="form-label">补充说明</label>
            <textarea v-model="inquiryMsg" class="form-input" rows="3"
                      placeholder="描述您的具体需求，如认证要求、包装、定制LOGO等…" />
          </div>
        </div>
        <div class="modal-ft">
          <button class="btn btn-ghost" @click="showInquiry=false">取消</button>
          <button class="btn btn-primary" :disabled="sending" @click="doSendInquiry">
            {{ sending ? '发送中…' : '发送询盘' }}
          </button>
        </div>
      </div>
    </div>
  </div>

  <div v-else-if="!loading" class="empty-state" style="margin-top:60px;">
    <div class="empty-icon">😕</div>
    <div class="empty-text">产品不存在</div>
    <router-link to="/products" class="btn btn-primary" style="margin-top:12px;">返回选品中心</router-link>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, inject } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { productApi, inquiryApi } from '@/api'
import { useAuthStore } from '@/stores/auth'
import { useCartStore }  from '@/stores/cart'
import { openChat } from '@/utils/chat'

const route  = useRoute()
const router = useRouter()
const auth   = useAuthStore()
const cart   = useCartStore()
const toast  = inject('toast', () => {})

const product     = ref(null)
const loading     = ref(true)
const qty         = ref(100)
const activeTab   = ref('info')
const showInquiry = ref(false)
const inquiryQty  = ref(100)
const inquiryBudget = ref('')
const inquiryMsg  = ref('')
const sending     = ref(false)

const tabs = [
  { key: 'info',    label: '产品信息' },
  { key: 'factory', label: '工厂资质' },
  { key: 'reviews', label: `评价 (${product.value?.review_count || 0})` },
]

const currentPrice = computed(() => {
  if (!product.value) return 0
  const tiers = product.value.price_tiers || []
  let price = product.value.base_price
  for (const t of [...tiers].reverse()) {
    if (qty.value >= t.min_qty) { price = t.price; break }
  }
  return price
})

const specRows = computed(() => {
  const p = product.value
  if (!p) return []
  return [
    ['SKU', p.sku],
    ['产品类目', p.category],
    ['适用年龄', p.age_range],
    ['产品尺寸', p.size],
    ['主要材料', p.material],
    ['交期', p.lead_time ? `${p.lead_time}个工作日` : null],
  ]
})

function fmtNum(n) { return n >= 10000 ? (n/10000).toFixed(1)+'w' : (n||0).toLocaleString() }

async function addToCart() {
  if (!auth.isLoggedIn) { router.push('/login'); return }
  const res = await cart.upsert(product.value.id, qty.value)
  toast(res.code === 0 ? '已加入采购清单 🛒' : (res.msg || '操作失败'), res.code === 0 ? 'success' : 'error')
}

function sendInquiry() {
  if (!auth.isLoggedIn) { router.push('/login'); return }
  inquiryQty.value = qty.value
  showInquiry.value = true
}

async function doSendInquiry() {
  if (!inquiryMsg.value.trim()) { toast('请填写询盘说明', 'warning'); return }
  sending.value = true
  const res = await inquiryApi.create({
    merchant_id: product.value.merchant_id,
    message:     inquiryMsg.value,
    budget:      inquiryBudget.value,
    items:       [{ product_id: product.value.id, qty: inquiryQty.value }],
  })
  sending.value = false
  if (res.code === 0) {
    toast('询盘已发送，商家将在24小时内回复 ✅')
    showInquiry.value = false
    router.push('/inquiries')
  } else {
    toast(res.msg || '发送失败', 'error')
  }
}

async function toMessage() {
  if (!auth.isLoggedIn) { router.push('/login'); return }
  await openChat(product.value?.merchant_user_id, toast)
}
function applySample() { if (!auth.isLoggedIn) { router.push('/login'); return } router.push('/samples') }

onMounted(async () => {
  const res = await productApi.detail(route.params.id)
  loading.value = false
  if (res.code === 0) {
    product.value = res.data
    qty.value     = res.data.moq || 100
  }
})
</script>

<style scoped>
.breadcrumb { font-size: 13px; color: var(--t4); margin-bottom: 20px; }
.breadcrumb a { color: var(--t4); text-decoration: none; } .breadcrumb a:hover { color: var(--blue); }

.detail-main  { display: grid; grid-template-columns: 400px 1fr; gap: 28px; align-items: start; }
.detail-cover { height: 400px; border-radius: var(--r16); display: flex; align-items: center; justify-content: center; }
.cover-emoji  { font-size: 120px; }

.detail-info { display: flex; flex-direction: column; gap: 14px; }
.di-tags { display: flex; gap: 6px; flex-wrap: wrap; }
.di-name { font-size: 22px; font-weight: 800; color: var(--t1); line-height: 1.3; }
.di-meta { display: flex; align-items: center; gap: 8px; font-size: 13px; }

.price-block  { display: flex; align-items: baseline; gap: 6px; }
.price-big    { font-size: 32px; font-weight: 900; color: var(--blue); }
.price-unit   { font-size: 13px; color: var(--t4); }

.tier-grid { display: flex; gap: 8px; }
.tier-item { flex: 1; padding: 10px 8px; border: 1.5px solid var(--border); border-radius: var(--r8); text-align: center; cursor: pointer; transition: all .15s; }
.tier-item:hover, .tier-item.active { border-color: var(--blue); background: var(--blue-xl); }
.tier-qty   { font-size: 12px; color: var(--t3); }
.tier-price { font-size: 16px; font-weight: 800; color: var(--blue); }

.qty-row { display: flex; align-items: center; gap: 12px; }
.qty-row label { font-size: 13px; font-weight: 600; color: var(--t2); white-space: nowrap; }
.qty-stepper { display: flex; align-items: center; border: 1.5px solid var(--border); border-radius: var(--r8); overflow: hidden; }
.qty-stepper button { width: 34px; height: 34px; border: none; background: var(--t6); font-size: 18px; cursor: pointer; }
.qty-stepper input  { width: 60px; text-align: center; border: none; border-left: 1.5px solid var(--border); border-right: 1.5px solid var(--border); height: 34px; font-size: 14px; font-weight: 700; }

.di-actions { display: flex; gap: 8px; }
.di-actions .btn { flex: 1; justify-content: center; }

.tab-nav { display: flex; border-bottom: 1px solid var(--border); }
.tab-btn { padding: 12px 18px; border: none; background: none; font-size: 14px; font-weight: 500; color: var(--t4); cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -1px; transition: all .15s; }
.tab-btn:hover  { color: var(--t2); }
.tab-btn.active { color: var(--blue); border-bottom-color: var(--blue); font-weight: 700; }
.tab-body { padding: 20px; }
.desc-text { font-size: 14px; color: var(--t2); line-height: 1.7; margin-bottom: 16px; }

.spec-table { width: 100%; border-collapse: collapse; }
.spec-key   { width: 120px; padding: 10px 0; font-size: 13px; color: var(--t4); border-bottom: 1px solid var(--t6); }
.spec-val   { padding: 10px 0; font-size: 13px; color: var(--t1); font-weight: 500; border-bottom: 1px solid var(--t6); }

.factory-brief { }
.fb-header { display: flex; gap: 12px; align-items: center; margin-bottom: 14px; }
.fb-stats  { display: flex; gap: 0; background: var(--bg0); border-radius: var(--r8); margin-bottom: 10px; }
.fbs-item  { flex: 1; text-align: center; padding: 10px; border-right: 1px solid var(--border); font-size: 12px; color: var(--t4); }
.fbs-item:last-child { border: none; }
.fbs-item b { display: block; font-size: 16px; font-weight: 800; color: var(--blue); }
.fb-certs  { display: flex; gap: 6px; flex-wrap: wrap; }

.review-item { padding: 14px 0; border-bottom: 1px solid var(--t6); }
.review-item:last-child { border: none; }
.review-hd { display: flex; align-items: center; gap: 8px; }

/* 弹窗 */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 1000; display: flex; align-items: center; justify-content: center; }
.modal-box { background: #fff; border-radius: 16px; width: 480px; max-height: 85vh; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); overflow: hidden; }
.modal-hd  { display: flex; align-items: center; justify-content: space-between; padding: 18px 24px; border-bottom: 1px solid var(--border); }
.modal-title { font-size: 16px; font-weight: 700; }
.modal-close { background: var(--t6); border: none; width: 28px; height: 28px; border-radius: 6px; cursor: pointer; font-size: 13px; }
.modal-body{ padding: 18px 24px; overflow-y: auto; flex: 1; }
.modal-ft  { padding: 14px 24px; border-top: 1px solid var(--border); display: flex; justify-content: flex-end; gap: 8px; }
.product-brief { display: flex; gap: 12px; align-items: center; background: var(--bg0); border-radius: var(--r10); padding: 12px; margin-bottom: 16px; }
</style>
