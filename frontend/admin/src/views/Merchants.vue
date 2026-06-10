<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">商家管理</h1><span class="page-sub">共 {{ total }} 家商家</span></div>
    <div class="alert-info" v-if="pendingCount > 0">
      <span>ℹ️</span>
      <span style="flex:1;font-size:13px;">有 <strong>{{ pendingCount }}</strong> 家商家等待审核</span>
      <button class="btn btn-sm btn-primary" @click="tab='reviewing';load()">立即审核</button>
    </div>
    <div class="card">
      <div class="filter-bar"><div class="pill-group"><button v-for="t in tabs" :key="t.k" :class="['pill',tab===t.k?'active':'']" @click="tab=t.k;load()">{{t.l}}</button></div><div style="margin-left:auto;"><input v-model="q" class="form-input" placeholder="搜索商家…" style="width:180px;padding:6px 11px;" @keyup.enter="load"/></div></div>
      <div class="table-wrap"><table class="table">
        <thead><tr><th>商家</th><th>所在地</th><th>等级</th><th>评分</th><th>总GMV</th><th>订单数</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="m in merchants" :key="m.id">
            <td><div style="font-weight:700;color:var(--t1);font-size:13px;">{{m.short_name}}</div><div style="font-size:11px;color:var(--t4);">{{m.company_name}}</div></td>
            <td style="font-size:12px;color:var(--t3);">{{m.province}} {{m.city}}</td>
            <td><span :class="['tag',{platinum:'tag-purple',gold:'tag-gold',silver:'tag-gray',bronze:'tag-gray'}[m.level]||'tag-gray']">{{m.level||'—'}}</span></td>
            <td style="font-weight:700;">{{m.rating||'—'}}</td>
            <td class="text-primary" style="font-weight:700;">{{fmtM(m.total_gmv)}}</td>
            <td style="font-weight:600;">{{(m.total_orders||0).toLocaleString()}}</td>
            <td><span :class="['badge',sB(m.status)]">{{sL(m.status)}}</span></td>
            <td><div style="display:flex;gap:5px;">
              <button v-if="m.status==='reviewing'" class="btn btn-sm btn-primary" @click="act(m,'approve')">通过</button>
              <button v-if="m.status==='reviewing'" class="btn btn-sm btn-danger"  @click="act(m,'reject')">拒绝</button>
              <button v-if="m.status==='active'"    class="btn btn-sm btn-danger"  @click="act(m,'suspend')">暂停</button>
              <button v-if="m.status==='suspended'" class="btn btn-sm btn-outline" @click="act(m,'activate')">恢复</button>
            </div></td>
          </tr>
          <tr v-if="!merchants.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">🏭</div><div class="empty-text">暂无商家</div></div></td></tr>
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
const merchants=ref([]);const total=ref(0);const totalPages=ref(1);const page=ref(1);const tab=ref('all');const q=ref('')
const tabs=[{k:'all',l:'全部'},{k:'active',l:'正常'},{k:'reviewing',l:'待审核'},{k:'suspended',l:'已暂停'}]
const pendingCount=computed(()=>merchants.value.filter(m=>m.status==='reviewing').length)
function sL(s){return{active:'正常',reviewing:'审核中',suspended:'已暂停',rejected:'已拒绝'}[s]||s}
function sB(s){return{active:'badge-active',reviewing:'badge-pending',suspended:'badge-danger',rejected:'badge-danger'}[s]||'badge-gray'}
function fmtM(v){v=Number(v)||0;return v>=10000000?'¥'+(v/10000).toFixed(0)+'万':v>=10000?'¥'+(v/10000).toFixed(1)+'万':'¥'+v.toLocaleString()}
async function load(){const p={page:page.value};if(tab.value!=='all')p.status=tab.value;if(q.value)p.q=q.value;const r=await adminApi.merchants(p);if(r.code===0){merchants.value=r.data||[];total.value=r.total||0;totalPages.value=r.total_pages||1}}
async function act(m,action){const r=await adminApi.updateMerchant(m.id,{action});if(r.code===0){toast('操作成功');load()}else toast(r.msg,'error')}
onMounted(load)
</script>
<style scoped>
.page-pad{padding:22px 24px;}.page-sub{font-size:13px;color:var(--t4);}
.alert-info{display:flex;align-items:center;gap:12px;background:var(--blue-xl);border:1px solid #91caff;border-radius:10px;padding:11px 16px;margin-bottom:14px;}
.filter-bar{display:flex;align-items:center;gap:8px;padding:12px 16px;border-bottom:1px solid var(--t6);}
.pill-group{display:flex;background:var(--t6);border-radius:7px;padding:2px;gap:2px;}
.pill{padding:5px 12px;border-radius:5px;font-size:12px;font-weight:600;color:var(--t4);cursor:pointer;border:none;background:transparent;transition:all .15s;}
.pill.active{background:#fff;color:var(--blue);box-shadow:var(--sh-sm);}
.tag-gold{background:#FFFBE6;color:#D48806;}
.pagination{display:flex;align-items:center;justify-content:center;gap:12px;padding:14px;}.page-info{font-size:13px;color:var(--t3);}
</style>