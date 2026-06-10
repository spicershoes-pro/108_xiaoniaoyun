<template>
  <router-link :to="`/products/${product.id}`" class="product-card">
    <div class="pc-cover" :style="{ background: product.cover_color || '#EFF6FF' }">
      <span class="pc-emoji">{{ product.emoji || '🧸' }}</span>
      <button class="fav-btn" @click.prevent="toggleFav">
        {{ isFav ? '❤️' : '🤍' }}
      </button>
    </div>
    <div class="pc-body">
      <div class="pc-tags">
        <span v-for="t in (product.certs || []).slice(0,2)" :key="t" class="tag tag-green">{{ t }}</span>
      </div>
      <div class="pc-name">{{ product.name }}</div>
      <div class="pc-factory">{{ product.merchant_name || product.factory }}</div>
      <div class="pc-bottom">
        <div class="pc-price">
          <span class="price-num">¥{{ product.base_price }}</span>
          <span class="price-unit">/件起</span>
        </div>
        <div class="pc-sales text-muted" style="font-size:11px;">
          销量 {{ fmtNum(product.sales_count) }}
        </div>
      </div>
      <div class="pc-moq">MOQ {{ product.moq }} 件</div>
    </div>
  </router-link>
</template>

<script setup>
import { ref, inject } from 'vue'
import { favApi } from '@/api'

const props   = defineProps({ product: { type: Object, required: true } })
const toast   = inject('toast', () => {})
const isFav   = ref(false)

async function toggleFav() {
  const res = await favApi.toggle(props.product.id)
  if (res.code === 0) {
    isFav.value = res.data?.favorited
    toast(isFav.value ? '收藏成功' : '已取消收藏')
  }
}

function fmtNum(n) {
  if (!n) return '0'
  return n >= 10000 ? (n / 10000).toFixed(1) + 'w' : n.toLocaleString()
}
</script>

<style scoped>
.product-card {
  background: #fff; border: 1px solid var(--border); border-radius: var(--r12);
  overflow: hidden; text-decoration: none; display: block;
  transition: all .15s;
}
.product-card:hover { border-color: var(--blue); box-shadow: var(--sh); transform: translateY(-2px); }

.pc-cover {
  height: 160px; display: flex; align-items: center; justify-content: center;
  position: relative;
}
.pc-emoji { font-size: 64px; }
.fav-btn  {
  position: absolute; top: 8px; right: 8px;
  background: rgba(255,255,255,.85); border: none; border-radius: 8px;
  width: 30px; height: 30px; font-size: 15px; cursor: pointer;
  display: flex; align-items: center; justify-content: center;
  transition: transform .15s;
}
.fav-btn:active { transform: scale(.9); }

.pc-body { padding: 12px; }
.pc-tags { display: flex; gap: 4px; margin-bottom: 6px; flex-wrap: wrap; }
.pc-name { font-size: 13px; font-weight: 600; color: var(--t1); margin-bottom: 3px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; line-height: 1.4; }
.pc-factory { font-size: 11px; color: var(--t4); margin-bottom: 8px; }
.pc-bottom { display: flex; justify-content: space-between; align-items: flex-end; margin-bottom: 4px; }
.price-num  { font-size: 18px; font-weight: 800; color: var(--blue); }
.price-unit { font-size: 11px; color: var(--t4); }
.pc-moq { font-size: 11px; color: var(--t4); background: var(--t6); display: inline-block; padding: 2px 7px; border-radius: 4px; }
</style>
