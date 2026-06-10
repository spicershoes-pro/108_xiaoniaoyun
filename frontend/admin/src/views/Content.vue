<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">内容管理</h1></div>
    <div class="tab-row"><button v-for="t in tabs" :key="t.k" :class="['tab-btn',curTab===t.k?'active':'']" @click="curTab=t.k;load()">{{t.l}}</button></div>
    <!-- 帖子列表 -->
    <div class="card" v-if="curTab==='posts'">
      <div class="table-wrap"><table class="table">
        <thead><tr><th>作者</th><th>身份</th><th>内容</th><th>点赞</th><th>举报</th><th>状态</th><th>时间</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="p in posts" :key="p.id" :style="{background:p.reports>5?'#FFF1F0':''}">
            <td style="font-weight:600;font-size:13px;">{{p.author_name}}</td>
            <td><span :class="['tag',p.author_role==='super_admin'||p.author_role==='admin'?'tag-blue':p.author_role==='merchant'?'tag-green':'tag-gray']">{{p.author_role==='merchant'?'工厂':p.author_role==='admin'||p.author_role==='super_admin'?'官方':'买家'}}</span></td>
            <td style="font-size:12px;color:var(--t3);max-width:220px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{p.content}}</td>
            <td style="font-weight:600;">{{p.likes}}</td>
            <td><span :style="{color:p.reports>5?'var(--red)':p.reports>0?'var(--orange)':'var(--t4)',fontWeight:p.reports>0?700:400}">{{p.reports>0?`⚠ ${p.reports}`:'0'}}</span></td>
            <td><span :class="['badge',{reviewing:'badge-pending',published:'badge-active',rejected:'badge-gray',deleted:'badge-gray'}[p.status]||'badge-gray']">{{sL(p.status)}}</span></td>
            <td style="font-size:11px;color:var(--t4);">{{p.created_at?.slice(0,10)}}</td>
            <td><div style="display:flex;gap:5px;">
              <button v-if="p.status==='reviewing'" class="btn btn-sm btn-primary" @click="act(p,'approve')">通过</button>
              <button v-if="p.status==='reviewing'||p.reports>5" class="btn btn-sm btn-danger" @click="act(p,'delete')">删除</button>
            </div></td>
          </tr>
          <tr v-if="!posts.length"><td colspan="8"><div class="empty-state"><div class="empty-icon">📝</div><div class="empty-text">暂无内容</div></div></td></tr>
        </tbody>
      </table></div>
    </div>
    <!-- Banner -->
    <div class="card" v-if="curTab==='banners'">
      <div style="padding:10px 16px;border-bottom:1px solid var(--t6);display:flex;justify-content:flex-end;"><button class="btn btn-primary btn-sm">+ 新增Banner</button></div>
      <div class="table-wrap"><table class="table">
        <thead><tr><th>预览</th><th>标题</th><th>位置</th><th>点击量</th><th>状态</th><th>操作</th></tr></thead>
        <tbody>
          <tr v-for="b in banners" :key="b.id">
            <td><div :style="{width:'80px',height:'32px',background:b.bg_style,borderRadius:'6px',display:'flex',alignItems:'center',justifyContent:'center'}"><span style="font-size:11px;font-weight:700;color:#fff;">{{b.title?.slice(0,4)}}</span></div></td>
            <td style="font-weight:600;font-size:13px;">{{b.title}}</td>
            <td><span class="tag tag-blue">位置 {{b.position}}</span></td>
            <td style="font-weight:700;color:var(--blue);">{{(b.clicks||0).toLocaleString()}}</td>
            <td><span :class="['badge',b.status==='active'?'badge-active':b.status==='paused'?'badge-pending':'badge-gray']">{{b.status==='active'?'上线中':b.status==='paused'?'已暂停':'草稿'}}</span></td>
            <td><div style="display:flex;gap:5px;"><button class="btn btn-sm btn-ghost">编辑</button><button v-if="b.status==='active'" class="btn btn-sm btn-warning" @click="toast('Banner已暂停','warning')">暂停</button><button v-if="b.status==='draft'" class="btn btn-sm btn-primary" @click="toast('Banner已上线')">发布</button></div></td>
          </tr>
        </tbody>
      </table></div>
    </div>
  </div>
</template>
<script setup>
import { ref, inject, onMounted } from 'vue'
import { adminApi, discoverApi } from '@/api'
const toast=inject('toast',()=>{})
const posts=ref([]);const banners=ref([]);const curTab=ref('posts')
const tabs=[{k:'posts',l:'玩具圈帖子'},{k:'banners',l:'首页Banner'}]
function sL(s){return{reviewing:'待审核',published:'已发布',rejected:'已拒绝',deleted:'已删除'}[s]||s}
async function load(){
  if(curTab.value==='posts'){const r=await adminApi.content();if(r.code===0)posts.value=r.data||[]}
  else{const r=await discoverApi.banners();if(r.code===0)banners.value=r.data||[]}
}
async function act(p,action){const r=await adminApi.updateContent(p.id,{action});if(r.code===0){toast('操作成功');load()}else toast(r.msg,'error')}
onMounted(load)
</script>
<style scoped>
.page-pad{padding:22px 24px;}
.tab-row{display:flex;border-bottom:1px solid var(--border);margin-bottom:16px;background:#fff;border-radius:10px 10px 0 0;padding:0 16px;}
.tab-btn{padding:11px 16px;border:none;background:none;font-size:13px;font-weight:500;color:var(--t4);cursor:pointer;border-bottom:2px solid transparent;margin-bottom:-1px;transition:all .15s;}
.tab-btn.active{color:var(--blue);border-bottom-color:var(--blue);font-weight:700;}
</style>