<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">IP授权管理</h1><button class="btn btn-primary">+ 新增IP</button></div>
    <div class="tab-row"><button v-for="t in tabs" :key="t.k" :class="['tab-btn',curTab===t.k?'active':'']" @click="curTab=t.k;load()">{{t.l}}<span v-if="t.k==='apps'&&pendingCount>0" style="margin-left:4px;background:var(--red);color:#fff;font-size:9px;padding:1px 5px;border-radius:8px;font-weight:700;">{{pendingCount}}</span></button></div>
    <div class="card" v-if="curTab==='library'">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>IP</th><th>权利方</th><th>来源</th><th>类型</th><th>申请数</th><th>分成比例</th><th>到期</th><th>状态</th></tr></thead>
        <tbody>
          <tr v-for="ip in ipList" :key="ip.id">
            <td><div style="display:flex;gap:8px;align-items:center;"><span style="font-size:22px;">{{ip.emoji}}</span><div><div style="font-weight:700;font-size:13px;">{{ip.name}}</div><span v-if="ip.is_hot" class="tag tag-red">🔥 热门</span></div></div></td>
            <td style="font-size:12px;color:var(--t3);">{{ip.licensor}}</td>
            <td style="font-size:12px;">{{ip.origin}}</td>
            <td><span class="tag tag-blue">{{ip.category}}</span></td>
            <td style="font-weight:700;color:var(--orange);">{{ip._count?.applications||0}}</td>
            <td style="font-weight:600;">{{ip.revenue_share||'TBD'}}</td>
            <td :style="{fontSize:'12px',color:ip.status==='expiring'?'var(--orange)':'var(--t3)',fontWeight:ip.status==='expiring'?700:400}">{{ip.expires_at?.slice(0,10)||'洽谈中'}}</td>
            <td><span :class="['badge',ip.status==='active'?'badge-active':ip.status==='negotiating'?'badge-pending':'badge-pending']">{{ip.status==='active'?'有效':ip.status==='negotiating'?'洽谈中':'即将到期'}}</span></td>
          </tr>
        </tbody>
      </table></div>
    </div>
    <div class="card" v-if="curTab==='apps'">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>申请编号</th><th>商家</th><th>申请IP</th><th>授权产品</th><th>预计数量</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="a in applications" :key="a.id">
            <td class="mono" style="font-size:11px;">{{a.id?.slice(-8)}}</td>
            <td style="font-weight:600;font-size:13px;">{{a.company_name}}</td>
            <td><span style="font-size:16px;margin-right:4px;">{{a.ip_emoji}}</span><span style="font-weight:600;">{{a.ip_name}}</span></td>
            <td style="font-size:12px;color:var(--t3);">{{a.product}}</td>
            <td style="font-weight:600;">{{a.annual_qty?.toLocaleString()||'—'}}</td>
            <td><span :class="['badge',a.status==='pending'?'badge-pending':a.status==='approved'?'badge-active':'badge-danger']">{{a.status==='pending'?'待审核':a.status==='approved'?'已批准':'已拒绝'}}</span></td>
            <td><div style="display:flex;gap:5px;">
              <button v-if="a.status==='pending'" class="btn btn-sm btn-primary" @click="reviewApp(a,'approve')">批准</button>
              <button v-if="a.status==='pending'" class="btn btn-sm btn-danger"  @click="reviewApp(a,'reject')">拒绝</button>
            </div></td>
          </tr>
          <tr v-if="!applications.length"><td colspan="7"><div class="empty-state"><div class="empty-icon">🎨</div><div class="empty-text">暂无申请</div></div></td></tr>
        </tbody>
      </table></div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, inject, onMounted } from 'vue'
import { adminApi } from '@/api'
const toast=inject('toast',()=>{})
const ipList=ref([]);const applications=ref([]);const curTab=ref('library')
const tabs=[{k:'library',l:'IP授权库'},{k:'apps',l:'授权申请'}]
const pendingCount=computed(()=>applications.value.filter(a=>a.status==='pending').length)
async function load(){
  if(curTab.value==='library'){const r=await adminApi.ips({tab:'library'});if(r.code===0)ipList.value=r.data?.list||r.data||[]}
  else{const r=await adminApi.ips({tab:'applications'});if(r.code===0)applications.value=r.data||[]}
}
async function reviewApp(a,action){const r=await adminApi.updateIp(a.id,{action});if(r.code===0){toast(action==='approve'?'已批准授权申请':'已拒绝授权申请');load()}else toast(r.msg,'error')}
onMounted(load)
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.tab-row{display:flex;border-bottom:1px solid var(--border);margin-bottom:16px;background:#fff;border-radius:10px 10px 0 0;padding:0 16px;}
.tab-btn{padding:11px 16px;border:none;background:none;font-size:13px;font-weight:500;color:var(--t4);cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;}
.tab-btn.active{color:var(--blue);border-bottom-color:var(--blue);font-weight:700;}
</style>