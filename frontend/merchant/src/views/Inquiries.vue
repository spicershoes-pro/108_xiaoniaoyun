<!-- src/views/Inquiries.vue -->
<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">询盘管理</h1></div>

    <div class="filter-bar card" style="margin-bottom:14px;display:flex;gap:6px;padding:10px 14px;">
      <button v-for="t in tabs" :key="t.k" :class="['btn btn-sm', tab===t.k?'btn-primary':'btn-ghost']"
              @click="tab=t.k; load()">{{ t.l }}</button>
    </div>

    <div class="card">
      <div class="table-wrap">
        <table class="table">
          <thead><tr><th>优先级</th><th>买家</th><th>产品</th><th>数量</th><th>报价</th><th>状态</th><th>时间</th><th>操作</th></tr></thead>
          <tbody>
            <tr v-for="inq in inquiries" :key="inq.id">
              <td><div :class="['prio-dot', inq.priority]"></div></td>
              <td>
                <div style="font-weight:600;color:var(--t1);">{{ inq.buyer_name }}</div>
                <div class="text-muted" style="font-size:11px;">{{ inq.buyer_company }} · {{ inq.buyer_country }}</div>
              </td>
              <td style="font-size:12px;color:var(--t3);max-width:140px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">
                {{ inq.items?.[0]?.product_name }}
              </td>
              <td class="text-primary" style="font-weight:700;">{{ inq.items?.[0]?.qty?.toLocaleString() }} 件</td>
              <td style="font-size:12px;">{{ inq.quote_price || '—' }}</td>
              <td>
                <span :class="['badge', sMap[inq.status]||'badge-gray']">
                  {{ {pending:'待回复',quoted:'已报价',negotiating:'洽谈中',converted:'已转化',closed:'已关闭'}[inq.status] }}
                </span>
              </td>
              <td class="text-muted" style="font-size:11px;">{{ inq.created_at?.slice(0,10) }}</td>
              <td>
                <div style="display:flex;gap:5px;">
                  <button class="btn btn-sm btn-outline" @click="openDetail(inq)">详情</button>
                  <button v-if="inq.status==='pending'" class="btn btn-sm btn-primary" @click="openQuote(inq)">报价</button>
                </div>
              </td>
            </tr>
            <tr v-if="!inquiries.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">📭</div><div class="empty-text">暂无询盘</div></div></td></tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 报价弹窗 -->
    <div class="modal-overlay" v-if="quoteTarget" @click.self="quoteTarget=null">
      <div class="modal-box">
        <div class="modal-hd"><span class="modal-title">回复报价</span><button class="modal-close" @click="quoteTarget=null">✕</button></div>
        <div class="modal-body">
          <div style="background:var(--bg0);border-radius:10px;padding:12px;margin-bottom:14px;">
            <div style="font-weight:600;">{{ quoteTarget?.buyer_name }} · {{ quoteTarget?.buyer_company }}</div>
            <div class="text-muted" style="font-size:12px;margin-top:4px;">{{ quoteTarget?.message }}</div>
          </div>
          <div class="form-group"><label class="form-label">报价（含单价/起订量）*</label><input v-model="quotePrice" class="form-input" placeholder="例：¥82/件，500件起"/></div>
          <div class="form-group"><label class="form-label">补充说明</label><textarea v-model="quoteNote" class="form-input" rows="3" placeholder="交期、认证说明、定制选项…"/></div>
        </div>
        <div class="modal-ft">
          <button class="btn btn-ghost" @click="quoteTarget=null">取消</button>
          <button class="btn btn-primary" :disabled="!quotePrice||sending" @click="doQuote">{{ sending?'发送中…':'发送报价' }}</button>
        </div>
      </div>
    </div>

    <!-- 询盘详情 -->
    <div class="modal-overlay" v-if="detailTarget" @click.self="detailTarget=null">
      <div class="modal-box">
        <div class="modal-hd"><span class="modal-title">询盘详情</span><button class="modal-close" @click="detailTarget=null">✕</button></div>
        <div class="modal-body">
          <div style="font-weight:700;margin-bottom:8px;">{{ detailTarget.buyer_name }} · {{ detailTarget.buyer_country }}</div>
          <div class="text-muted" style="font-size:12px;margin-bottom:12px;">{{ detailTarget.message }}</div>
          <div v-for="it in detailTarget.items" :key="it.id" style="padding:8px 0;border-top:1px solid var(--t6);font-size:13px;">
            {{ it.product_name }} × {{ it.qty?.toLocaleString() }} 件
          </div>
        </div>
        <div class="modal-ft">
          <button v-if="detailTarget.status==='pending'" class="btn btn-primary" @click="openQuote(detailTarget); detailTarget=null">去报价</button>
          <button class="btn btn-ghost" @click="detailTarget=null">关闭</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { inquiryApi } from '@/api'
const toast = inject('toast', ()=>{})
const inquiries  = ref([])
const tab        = ref('all')
const detailTarget = ref(null)
const quoteTarget= ref(null)
const quotePrice = ref('')
const quoteNote  = ref('')
const sending    = ref(false)
const tabs = [{k:'all',l:'全部'},{k:'pending',l:'待回复'},{k:'quoted',l:'已报价'},{k:'negotiating',l:'洽谈中'},{k:'closed',l:'已关闭'}]
const sMap = {pending:'badge-pending',quoted:'badge-info',negotiating:'badge-info',converted:'badge-success',closed:'badge-gray'}
async function load(){ const res = await inquiryApi.list(tab.value!=='all'?{status:tab.value}:{}); if(res.code===0) inquiries.value=res.data||[] }
function openDetail(inq){ detailTarget.value = inq }
function openQuote(inq){ quoteTarget.value=inq; quotePrice.value=''; quoteNote.value='' }
async function doQuote(){
  if(!quotePrice.value) return
  sending.value=true
  const res = await inquiryApi.quote(quoteTarget.value.id, {quote_price:quotePrice.value, quote_note:quoteNote.value})
  sending.value=false
  if(res.code===0){ toast('报价已发送给买家 ✅'); quoteTarget.value=null; load() }
  else toast(res.msg,'error')
}
onMounted(load)
</script>
<style scoped>
.page-pad { padding:22px 24px; }
.prio-dot { width:9px; height:9px; border-radius:50%; }
.prio-dot.high   { background:var(--red); }
.prio-dot.medium { background:var(--orange); }
.prio-dot.low    { background:var(--t5); }
.modal-overlay { position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center; }
.modal-box { background:#fff;border-radius:16px;width:480px;max-height:85vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden; }
.modal-hd  { display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border); }
.modal-title { font-size:16px;font-weight:700; }
.modal-close { background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;font-size:13px; }
.modal-body  { padding:18px 24px;overflow-y:auto;flex:1; }
.modal-ft    { padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px; }
</style>
