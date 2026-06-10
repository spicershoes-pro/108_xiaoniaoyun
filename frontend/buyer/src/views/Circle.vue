<template>
  <div class="page-container" style="padding-top:28px;padding-bottom:40px;">
    <div class="page-header">
      <h1 class="page-title">💬 玩具圈</h1>
      <button class="btn btn-primary" v-if="auth.isLoggedIn" @click="showPost=true">+ 发帖</button>
      <router-link v-else to="/login" class="btn btn-primary">登录后发帖</router-link>
    </div>
    <div style="display:flex;gap:8px;margin-bottom:16px;">
      <button v-for="t in tabs" :key="t.k" :class="['btn btn-sm', tab===t.k?'btn-primary':'btn-ghost']" @click="tab=t.k;load()">{{t.l}}</button>
    </div>
    <div v-if="loading" style="display:flex;flex-direction:column;gap:12px;"><div v-for="i in 3" :key="i" class="skel" style="height:120px;border-radius:12px;"/></div>
    <div v-else style="display:flex;flex-direction:column;gap:12px;">
      <div v-for="post in posts" :key="post.id" class="post-card card">
        <div class="post-hd">
          <div class="post-av">{{ post.author_name?.slice(0,1)||'?' }}</div>
          <div style="flex:1;">
            <div style="font-size:13px;font-weight:700;color:var(--t1);">{{ post.author_name }}</div>
            <div style="display:flex;gap:6px;margin-top:2px;">
              <span :class="['tag',post.author_role==='merchant'?'tag-green':post.author_role==='admin'||post.author_role==='super_admin'?'tag-blue':'tag-gray']" style="font-size:10px;">{{post.author_role==='merchant'?'工厂':post.author_role==='admin'||post.author_role==='super_admin'?'官方':'买家'}}</span>
              <span style="font-size:11px;color:var(--t4);">{{ post.created_at?.slice(0,10) }}</span>
            </div>
          </div>
        </div>
        <div class="post-content">{{ post.content }}</div>
        <div class="post-ft">
          <span style="font-size:12px;color:var(--t4);">❤️ {{ post.likes }}</span>
          <span style="font-size:12px;color:var(--t4);">💬 {{ post.comments }}</span>
        </div>
      </div>
      <div v-if="!posts.length" class="empty-state"><div class="empty-icon">📝</div><div class="empty-text">暂无帖子</div></div>
    </div>

    <!-- 发帖弹窗 -->
    <div class="modal-overlay" v-if="showPost" @click.self="showPost=false">
      <div class="modal-box">
        <div class="modal-hd"><span class="modal-title">发布帖子</span><button class="modal-close" @click="showPost=false">✕</button></div>
        <div class="modal-body">
          <div class="form-group"><label class="form-label">内容 *（至少5字）</label><textarea v-model="postContent" class="form-input" rows="5" placeholder="分享采购经验、选品心得、工厂评价…" style="resize:none;"/></div>
          <div style="font-size:12px;color:var(--t4);">发布后需经平台审核，审核通过后公开显示。</div>
        </div>
        <div class="modal-ft"><button class="btn btn-ghost" @click="showPost=false">取消</button><button class="btn btn-primary" :disabled="submitting||postContent.length<5" @click="doPost">{{ submitting?'发布中…':'发布' }}</button></div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { discoverApi } from '@/api'
import { useAuthStore } from '@/stores/auth'
const toast=inject('toast',()=>{}); const auth=useAuthStore()
const posts=ref([]); const loading=ref(false); const tab=ref('all'); const showPost=ref(false); const postContent=ref(''); const submitting=ref(false)
const tabs=[{k:'all',l:'全部'},{k:'factory',l:'工厂动态'},{k:'platform',l:'官方资讯'},{k:'buyer',l:'买家圈'}]
async function load(){ loading.value=true; const r=await discoverApi.posts(tab.value!=='all'?{type:tab.value}:{}); loading.value=false; if(r.code===0)posts.value=r.data||[] }
async function doPost(){
  if(postContent.value.length<5) return
  submitting.value=true; const r=await discoverApi.createPost({content:postContent.value}); submitting.value=false
  if(r.code===0){toast('帖子已提交审核 ✅');showPost.value=false;postContent.value='';load()}else toast(r.msg,'error')
}
onMounted(load)
</script>
<style scoped>
.post-card{padding:16px;}
.post-hd{display:flex;gap:10px;align-items:flex-start;margin-bottom:10px;}
.post-av{width:36px;height:36px;border-radius:9px;background:linear-gradient(135deg,var(--blue),#5e5ce6);color:#fff;font-size:15px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;}
.post-content{font-size:13px;color:var(--t2);line-height:1.7;margin-bottom:10px;}
.post-ft{display:flex;gap:14px;}
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:center;justify-content:center;}
.modal-box{background:#fff;border-radius:16px;width:480px;display:flex;flex-direction:column;box-shadow:0 20px 60px rgba(0,0,0,.2);overflow:hidden;}
.modal-hd{display:flex;align-items:center;justify-content:space-between;padding:18px 24px;border-bottom:1px solid var(--border);}
.modal-title{font-size:15px;font-weight:700;}.modal-close{background:var(--t6);border:none;width:28px;height:28px;border-radius:6px;cursor:pointer;}
.modal-body{padding:18px 24px;}.modal-ft{padding:14px 24px;border-top:1px solid var(--border);display:flex;justify-content:flex-end;gap:8px;}
</style>