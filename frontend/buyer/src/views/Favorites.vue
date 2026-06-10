<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header"><h1 class="page-title">我的收藏</h1><span class="text-muted">共 {{ total }} 件产品</span></div>
    <div v-if="loading" class="product-grid">
      <div v-for="i in 8" :key="i" class="skel" style="height:260px;border-radius:12px;" />
    </div>
    <div v-else-if="list.length" class="product-grid">
      <div v-for="item in list" :key="item.id" class="fav-card">
        <router-link :to="`/products/${item.product_id}`" class="fc-cover" :style="{background:item.cover_color||'#EFF6FF'}">
          <span style="font-size:64px;">{{ item.emoji||'🧸' }}</span>
        </router-link>
        <div class="fc-body">
          <div style="display:flex;gap:4px;margin-bottom:6px;flex-wrap:wrap;">
            <span v-for="c in (item.certs||[]).slice(0,2)" :key="c" class="tag tag-green">{{c}}</span>
          </div>
          <router-link :to="`/products/${item.product_id}`" class="fc-name">{{ item.name }}</router-link>
          <div style="font-size:11px;color:var(--t4);margin:4px 0 8px;">{{ item.merchant_name }}</div>
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:6px;">
            <div><span style="font-size:18px;font-weight:800;color:var(--blue);">¥{{ item.base_price }}</span><span class="text-muted" style="font-size:11px;"> /件起</span></div>
            <div style="display:flex;gap:5px;">
              <button class="btn btn-sm btn-outline" @click="addCart(item)">加清单</button>
              <button class="btn btn-sm btn-ghost" @click="remove(item)">🗑</button>
            </div>
          </div>
          <div style="font-size:11px;color:var(--t4);background:var(--t6);display:inline-block;padding:2px 7px;border-radius:4px;">MOQ {{ item.moq }} 件</div>
        </div>
      </div>
    </div>
    <div v-else class="empty-state">
      <div class="empty-icon">❤️</div><div class="empty-text">还没有收藏任何产品</div>
      <router-link to="/products" class="btn btn-primary" style="margin-top:14px;">去选品</router-link>
    </div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { favApi, cartApi } from '@/api'
const toast=inject('toast',()=>{}); const list=ref([]); const total=ref(0); const loading=ref(false)
async function load(){ loading.value=true; const r=await favApi.list(); loading.value=false; if(r.code===0){list.value=r.data.list||[];total.value=r.data.total||0} }
async function remove(item){ const r=await favApi.toggle(item.product_id); if(r.code===0){toast('已取消收藏');list.value=list.value.filter(i=>i.product_id!==item.product_id);total.value=list.value.length} }
async function addCart(item){ const r=await cartApi.upsert({product_id:item.product_id,qty:item.moq||100}); toast(r.code===0?'已加入采购清单 🛒':(r.msg||'失败'),r.code===0?'success':'error') }
onMounted(load)
</script>
<style scoped>
.product-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:14px;}
.fav-card{background:#fff;border:1px solid var(--border);border-radius:var(--r12);overflow:hidden;transition:all .15s;}
.fav-card:hover{border-color:var(--blue);box-shadow:var(--sh);transform:translateY(-2px);}
.fc-cover{height:160px;display:flex;align-items:center;justify-content:center;text-decoration:none;}
.fc-body{padding:12px;}
.fc-name{font-size:13px;font-weight:600;color:var(--t1);display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;line-height:1.4;text-decoration:none;}
.fc-name:hover{color:var(--blue);}
</style>