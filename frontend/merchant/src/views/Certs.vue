<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">资质认证</h1><button class="btn btn-primary">+ 上传证书</button></div>
    <div class="card" style="margin-bottom:16px;" v-if="expiring.length">
      <div style="display:flex;align-items:center;gap:12px;background:var(--orange-l);border:1px solid #ffd591;border-radius:10px;padding:12px 16px;margin:14px;">
        <span style="font-size:20px;">⚠️</span>
        <div style="flex:1;font-size:13px;"><strong style="color:#D46B08;">认证即将到期提醒</strong><div class="text-muted" style="margin-top:2px;">{{ expiring.map(c=>c.name).join('、') }} 证书即将到期，请及时更新</div></div>
      </div>
    </div>
    <div class="certs-grid">
      <div v-for="c in certs" :key="c.id" class="cert-card card">
        <div class="cert-badge" :class="c.status">{{ c.name }}</div>
        <div class="cert-info">
          <div class="cert-issuer text-muted">{{ c.issuer||'—' }}</div>
          <div class="cert-date">
            <span style="font-size:12px;color:var(--t4);">到期：</span>
            <span :style="{fontWeight:600,color:c.status==='expired'?'var(--red)':c.status==='expiring'?'var(--orange)':'var(--t1)'}">
              {{ c.expires_at?.slice(0,10)||'—' }}
            </span>
          </div>
          <span :class="['tag',c.status==='valid'?'tag-green':c.status==='expiring'?'tag-orange':'tag-red']" style="margin-top:8px;display:inline-flex;">
            {{ {valid:'有效',expiring:'即将到期',expired:'已过期'}[c.status]||c.status }}
          </span>
        </div>
        <div class="cert-actions">
          <button class="btn btn-sm btn-ghost">查看</button>
          <button class="btn btn-sm btn-outline">更新</button>
        </div>
      </div>
      <!-- 可申请的认证 -->
      <div v-for="c in availableCerts" :key="c" class="cert-card cert-empty card">
        <div class="cert-badge empty">{{ c }}</div>
        <div class="cert-info"><div style="font-size:13px;color:var(--t4);margin-top:6px;">暂未认证</div></div>
        <div class="cert-actions"><button class="btn btn-sm btn-primary">申请认证</button></div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, computed, onMounted } from 'vue'
import { profileApi } from '@/api'
const certs=ref([]); const allCerts=['CE','EN71','ASTM','ISO9001','BSCI','ICES']
const expiring=computed(()=>certs.value.filter(c=>c.status==='expiring'||c.status==='expired'))
const availableCerts=computed(()=>allCerts.filter(n=>!certs.value.find(c=>c.name===n)))
onMounted(async()=>{ const r=await profileApi.get(); if(r.code===0)certs.value=r.data?.certs||[] })
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.certs-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;}
.cert-card{padding:18px;display:flex;flex-direction:column;gap:10px;}
.cert-empty{opacity:.6;}
.cert-badge{display:inline-flex;align-items:center;justify-content:center;padding:8px 16px;border-radius:8px;font-size:18px;font-weight:800;background:linear-gradient(135deg,var(--blue),#5e5ce6);color:#fff;width:fit-content;}
.cert-badge.expiring{background:linear-gradient(135deg,var(--orange),#fa541c);}
.cert-badge.expired{background:var(--t5);color:var(--t4);}
.cert-badge.empty{background:var(--t6);color:var(--t4);font-size:15px;}
.cert-info{flex:1;}
.cert-issuer{font-size:12px;margin-bottom:4px;}
.cert-actions{display:flex;gap:6px;}
</style>