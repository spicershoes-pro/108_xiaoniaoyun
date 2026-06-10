<template>
  <div class="products-page">
    <div class="page-container">
      <div class="page-header">
        <h1 class="page-title">选品中心</h1>
        <span class="text-muted">共 {{ total }} 个产品</span>
      </div>

      <div class="filter-bar card">
        <!-- 品类 -->
        <div class="filter-row">
          <span class="filter-label">品类</span>
          <div class="filter-chips">
            <button v-for="c in categories" :key="c"
                    :class="['chip', { active: filters.category === c }]"
                    @click="setFilter('category', c)">{{ c }}</button>
          </div>
        </div>
        <!-- 排序 -->
        <div class="filter-row">
          <span class="filter-label">排序</span>
          <div class="filter-chips">
            <button v-for="s in sorts" :key="s.key"
                    :class="['chip', { active: filters.sort === s.key }]"
                    @click="setFilter('sort', s.key)">{{ s.label }}</button>
          </div>
          <div style="margin-left:auto;display:flex;gap:6px;">
            <button :class="['chip', { active: viewMode === 'grid' }]" @click="viewMode='grid'">▦ 网格</button>
            <button :class="['chip', { active: viewMode === 'list' }]" @click="viewMode='list'">≡ 列表</button>
          </div>
        </div>
      </div>

      <!-- 网格 -->
      <div v-if="loading" class="product-grid mt-16">
        <div v-for="i in 12" :key="i" class="skel" style="height:260px;border-radius:12px;" />
      </div>

      <template v-else>
        <div v-if="viewMode === 'grid'" class="product-grid mt-16">
          <ProductCard v-for="p in products" :key="p.id" :product="p" />
        </div>

        <div v-else class="product-list mt-16">
          <router-link v-for="p in products" :key="p.id"
                       :to="`/products/${p.id}`" class="list-item">
            <div class="li-cover" :style="{ background: p.cover_color || '#EFF6FF' }">
              <span>{{ p.emoji || '🧸' }}</span>
            </div>
            <div class="li-info">
              <div class="li-name">{{ p.name }}</div>
              <div class="li-factory">{{ p.merchant_name }} · MOQ {{ p.moq }}件</div>
              <div class="li-certs">
                <span v-for="c in (p.certs||[]).slice(0,3)" :key="c" class="tag tag-green">{{ c }}</span>
              </div>
            </div>
            <div class="li-price">
              <div class="price-num">¥{{ p.base_price }}</div>
              <div class="text-muted" style="font-size:11px;">/件起</div>
              <div class="text-muted" style="font-size:11px;margin-top:4px;">销量 {{ p.sales_count?.toLocaleString() }}</div>
            </div>
            <span style="color:var(--t4);font-size:18px;">›</span>
          </router-link>
        </div>

        <!-- 空 -->
        <div v-if="!products.length" class="empty-state">
          <div class="empty-icon">🔍</div>
          <div class="empty-text">暂无相关产品</div>
        </div>

        <!-- 分页 -->
        <div class="pagination" v-if="totalPages > 1">
          <button class="btn btn-ghost btn-sm" :disabled="page === 1" @click="changePage(page-1)">上一页</button>
          <span class="page-info">{{ page }} / {{ totalPages }}</span>
          <button class="btn btn-ghost btn-sm" :disabled="page === totalPages" @click="changePage(page+1)">下一页</button>
        </div>
      </template>
    </div>
  </div>
</template>

<script setup>
import { ref, reactive, watch, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { productApi } from '@/api'
import ProductCard from '@/components/ProductCard.vue'

const route   = useRoute()
const router  = useRouter()

const categories = ['全部','遥控玩具','益智玩具','户外玩具','毛绒玩具','科技玩具','传统玩具']
const sorts      = [
  { key: 'default',    label: '综合' },
  { key: 'sales',      label: '销量' },
  { key: 'price_asc',  label: '价格↑' },
  { key: 'price_desc', label: '价格↓' },
  { key: 'rating',     label: '评分' },
]

const products  = ref([])
const total     = ref(0)
const page      = ref(1)
const totalPages= ref(1)
const loading   = ref(false)
const viewMode  = ref('grid')

const filters = reactive({
  category: route.query.category || '全部',
  sort:     route.query.sort     || 'default',
  q:        route.query.q        || '',
})

async function load() {
  loading.value = true
  try {
    const params = { page: page.value, per_page: 20, sort: filters.sort }
    if (filters.category && filters.category !== '全部') params.category = filters.category
    if (filters.q) params.q = filters.q
    const res = await productApi.list(params)
    if (res.code === 0) {
      products.value   = res.data || []
      total.value      = res.total || 0
      totalPages.value = res.total_pages || 1
    }
  } finally {
    loading.value = false
  }
}

function setFilter(key, val) {
  filters[key] = val
  page.value   = 1
}

function changePage(p) { page.value = p }

watch([filters, page], load, { immediate: true })
</script>

<style scoped>
.filter-bar  { margin-bottom: 0; }
.filter-row  { display: flex; align-items: center; gap: 10px; padding: 12px 16px; border-bottom: 1px solid var(--t6); flex-wrap: wrap; }
.filter-row:last-child { border-bottom: none; }
.filter-label{ font-size: 12px; font-weight: 700; color: var(--t4); flex-shrink: 0; width: 36px; }
.filter-chips{ display: flex; flex-wrap: wrap; gap: 6px; }
.chip { padding: 5px 12px; border-radius: 20px; border: 1.5px solid var(--border); background: #fff; font-size: 12px; font-weight: 500; color: var(--t3); cursor: pointer; transition: all .15s; }
.chip:hover  { border-color: var(--blue); color: var(--blue); }
.chip.active { border-color: var(--blue); background: var(--blue-xl); color: var(--blue2); font-weight: 600; }

.mt-16 { margin-top: 16px; }
.product-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; }
.product-list { display: flex; flex-direction: column; gap: 0; border: 1px solid var(--border); border-radius: var(--r12); overflow: hidden; background: #fff; }
.list-item { display: flex; align-items: center; gap: 14px; padding: 14px 16px; border-bottom: 1px solid var(--t6); text-decoration: none; transition: background .12s; }
.list-item:last-child { border-bottom: none; }
.list-item:hover { background: #fafbff; }
.li-cover { width: 56px; height: 56px; border-radius: var(--r10); display: flex; align-items: center; justify-content: center; font-size: 28px; flex-shrink: 0; }
.li-info  { flex: 1; min-width: 0; }
.li-name  { font-size: 14px; font-weight: 600; color: var(--t1); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.li-factory { font-size: 12px; color: var(--t4); margin: 3px 0; }
.li-certs { display: flex; gap: 4px; }
.li-price { text-align: right; flex-shrink: 0; }
.price-num { font-size: 18px; font-weight: 800; color: var(--blue); }

.pagination { display: flex; align-items: center; justify-content: center; gap: 12px; margin-top: 24px; }
.page-info  { font-size: 13px; color: var(--t3); }
</style>
