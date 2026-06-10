<template>
  <div class="home-page">
    <!-- Hero Banner -->
    <section class="hero">
      <div class="page-container">
        <div class="banner-carousel" v-if="banners.length">
          <div class="banner-slide" :style="{ background: banners[bannerIdx]?.bg_style }">
            <div class="banner-content">
              <span class="banner-tag">{{ banners[bannerIdx]?.tag }}</span>
              <h2 class="banner-title">{{ banners[bannerIdx]?.title }}</h2>
              <p class="banner-sub">{{ banners[bannerIdx]?.subtitle }}</p>
              <router-link to="/products" class="btn btn-primary">立即选品 →</router-link>
            </div>
            <div class="banner-emoji">{{ banners[bannerIdx]?.emoji }}</div>
          </div>
          <div class="banner-dots">
            <span v-for="(_, i) in banners" :key="i"
                  :class="['dot', { active: i === bannerIdx }]"
                  @click="bannerIdx = i" />
          </div>
        </div>
      </div>
    </section>

    <!-- 快捷入口 -->
    <section class="quick-links">
      <div class="page-container">
        <div class="quick-grid">
          <router-link v-for="l in quickLinks" :key="l.to" :to="l.to" class="quick-item">
            <span class="quick-icon">{{ l.icon }}</span>
            <span class="quick-label">{{ l.label }}</span>
          </router-link>
        </div>
      </div>
    </section>

    <!-- 平台数据 -->
    <section class="stats-bar">
      <div class="page-container">
        <div class="stats-grid">
          <div v-for="s in stats" :key="s.label" class="stat-item">
            <div class="stat-val">{{ s.val }}</div>
            <div class="stat-label">{{ s.label }}</div>
          </div>
        </div>
      </div>
    </section>

    <!-- 热销爆款 -->
    <section class="section">
      <div class="page-container">
        <div class="section-header">
          <h2 class="section-title">🔥 热销爆款</h2>
          <router-link to="/products?sort=sales" class="section-more">查看全部 →</router-link>
        </div>
        <div class="product-grid" v-if="hotProducts.length">
          <ProductCard v-for="p in hotProducts" :key="p.id" :product="p" />
        </div>
        <div v-else class="product-grid">
          <div v-for="i in 8" :key="i" class="skel" style="height:260px;border-radius:12px;" />
        </div>
      </div>
    </section>

    <!-- 热销榜 -->
    <section class="section ranking-section">
      <div class="page-container">
        <div class="section-header">
          <h2 class="section-title">📊 全球热销榜</h2>
          <router-link to="/ranking" class="section-more">查看详情 →</router-link>
        </div>
        <div class="ranking-tabs">
          <button v-for="r in regions" :key="r.key"
                  :class="['btn btn-sm', rankRegion === r.key ? 'btn-primary' : 'btn-ghost']"
                  @click="loadRanking(r.key)">{{ r.label }}</button>
        </div>
        <div class="ranking-list">
          <div v-for="(item, i) in rankList" :key="i" class="rank-item">
            <div :class="['rank-no', i < 3 ? `rank-${i+1}` : '']">{{ i + 1 }}</div>
            <span class="rank-em">{{ item.em }}</span>
            <div class="rank-info">
              <div class="rank-name">{{ item.n }}</div>
              <div class="rank-sales">月销 {{ item.s }}</div>
            </div>
            <span class="tag tag-green">{{ item.g }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- 优质工厂 -->
    <section class="section">
      <div class="page-container">
        <div class="section-header">
          <h2 class="section-title">🏭 优质工厂</h2>
          <router-link to="/factories" class="section-more">查看全部 →</router-link>
        </div>
        <div class="factory-grid">
          <router-link v-for="f in factories" :key="f.id" :to="`/factories/${f.id}`" class="factory-card">
            <div class="factory-header">
              <div class="factory-av">🏭</div>
              <div>
                <div class="factory-name">{{ f.short_name }}</div>
                <div class="factory-city">{{ f.province }} {{ f.city }}</div>
              </div>
              <span class="tag tag-green" v-if="f.verified">✓ 已认证</span>
            </div>
            <div class="factory-stats">
              <div class="fs-item"><b>{{ f.rating }}</b> 综合评分</div>
              <div class="fs-item"><b>{{ f.total_orders?.toLocaleString() }}</b> 累计订单</div>
              <div class="fs-item"><b>{{ f.response_rate }}%</b> 响应率</div>
            </div>
          </router-link>
        </div>
      </div>
    </section>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { productApi, merchantApi, discoverApi } from '@/api'
import ProductCard from '@/components/ProductCard.vue'

const banners     = ref([])
const bannerIdx   = ref(0)
const hotProducts = ref([])
const factories   = ref([])
const rankList    = ref([])
const rankRegion  = ref('US')

const quickLinks = [
  { icon: '🔍', label: '找产品',  to: '/products' },
  { icon: '🏭', label: '找工厂',  to: '/factories' },
  { icon: '📊', label: '热销榜',  to: '/ranking' },
  { icon: '🎨', label: 'IP授权',  to: '/ips' },
  { icon: '💱', label: '汇率换算',to: '/currency' },
  { icon: '💬', label: '玩具圈',  to: '/circle' },
  { icon: '📦', label: '我的订单',to: '/orders' },
  { icon: '🎁', label: '样品申请',to: '/samples' },
]

const stats = [
  { val: '3,000+', label: 'SKU在售' },
  { val: '200+',   label: '优质工厂' },
  { val: '50+',    label: 'IP授权' },
  { val: '60+',    label: '目标国家' },
]

const regions = [
  { key: 'US',  label: '🇺🇸 北美' },
  { key: 'EU',  label: '🇪🇺 欧洲' },
  { key: 'JP',  label: '🇯🇵 日本' },
  { key: 'SEA', label: '🌏 东南亚' },
]

let bannerTimer = null

function fmtRankSales(n) {
  if (!n) return '—'
  const v = Number(n)
  return v >= 10000 ? `${(v / 10000).toFixed(1)}w` : v.toLocaleString()
}

function fmtRankGrowth(g) {
  if (g == null || g === '') return '—'
  const v = Number(g)
  return `${v >= 0 ? '+' : ''}${v.toFixed(0)}%`
}

function mapRankingRows(rows) {
  return (rows || []).map(item => ({
    em: item.emoji || '📦',
    n: item.name || '',
    s: fmtRankSales(item.monthly_sales),
    g: fmtRankGrowth(item.growth_rate),
    product_id: item.product_id,
  }))
}

async function loadRanking(region) {
  rankRegion.value = region
  const res = await discoverApi.ranking(region)
  if (res.code === 0) rankList.value = mapRankingRows(res.data?.list)
}

onMounted(async () => {
  const [bRes, pRes, fRes] = await Promise.all([
    discoverApi.banners(),
    productApi.list({ sort: 'sales', per_page: 8 }),
    merchantApi.list({ per_page: 4 }),
  ])
  if (bRes.code === 0) banners.value = bRes.data || []
  if (pRes.code === 0) hotProducts.value = pRes.data || []
  if (fRes.code === 0) factories.value = fRes.data || []

  await loadRanking('US')

  bannerTimer = setInterval(() => {
    if (banners.value.length)
      bannerIdx.value = (bannerIdx.value + 1) % banners.value.length
  }, 4000)
})

onUnmounted(() => clearInterval(bannerTimer))
</script>

<style scoped>
.hero { padding: 24px 0 0; }
.banner-carousel { position: relative; border-radius: var(--r16); overflow: hidden; }
.banner-slide {
  display: flex; align-items: center; justify-content: space-between;
  padding: 36px 40px; min-height: 180px; border-radius: var(--r16);
}
.banner-content { flex: 1; }
.banner-tag   { display: inline-block; background: rgba(255,255,255,.25); color: #fff; padding: 3px 10px; border-radius: 20px; font-size: 12px; font-weight: 700; margin-bottom: 10px; }
.banner-title { font-size: 28px; font-weight: 900; color: #fff; margin-bottom: 8px; }
.banner-sub   { font-size: 14px; color: rgba(255,255,255,.8); margin-bottom: 16px; }
.banner-emoji { font-size: 72px; flex-shrink: 0; margin-left: 20px; }
.banner-dots  { display: flex; justify-content: center; gap: 6px; padding: 12px 0; background: #fff; }
.dot { width: 8px; height: 8px; border-radius: 4px; background: var(--border); cursor: pointer; transition: all .3s; }
.dot.active { width: 20px; background: var(--blue); }

.quick-links { padding: 20px 0; }
.quick-grid  { display: grid; grid-template-columns: repeat(8, 1fr); gap: 8px; }
.quick-item  { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 14px 8px; background: #fff; border-radius: var(--r12); border: 1px solid var(--border); text-decoration: none; transition: all .15s; }
.quick-item:hover { border-color: var(--blue); background: var(--blue-xl); transform: translateY(-2px); }
.quick-icon  { font-size: 26px; }
.quick-label { font-size: 12px; color: var(--t2); font-weight: 500; }

.stats-bar { background: linear-gradient(135deg, var(--blue), var(--blue2)); padding: 20px 0; }
.stats-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 0; }
.stat-item  { text-align: center; border-right: 1px solid rgba(255,255,255,.2); padding: 8px; }
.stat-item:last-child { border: none; }
.stat-val   { font-size: 24px; font-weight: 900; color: #fff; }
.stat-label { font-size: 12px; color: rgba(255,255,255,.7); margin-top: 2px; }

.section { padding: 32px 0; }
.section-header { display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px; }
.section-title  { font-size: 18px; font-weight: 800; color: var(--t1); }
.section-more   { font-size: 13px; color: var(--blue); text-decoration: none; }
.section-more:hover { color: var(--blue2); }

.product-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 14px; }

.ranking-section { background: var(--bg0); border-radius: var(--r16); margin: 0 0 16px; padding: 24px; }
.ranking-tabs { display: flex; gap: 8px; margin-bottom: 16px; }
.ranking-list { display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px; }
.rank-item { display: flex; align-items: center; gap: 10px; background: #fff; padding: 12px 14px; border-radius: var(--r10); border: 1px solid var(--border); }
.rank-no   { width: 24px; height: 24px; border-radius: 6px; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 800; background: var(--t6); color: var(--t4); flex-shrink: 0; }
.rank-1 { background: #FFF7E6; color: #D48806; }
.rank-2 { background: #f0f0f0; color: #595959; }
.rank-3 { background: #FFF2E8; color: #D46B08; }
.rank-em   { font-size: 22px; flex-shrink: 0; }
.rank-info { flex: 1; min-width: 0; }
.rank-name { font-size: 13px; font-weight: 600; color: var(--t1); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.rank-sales{ font-size: 11px; color: var(--t4); }

.factory-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 14px; }
.factory-card { background: #fff; border: 1px solid var(--border); border-radius: var(--r12); padding: 16px; text-decoration: none; transition: all .15s; }
.factory-card:hover { border-color: var(--blue); box-shadow: var(--sh); transform: translateY(-2px); }
.factory-header { display: flex; align-items: center; gap: 10px; margin-bottom: 12px; }
.factory-av   { width: 40px; height: 40px; border-radius: var(--r10); background: var(--blue-xl); display: flex; align-items: center; justify-content: center; font-size: 22px; flex-shrink: 0; }
.factory-name { font-size: 14px; font-weight: 700; color: var(--t1); }
.factory-city { font-size: 12px; color: var(--t4); }
.factory-stats{ display: flex; gap: 0; }
.fs-item { flex: 1; text-align: center; border-right: 1px solid var(--t6); font-size: 11px; color: var(--t4); }
.fs-item:last-child { border: none; }
.fs-item b { display: block; font-size: 14px; font-weight: 800; color: var(--blue); }
</style>
