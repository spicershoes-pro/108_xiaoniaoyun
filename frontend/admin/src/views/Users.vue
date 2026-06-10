<!-- src/views/Users.vue -->
<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">用户管理</h1><span class="text-muted">共 {{ total }} 名用户</span></div>
    <div class="card" style="margin-bottom:14px;">
      <div class="filter-bar" style="display:flex;gap:8px;padding:12px 16px;">
        <button v-for="t in tabs" :key="t.k" :class="['btn btn-sm', tab===t.k?'btn-primary':'btn-ghost']" @click="tab=t.k;load()">{{ t.l }}</button>
        <div style="margin-left:auto;display:flex;gap:8px;">
          <input v-model="q" class="form-input" placeholder="搜索用户…" style="width:180px;padding:6px 11px;" @keyup.enter="load" />
        </div>
      </div>
      <div class="table-wrap">
        <table class="table">
          <thead><tr><th>用户</th><th>公司</th><th>国家</th><th>等级</th><th>订单数</th><th>累计GMV</th><th>状态</th><th>操作</th></tr></thead>
          <tbody>
            <tr v-for="u in users" :key="u.id">
              <td>
                <div style="display:flex;gap:8px;align-items:center;">
                  <div class="user-av">{{ u.name?.slice(0,1)||u.phone?.slice(-4,0)||'?' }}</div>
                  <div><div style="font-weight:600;font-size:13px;">{{ u.name||'—' }}</div><div class="text-muted" style="font-size:11px;">{{ u.phone }}</div></div>
                </div>
              </td>
              <td style="font-size:12px;color:var(--t3);max-width:150px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{ u.company_name||'—' }}</td>
              <td style="font-size:12px;">{{ u.country||'—' }}</td>
              <td><span :class="['tag', u.level==='platinum'?'tag-purple':u.level==='gold'?'tag-gold':u.level==='silver'?'tag-gray':'tag-gray']">{{ u.level||'bronze' }}</span></td>
              <td style="font-weight:600;">{{ u._count?.ordersAsBuyer||0 }}</td>
              <td class="text-primary" style="font-weight:700;">{{ fmtMoney(u.total_gmv) }}</td>
              <td><span :class="['badge', {active:'badge-active',pending:'badge-pending',suspended:'badge-danger'}[u.status]||'badge-gray']">{{ {active:'正常',pending:'待审核',suspended:'已封禁'}[u.status]||u.status }}</span></td>
              <td>
                <div style="display:flex;gap:5px;">
                  <button v-if="u.status==='active'"    class="btn btn-sm btn-danger"  @click="act(u,'suspend')">封禁</button>
                  <button v-if="u.status==='suspended'" class="btn btn-sm btn-outline" @click="act(u,'activate')">解封</button>
                  <button v-if="u.status==='pending'"   class="btn btn-sm btn-primary" @click="act(u,'verify')">认证</button>
                </div>
              </td>
            </tr>
            <tr v-if="!users.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">👥</div><div class="empty-text">暂无用户</div></div></td></tr>
          </tbody>
        </table>
      </div>
    </div>
    <div class="pagination" v-if="totalPages>1"><button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;load()">上一页</button><span class="page-info">{{ page }} / {{ totalPages }}</span><button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;load()">下一页</button></div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { adminApi } from '@/api'
const toast = inject('toast',()=>{})
const users=[...Array(0)].map(()=>({})); const usersR=ref([]); const total=ref(0); const page=ref(1); const totalPages=ref(1); const tab=ref('all'); const q=ref('')
const tabs=[{k:'all',l:'全部'},{k:'active',l:'正常'},{k:'pending',l:'待审核'},{k:'suspended',l:'已封禁'}]
function fmtMoney(v){ v=Number(v)||0; return v>=10000000?'¥'+(v/10000).toFixed(0)+'万':v>=10000?'¥'+(v/10000).toFixed(1)+'万':v?'¥'+v.toLocaleString():'¥0' }
async function load(){ const p={page:page.value}; if(tab.value!=='all') p.status=tab.value; if(q.value) p.q=q.value; const r=await adminApi.users(p); if(r.code===0){usersR.value=r.data||[];total.value=r.total||0;totalPages.value=r.total_pages||1} }
const users2=usersR
async function act(u,action){ const r=await adminApi.updateUser(u.id,{action}); if(r.code===0){toast('操作成功');load()}else toast(r.msg,'error') }
onMounted(load)
</script>
<script>export default { computed:{ users(){ return this.users2 } } }</script>
<style scoped>
.page-pad{padding:22px 24px;}
.user-av{width:30px;height:30px;border-radius:7px;background:linear-gradient(135deg,var(--blue),#5e5ce6);color:#fff;font-size:12px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;}
.pagination{display:flex;align-items:center;justify-content:center;gap:12px;margin-top:14px;}
.page-info{font-size:13px;color:var(--t3);}
</style>
