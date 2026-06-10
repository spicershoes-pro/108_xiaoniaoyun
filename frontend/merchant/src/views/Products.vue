<!-- src/views/Products.vue -->
<template>
  <div class="page-pad">
    <div class="page-header">
      <h1 class="page-title">产品管理</h1>
      <button class="btn btn-primary" @click="showAdd=true">+ 新增产品</button>
    </div>
    <div class="filter-bar card" style="margin-bottom:14px;display:flex;gap:6px;padding:10px 14px;align-items:center;">
      <button v-for="t in tabs" :key="t.k" :class="['btn btn-sm', tab===t.k?'btn-primary':'btn-ghost']" @click="tab=t.k;load()">{{ t.l }}</button>
      <div style="margin-left:auto;">
        <input v-model="q" class="form-input" placeholder="搜索产品…" style="width:180px;padding:6px 11px;" @keyup.enter="load" />
      </div>
    </div>
    <div class="card">
      <div class="table-wrap">
        <table class="table">
          <thead><tr><th>产品</th><th>SKU</th><th>价格/MOQ</th><th>库存</th><th>30日销量</th><th>评分</th><th>状态</th><th>操作</th></tr></thead>
          <tbody>
            <tr v-for="p in products" :key="p.id">
              <td>
                <div style="display:flex;gap:10px;align-items:center;">
                  <div :style="{width:'40px',height:'40px',borderRadius:'9px',background:p.cover_color||'#EFF6FF',display:'flex',alignItems:'center',justifyContent:'center',fontSize:'20px',flexShrink:0}">{{ p.emoji||'🧸' }}</div>
                  <div>
                    <div style="font-weight:600;color:var(--t1);font-size:13px;">{{ p.name }}</div>
                    <div class="text-muted" style="font-size:11px;">{{ p.category }}</div>
                  </div>
                </div>
              </td>
              <td class="mono">{{ p.sku }}</td>
              <td><div class="text-primary" style="font-weight:700;">¥{{ p.base_price }}</div><div class="text-muted" style="font-size:11px;">MOQ {{ p.moq }}件</div></td>
              <td style="font-weight:600;">{{ p.stock?.toLocaleString() }}</td>
              <td style="font-weight:600;">{{ p.sales_count?.toLocaleString() }}</td>
              <td>
                <div v-if="p.rating>0" style="color:var(--gold);font-size:12px;">{{ '★'.repeat(Math.round(p.rating)) }} {{ p.rating }}</div>
                <span v-else class="text-muted" style="font-size:12px;">—</span>
              </td>
              <td>
                <span :class="['badge', {online:'badge-active',offline:'badge-gray',pending:'badge-pending',rejected:'badge-danger'}[p.status]||'badge-gray']">
                  {{ {online:'上架中',offline:'已下架',pending:'待审核',draft:'草稿',rejected:'已拒绝'}[p.status]||p.status }}
                </span>
              </td>
              <td>
                <div style="display:flex;gap:5px;">
                  <button class="btn btn-sm btn-ghost">编辑</button>
                  <button class="btn btn-sm btn-ghost" @click="toggleStatus(p)">
                    {{ p.status==='online'?'下架':'申请上架' }}
                  </button>
                </div>
              </td>
            </tr>
            <tr v-if="!products.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">🧸</div><div class="empty-text">暂无产品</div></div></td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 新增弹窗 -->
    <div class="modal-overlay" v-if="showAdd" @click.self="showAdd=false">
      <div class="modal-box" style="width:560px;">
        <div class="modal-hd"><span class="modal-title">新增产品</span><button class="modal-close" @click="showAdd=false">✕</button></div>
        <div class="modal-body">
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <div class="form-group"><label class="form-label">产品名称 *</label><input v-model="form.name" class="form-input" placeholder="请输入产品名称"/></div>
            <div class="form-group"><label class="form-label">产品类目 *</label>
              <select v-model="form.category" class="form-input form-select">
                <option v-for="c in catOpts" :key="c">{{ c }}</option>
              </select>
            </div>
            <div class="form-group"><label class="form-label">基础价格（元）*</label><input v-model.number="form.base_price" type="number" class="form-input" placeholder="0.00"/></div>
            <div class="form-group"><label class="form-label">MOQ（件）*</label><input v-model.number="form.moq" type="number" class="form-input" placeholder="100"/></div>
            <div class="form-group"><label class="form-label">交期（工作日）</label><input v-model.number="form.lead_time" type="number" class="form-input" placeholder="15"/></div>
            <div class="form-group"><label class="form-label">初始库存</label><input v-model.number="form.stock" type="number" class="form-input" placeholder="0"/></div>
          </div>
          <div class="form-group"><label class="form-label">产品描述</label><textarea v-model="form.description" class="form-input" rows="3" placeholder="材质、功能、认证等…"/></div>
          <div class="form-group"><label class="form-label">认证资质</label>
            <div style="display:flex;gap:10px;flex-wrap:wrap;">
              <label v-for="c in certOpts" :key="c" style="display:flex;align-items:center;gap:4px;cursor:pointer;font-size:13px;">
                <input type="checkbox" :value="c" v-model="form.certs" /> {{ c }}
              </label>
            </div>
          </div>
        </div>
        <div class="modal-ft">
          <button class="btn btn-ghost" @click="showAdd=false">取消</button>
          <button class="btn btn-primary" :disabled="submitting" @click="doCreate">{{ submitting?'提交中…':'提交审核' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, reactive, inject, onMounted } from 'vue'
import { productApi } from '@/api'
const toast = inject('toast', ()=>{})
const products  = ref([])
const tab       = ref('all')
const q         = ref('')
const showAdd   = ref(false)
const submitting= ref(false)
const tabs = [{k:'all',l:'全部'},{k:'online',l:'上架中'},{k:'pending',l:'待审核'},{k:'offline',l:'已下架'}]
const catOpts  = ['遥控玩具','益智玩具','户外玩具','毛绒玩具','科技玩具','传统玩具']
const certOpts = ['CE','EN71','ASTM','ISO9001','BSCI']
const form = reactive({ name:'',category:'遥控玩具',base_price:'',moq:100,lead_time:15,stock:0,description:'',certs:[] })
async function load(){
  const params = { status: tab.value==='all'?'all':tab.value }
  if(q.value) params.q = q.value
  const res = await productApi.list(params)
  if(res.code===0) products.value = res.data||[]
}
async function toggleStatus(p){
  const newStatus = p.status==='online' ? 'offline' : 'pending'
  const res = await productApi.toggle(p.id, newStatus)
  if(res.code===0){ toast(newStatus==='offline'?'产品已下架':'已提交上架申请'); load() }
  else toast(res.msg,'error')
}
async function doCreate(){
  if(!form.name||!form.base_price){ toast('请填写必填字段','warning'); return }
  submitting.value=true
  const res = await productApi.create({...form})
  submitting.value=false
  if(res.code===0){ toast('产品已提交审核 ✅'); showAdd.value=false; load() }
  else toast(res.msg,'error')
}
onMounted(load)
</script>
<style scoped>
.page-pad { padding:22px 24px; }
.modal-overlay { position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center; }
.modal-box { background:#fff;border-radius:16px;max-height:85vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden; }
.modal-hd { display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border); }
.modal-title { font-size:16px;font-weight:700; }
.modal-close { background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer; }
.modal-body { padding:18px 24px;overflow-y:auto;flex:1; }
.modal-ft { padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px; }
</style>
