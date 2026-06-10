<template>
<div class="page-container" style="padding:28px 0 40px;">
  <h1 class="page-title" style="margin-bottom:16px;">搜索结果：{{ q }}</h1>
  <div v-if="result.products?.length">
    <h2 style="font-size:15px;font-weight:700;margin-bottom:12px;">产品 ({{ result.products.length }})</h2>
    <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:24px;">
      <ProductCard v-for="p in result.products" :key="p.id" :product="p" />
    </div>
  </div>
  <div v-if="result.merchants?.length">
    <h2 style="font-size:15px;font-weight:700;margin-bottom:12px;">工厂 ({{ result.merchants.length }})</h2>
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px;">
      <router-link v-for="m in result.merchants" :key="m.id" :to="`/factories/${m.id}`" class="card" style="padding:16px;text-decoration:none;display:block;transition:all .15s;" :style="{}">
        <div style="font-size:15px;font-weight:700;color:var(--t1);">{{ m.short_name }}</div>
        <div style="font-size:12px;color:var(--t4);">{{ m.province }} {{ m.city }} · ★ {{ m.rating }}</div>
      </router-link>
    </div>
  </div>
  <div v-if="!result.total" class="empty-state">
    <div class="empty-icon">🔍</div>
    <div class="empty-text">未找到"{{ q }}"的相关结果</div>
  </div>
</div>
</template>
<script setup>
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'
import { discoverApi } from '@/api'
import ProductCard from '@/components/ProductCard.vue'
const route = useRoute()
const q = ref(route.query.q || '')
const result = ref({products:[],merchants:[],total:0})
async function load(){ if(q.value){ const res = await discoverApi.search(q.value); if(res.code===0) result.value = res.data } }
watch(()=>route.query.q, v=>{ q.value=v||''; load() }, { immediate: true })
</script>
