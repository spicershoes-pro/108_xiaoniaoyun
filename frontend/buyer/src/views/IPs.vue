<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header"><h1 class="page-title">🎨 IP授权中心</h1><span class="text-muted">正版授权 · 商业合规</span></div>
    <div style="display:flex;gap:8px;margin-bottom:16px;flex-wrap:wrap;">
      <button v-for="c in cats" :key="c" :class="['btn btn-sm', cat===c?'btn-primary':'btn-ghost']" @click="cat=c;load()">{{c}}</button>
    </div>
    <div v-if="loading" style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px;">
      <div v-for="i in 6" :key="i" class="skel" style="height:200px;border-radius:12px;"/>
    </div>
    <div v-else class="ip-grid">
      <div v-for="ip in list" :key="ip.id" class="ip-card">
        <div class="ip-cover">
          <span class="ip-em">{{ ip.emoji }}</span>
          <span class="tag tag-red hot-tag" v-if="ip.is_hot">🔥 热门</span>
        </div>
        <div class="ip-body">
          <div class="ip-name">{{ ip.name }}</div>
          <div class="ip-meta text-muted">{{ ip.origin }} · {{ ip.licensor }}</div>
          <div style="display:flex;gap:6px;margin:8px 0;">
            <span class="tag tag-blue">{{ ip.category }}</span>
            <span class="tag" :class="ip.status==='active'?'tag-green':ip.status==='expiring'?'tag-orange':'tag-gray'">{{ ip.status==='active'?'可申请':ip.status==='expiring'?'即将到期':'洽谈中' }}</span>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center;">
            <div style="font-size:12px;color:var(--t4);">分成比例 <span style="font-weight:700;color:var(--blue);">{{ ip.revenue_share||'TBD' }}</span></div>
            <button class="btn btn-sm btn-primary" :disabled="ip.status==='negotiating'" @click="openApply(ip)">申请授权</button>
          </div>
        </div>
      </div>
    </div>

    <!-- 申请弹窗 -->
    <div class="modal-overlay" v-if="applyTarget" @click.self="applyTarget=null">
      <div class="modal-box">
        <div class="modal-hd"><span class="modal-title">申请 {{ applyTarget.name }} 授权</span><button class="modal-close" @click="applyTarget=null">✕</button></div>
        <div class="modal-body">
          <div style="display:flex;gap:12px;align-items:center;background:var(--bg0);border-radius:10px;padding:12px;margin-bottom:16px;">
            <span style="font-size:36px;">{{ applyTarget.emoji }}</span>
            <div><div style="font-weight:700;">{{ applyTarget.name }}</div><div style="font-size:12px;color:var(--t4);">{{ applyTarget.licensor }} · 分成 {{ applyTarget.revenue_share }}</div></div>
          </div>
          <div class="form-group"><label class="form-label">申请公司 *</label><input v-model="applyForm.company" class="form-input" placeholder="您的公司名称"/></div>
          <div class="form-group"><label class="form-label">授权产品 *</label><input v-model="applyForm.product" class="form-input" placeholder="计划生产的产品名称"/></div>
          <div class="form-group"><label class="form-label">年预计数量</label><input v-model.number="applyForm.annual_qty" type="number" class="form-input" placeholder="件/年"/></div>
          <div class="form-group"><label class="form-label">使用目的</label><textarea v-model="applyForm.purpose" class="form-input" rows="2" placeholder="简述产品用途和销售计划"/></div>
        </div>
        <div class="modal-ft">
          <button class="btn btn-ghost" @click="applyTarget=null">取消</button>
          <button class="btn btn-primary" :disabled="submitting" @click="doApply">{{ submitting?'提交中…':'提交申请' }}</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, reactive, inject, onMounted } from 'vue'
import { discoverApi } from '@/api'
const toast=inject('toast',()=>{}); const list=ref([]); const loading=ref(false); const cat=ref('全部'); const applyTarget=ref(null); const submitting=ref(false)
const cats=['全部','经典IP','动画IP','潮流IP','英雄IP']
const applyForm=reactive({company:'',product:'',annual_qty:'',purpose:''})
async function load(){ loading.value=true; const r=await discoverApi.ips(cat.value!=='全部'?{category:cat.value}:{}); loading.value=false; if(r.code===0)list.value=r.data.list||[] }
function openApply(ip){ applyTarget.value=ip; applyForm.company='';applyForm.product='';applyForm.annual_qty='';applyForm.purpose='' }
async function doApply(){
  if(!applyForm.company||!applyForm.product){toast('请填写必填项','warning');return}
  submitting.value=true; const r=await discoverApi.applyIp({ip_id:applyTarget.value.id,...applyForm}); submitting.value=false
  if(r.code===0){toast('IP授权申请已提交，平台将在3个工作日内回复 ✅');applyTarget.value=null}else toast(r.msg,'error')
}
onMounted(load)
</script>
<style scoped>
.ip-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;}
.ip-card{background:#fff;border:1px solid var(--border);border-radius:var(--r12);overflow:hidden;transition:all .15s;}
.ip-card:hover{border-color:var(--blue);box-shadow:var(--sh);transform:translateY(-2px);}
.ip-cover{height:120px;display:flex;align-items:center;justify-content:center;background:linear-gradient(135deg,var(--blue-xl),var(--purple-l,#F9F0FF));position:relative;}
.ip-em{font-size:56px;}
.hot-tag{position:absolute;top:8px;right:8px;}
.ip-body{padding:14px;}
.ip-name{font-size:16px;font-weight:800;color:var(--t1);}
.ip-meta{font-size:12px;margin:3px 0;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center;}
.modal-box{background:#fff;border-radius:16px;width:480px;max-height:88vh;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden;}
.modal-hd{display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border);}
.modal-title{font-size:15px;font-weight:700;}.modal-close{background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;}
.modal-body{padding:18px 24px;overflow-y:auto;flex:1;}.modal-ft{padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px;}
</style>