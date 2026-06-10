<!-- src/views/FactoryDetail.vue -->
<template>
  <div class="page-container" style="padding:28px 0 40px;" v-if="factory">
    <div class="fac-hero card" style="padding:24px;margin-bottom:20px;">
      <div style="display:flex;gap:16px;align-items:flex-start;">
        <div style="width:64px;height:64px;border-radius:14px;background:var(--blue-xl);display:flex;align-items:center;justify-content:center;font-size:32px;flex-shrink:0;">🏭</div>
        <div style="flex:1;">
          <h1 style="font-size:22px;font-weight:800;margin-bottom:4px;">{{ factory.company_name }}</h1>
          <div style="font-size:13px;color:var(--t4);margin-bottom:10px;">{{ factory.province }} {{ factory.city }} · 成立于{{ factory.founded_year }}年 · {{ factory.staff_range }}</div>
          <div style="display:flex;gap:6px;flex-wrap:wrap;">
            <span class="tag tag-green" v-if="factory.verified">✓ 已认证</span>
            <span v-for="c in factory.certs" :key="c.name" class="tag tag-blue">{{ c.name }}</span>
          </div>
        </div>
        <div style="text-align:right;flex-shrink:0;">
          <div style="font-size:28px;font-weight:900;color:var(--blue);">{{ factory.rating }}</div>
          <div style="font-size:11px;color:var(--t4);">综合评分</div>
          <div style="font-size:14px;font-weight:700;margin-top:6px;">{{ factory.response_rate }}% 响应率</div>
        </div>
      </div>
      <p style="font-size:13px;color:var(--t3);line-height:1.7;margin-top:14px;">{{ factory.description }}</p>
      <div style="display:flex;gap:10px;margin-top:16px;">
        <button class="btn btn-primary" @click="toMsg">💬 发消息</button>
        <router-link to="/products" class="btn btn-outline">查看在售产品</router-link>
      </div>
    </div>
    <h2 style="font-size:16px;font-weight:700;margin-bottom:12px;">在售产品</h2>
    <div style="display:grid;grid-template-columns:repeat(4,1fr);gap:14px;">
      <ProductCard v-for="p in factory.products" :key="p.id" :product="p" />
    </div>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { merchantApi } from '@/api'
import { useAuthStore } from '@/stores/auth'
import ProductCard from '@/components/ProductCard.vue'
const route = useRoute(); const router = useRouter(); const auth = useAuthStore()
const factory = ref(null)
onMounted(async ()=>{ const res = await merchantApi.detail(route.params.id); if(res.code===0) factory.value = res.data })
function toMsg(){ if(!auth.isLoggedIn){ router.push('/login'); return } router.push('/messages') }
</script>
