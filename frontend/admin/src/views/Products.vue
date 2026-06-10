<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">产品审核</h1><span style="font-size:13px;color:var(--t4);">{{pendingCount}} 个产品待审核</span></div>
    <div class="card">
      <div class="filter-bar"><div class="pill-group"><button v-for="t in tabs" :key="t.k" :class="['pill',tab===t.k?'active':'']" @click="tab=t.k;load()">{{t.l}}</button></div></div>
      <div class="table-wrap"><table class="table">
        <thead><tr><th>产品</th><th>SKU</th><th>商家</th><th>价格</th><th>认证</th><th>销量</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="p in products" :key="p.id" :style="{background:p.certs?.length===0&&p.status==='pending'?'#FFF1F0':''}">
            <td><div style="display:flex;gap:8px;align-items:center;"><div :style="{width:'36px',height:'36px',borderRadius:'8px',background:p.cover_color||'#EFF6FF',display:'flex',alignItems:'center',justifyContent:'center',fontSize:'18px',flexShrink:0}">{{p.emoji||'🧸'}}</div><div><div style="font-weight:600;font-size:13px;color:var(--t1);">{{p.name}}</div><div style="font-size:11px;color:var(--t4);">{{p.category}}</div></div></div></td>
            <td class="mono">{{p.sku}}</td>
            <td style="font-size:12px;color:var(--t3);">{{p.merchant_name}}</td>
            <td class="text-primary" style="font-weight:700;">¥{{p.base_price}}</td>
            <td>
              <div v-if="p.certs?.length" style="display:flex;gap:3px;flex-wrap:wrap;"><span v-for="c in p.certs" :key="c" class="tag tag-green">{{c}}</span></div>
              <span v-else class="tag tag-red">⚠ 无认证</span>
            </td>
            <td style="font-weight:600;">{{(p.sales_count||0).toLocaleString()}}</td>
            <td><span :class="['badge',{online:'badge-active',pending:'badge-pending',offline:'badge-gray',rejected:'badge-danger'}[p.status]||'badge-gray']">{{sL(p.status)}}</span></td>
            <td><div style="display:flex;gap:5px;">
              <button v-if="p.status==='pending'" class="btn btn-sm btn-primary" @click="act(p,'approve')">通过</button>
              <button v-if="p.status==='pending'" class="btn btn-sm btn-danger"  @click="act(p,'reject')">拒绝</button>
              <button v-if="p.status==='online'"  class="btn btn-sm btn-warning" @click="act(p,'offline')">下架</button>
            </div></td>
          </tr>
          <tr v-if="!products.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">🧸</div><div class="empty-text">暂无产品</div></div></td></tr>
        </tbody>
      </table></div>
      <div class="pagination" v-if="totalPages>1"><button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;load()">上一页</button><span class="page-info">{{page}} / {{totalPages}}</span><button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;load()">下一页</button></div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, inject, onMounted } from 'vue'
import { adminApi } from '@/api'
const toast=inject('toast',()=>{})
const products=ref([]);const total=ref(0);const totalPages=ref(1);const page=ref(1);const tab=ref('all')
const tabs=[{k:'all',l:'全部'},{k:'pending',l:'待审核'},{k:'online',l:'已上架'},{k:'rejected',l:'已拒绝'}]
const pendingCount=computed(()=>products.value.filter(p=>p.status==='pending').length)
function sL(s){return{online:'上架中',pending:'待审核',offline:'已下架',rejected:'已拒绝',draft:'草稿'}[s]||s}
async function load(){const p={page:page.value};if(tab.value!=='all')p.status=tab.value;const r=await adminApi.products(p);if(r.code===0){products.value=r.data||[];total.value=r.total||0;totalPages.value=r.total_pages||1}}
async function act(p,action){const r=await adminApi.updateProduct(p.id,{action});if(r.code===0){toast(action==='approve'?'产品已通过审核并上架':action==='reject'?'产品已拒绝':'产品已下架');load()}else toast(r.msg,'error')}
onMounted(load)
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.filter-bar{display:flex;align-items:center;gap:8px;padding:12px 16px;border-bottom:1px solid var(--t6);}
.pill-group{display:flex;background:var(--t6);border-radius:7px;padding:2px;gap:2px;}
.pill{padding:5px 12px;border-radius:5px;font-size:12px;font-weight:600;color:var(--t4);cursor:pointer;border:none;background:transparent;}
.pill.active{background:#fff;color:var(--blue);box-shadow:var(--sh-sm);}
.pagination{display:flex;align-items:center;justify-content:center;gap:12px;padding:14px;}.page-info{font-size:13px;color:var(--t3);}
</style>