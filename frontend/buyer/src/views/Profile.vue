<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header"><h1 class="page-title">我的账号</h1></div>
    <div style="display:grid;grid-template-columns:280px 1fr;gap:20px;">
      <!-- 左：用户卡 -->
      <div>
        <div class="card card-body" style="text-align:center;margin-bottom:14px;">
          <div class="profile-av">{{ (user?.name||user?.phone||'?').slice(0,1) }}</div>
          <div class="profile-name">{{ user?.name || '未设置姓名' }}</div>
          <div class="profile-phone text-muted">{{ user?.phone }}</div>
          <div style="margin-top:10px;">
            <span :class="['tag', levelTag]">{{ levelLabel }}</span>
            <span class="tag tag-green" v-if="user?.buyer_profile?.verified" style="margin-left:6px;">✓ 已认证</span>
          </div>
          <div style="margin-top:14px;padding-top:14px;border-top:1px solid var(--t6);">
            <div style="display:flex;justify-content:space-around;">
              <div style="text-align:center;"><div style="font-size:20px;font-weight:800;color:var(--blue);">{{ stats.orders }}</div><div style="font-size:12px;color:var(--t4);">订单</div></div>
              <div style="text-align:center;"><div style="font-size:20px;font-weight:800;color:var(--blue);">{{ stats.inquiries }}</div><div style="font-size:12px;color:var(--t4);">询盘</div></div>
              <div style="text-align:center;"><div style="font-size:20px;font-weight:800;color:var(--blue);">{{ stats.favorites }}</div><div style="font-size:12px;color:var(--t4);">收藏</div></div>
            </div>
          </div>
        </div>
        <div class="card" style="overflow:hidden;">
          <router-link v-for="l in links" :key="l.to" :to="l.to" class="profile-link">
            <span>{{l.icon}}</span><span>{{l.label}}</span><span style="color:var(--t4);margin-left:auto;">›</span>
          </router-link>
          <div class="profile-link" style="cursor:pointer;color:var(--red);" @click="doLogout">
            <span>🚪</span><span>退出登录</span>
          </div>
        </div>
      </div>

      <!-- 右：编辑信息 -->
      <div class="card card-body">
        <div class="card-title" style="margin-bottom:16px;">基本信息</div>
        <div class="form-group"><label class="form-label">姓名</label><input v-model="editForm.name" class="form-input" placeholder="请输入真实姓名"/></div>
        <div class="form-group"><label class="form-label">邮箱</label><input v-model="editForm.email" class="form-input" placeholder="your@email.com" type="email"/></div>
        <div class="form-group"><label class="form-label">公司名称</label><input v-model="editForm.company" class="form-input" placeholder="采购公司名称"/></div>
        <div class="form-group"><label class="form-label">所在国家</label>
          <select v-model="editForm.country" class="form-input form-select">
            <option value="">请选择</option>
            <option v-for="c in countries" :key="c.code" :value="c.code">{{ c.flag }} {{ c.name }}</option>
          </select>
        </div>
        <button class="btn btn-primary" :disabled="saving" @click="doSave">{{ saving?'保存中…':'保存修改' }}</button>
        <div style="margin-top:24px;padding-top:20px;border-top:1px solid var(--t6);">
          <div class="card-title" style="margin-bottom:12px;">信用概况</div>
          <div style="display:flex;align-items:center;gap:12px;background:var(--bg0);border-radius:10px;padding:14px;">
            <div style="font-size:36px;font-weight:900;color:var(--blue);">{{ user?.buyer_profile?.credit_score || 100 }}</div>
            <div>
              <div style="font-size:13px;font-weight:700;color:var(--t1);">信用分</div>
              <div style="font-size:12px;color:var(--t4);">累计 GMV ¥{{ fmtM(user?.buyer_profile?.total_gmv) }}</div>
            </div>
            <div style="margin-left:auto;"><div class="progress" style="width:120px;"><div class="progress-fill" :style="{width:(user?.buyer_profile?.credit_score||100)+'%'}"/></div></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, reactive, computed, inject, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'
const toast=inject('toast',()=>{}); const router=useRouter(); const auth=useAuthStore()
const user=computed(()=>auth.user); const saving=ref(false)
const stats=computed(()=>user.value?.stats||{orders:0,inquiries:0,favorites:0})
const levelTag=computed(()=>({platinum:'tag-purple',gold:'tag-gold',silver:'tag-gray',bronze:'tag-gray'}[user.value?.buyer_profile?.level]||'tag-gray'))
const levelLabel=computed(()=>({platinum:'💎 铂金买家',gold:'🥇 黄金买家',silver:'🥈 银牌买家',bronze:'🥉 普通买家'}[user.value?.buyer_profile?.level]||'普通买家'))
const editForm=reactive({name:user.value?.name||'',email:user.value?.email||'',company:user.value?.buyer_profile?.company_name||'',country:user.value?.buyer_profile?.country||''})
const links=[{icon:'📦',label:'我的订单',to:'/orders'},{icon:'📨',label:'我的询盘',to:'/inquiries'},{icon:'❤️',label:'收藏夹',to:'/favorites'},{icon:'🎁',label:'样品申请',to:'/samples'},{icon:'💬',label:'消息中心',to:'/messages'}]
const countries=[{code:'CN',flag:'🇨🇳',name:'中国'},{code:'US',flag:'🇺🇸',name:'美国'},{code:'JP',flag:'🇯🇵',name:'日本'},{code:'GB',flag:'🇬🇧',name:'英国'},{code:'DE',flag:'🇩🇪',name:'德国'},{code:'FR',flag:'🇫🇷',name:'法国'},{code:'KR',flag:'🇰🇷',name:'韩国'},{code:'AE',flag:'🇦🇪',name:'阿联酋'},{code:'SG',flag:'🇸🇬',name:'新加坡'},{code:'VN',flag:'🇻🇳',name:'越南'}]
function fmtM(v){v=Number(v)||0;return v>=10000?Math.round(v/10000)+'万':v.toLocaleString()}
async function doSave(){saving.value=true;await new Promise(r=>setTimeout(r,600));saving.value=false;toast('信息已保存 ✅')}
function doLogout(){auth.logout();router.push('/')}
onMounted(()=>{ if(user.value){editForm.name=user.value.name||'';editForm.email=user.value.email||'' } })
</script>
<style scoped>
.profile-av{width:64px;height:64px;border-radius:16px;background:linear-gradient(135deg,var(--blue),#5e5ce6);color:#fff;font-size:26px;font-weight:700;display:flex;align-items:center;justify-content:center;margin:0 auto 10px;}
.profile-name{font-size:17px;font-weight:700;color:var(--t1);}
.profile-phone{font-size:13px;margin-top:4px;}
.profile-link{display:flex;align-items:center;gap:10px;padding:12px 16px;border-bottom:1px solid var(--t6);font-size:13px;color:var(--t2);text-decoration:none;transition:background .12s;}
.profile-link:last-child{border:none;}
.profile-link:hover{background:var(--bg0);}
.tag-gold{background:#FFFBE6;color:#D48806;}.tag-purple{background:#F9F0FF;color:#722ED1;}
</style>