<!-- src/views/Factories.vue -->
<template>
  <div class="page-container" style="padding:28px 0 40px;">
    <div class="page-header"><h1 class="page-title">工厂库</h1><span class="text-muted">共 {{ total }} 家优质工厂</span></div>
    <div class="search-bar" style="margin-bottom:16px;">
      <input v-model="q" class="form-input" placeholder="搜索工厂名称…" @keyup.enter="load" style="max-width:320px;" />
      <button class="btn btn-primary" @click="load">搜索</button>
    </div>
    <div class="factory-grid">
      <router-link v-for="f in factories" :key="f.id" :to="`/factories/${f.id}`" class="factory-card card">
        <div class="fc-header">
          <div class="fc-av">🏭</div>
          <div class="fc-info">
            <div class="fc-name">{{ f.short_name }}</div>
            <div class="fc-city text-muted">{{ f.province }} {{ f.city }}</div>
          </div>
          <div>
            <span class="tag tag-green" v-if="f.verified">✓ 已认证</span>
            <span class="tag tag-gold" style="margin-left:4px;">{{ f.level }}</span>
          </div>
        </div>
        <div class="fc-stats">
          <div class="fcs"><b>{{ f.rating }}</b><span>评分</span></div>
          <div class="fcs"><b>{{ f.total_orders?.toLocaleString() }}</b><span>累计订单</span></div>
          <div class="fcs"><b>{{ f.response_rate }}%</b><span>响应率</span></div>
        </div>
        <div class="fc-cats">
          <span v-for="c in (f.categories||[])" :key="c" class="tag tag-blue">{{ c }}</span>
        </div>
      </router-link>
    </div>
    <div class="pagination" v-if="totalPages>1" style="margin-top:20px;">
      <button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;load()">上一页</button>
      <span class="page-info">{{ page }} / {{ totalPages }}</span>
      <button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;load()">下一页</button>
    </div>
  </div>
</template>
<script setup>
import { ref, onMounted } from 'vue'
import { merchantApi } from '@/api'
const factories = ref([])
const total = ref(0)
const page  = ref(1)
const totalPages = ref(1)
const q     = ref('')
async function load() {
  const res = await merchantApi.list({ page: page.value, per_page: 12, q: q.value })
  if (res.code === 0) { factories.value = res.data||[]; total.value = res.total||0; totalPages.value = res.total_pages||1 }
}
onMounted(load)
</script>
<style scoped>
.search-bar{display:flex;gap:10px;align-items:center;}
.factory-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;}
.factory-card{padding:16px;text-decoration:none;transition:all .15s;display:block;}
.factory-card:hover{border-color:var(--blue);box-shadow:var(--sh);transform:translateY(-2px);}
.fc-header{display:flex;align-items:center;gap:10px;margin-bottom:12px;}
.fc-av{width:44px;height:44px;border-radius:10px;background:var(--blue-xl);display:flex;align-items:center;justify-content:center;font-size:22px;flex-shrink:0;}
.fc-info{flex:1;}
.fc-name{font-size:14px;font-weight:700;color:var(--t1);}
.fc-city{font-size:12px;}
.fc-stats{display:flex;gap:0;background:var(--bg0);border-radius:8px;margin-bottom:10px;}
.fcs{flex:1;text-align:center;padding:8px 4px;border-right:1px solid var(--border);font-size:11px;color:var(--t4);}
.fcs:last-child{border:none;}
.fcs b{display:block;font-size:16px;font-weight:800;color:var(--blue);}
.fc-cats{display:flex;gap:4px;flex-wrap:wrap;}
.pagination{display:flex;align-items:center;justify-content:center;gap:12px;}
.page-info{font-size:13px;color:var(--t3);}
</style>
