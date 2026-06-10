<template>
  <div style="display:flex;height:calc(100vh - 58px);overflow:hidden;">
    <div style="width:260px;border-right:1px solid var(--border);background:#fff;overflow-y:auto;">
      <div style="padding:14px 16px;border-bottom:1px solid var(--t6);font-size:14px;font-weight:700;">消息中心</div>
      <div v-for="c in convs" :key="c.id" :class="['conv-item', activeId===c.id?'active':'']" @click="open(c)">
        <div class="conv-av">{{ c.peer_display?.slice(0,1)||'?' }}</div>
        <div style="flex:1;min-width:0;">
          <div style="font-size:13px;font-weight:600;color:var(--t1);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{ c.peer_display }}</div>
          <div style="font-size:11px;color:var(--t4);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{ c.last_message }}</div>
        </div>
        <div class="unread-badge" v-if="c.unread_count">{{ c.unread_count }}</div>
      </div>
    </div>
    <div style="flex:1;display:flex;flex-direction:column;background:var(--bg0);" v-if="activeId">
      <div style="padding:12px 18px;background:#fff;border-bottom:1px solid var(--border);font-size:14px;font-weight:700;">{{ activeConv?.peer_display }}</div>
      <div style="flex:1;overflow-y:auto;padding:16px;display:flex;flex-direction:column;gap:10px;" ref="msgsEl">
        <div v-for="m in messages" :key="m.id" :class="['msg-row', m.sender_id===authStore.user?.id?'me':'other']">
          <div class="msg-bubble">{{ m.content }}</div>
          <div style="font-size:10px;color:var(--t4);">{{ m.created_at?.slice(11,16) }}</div>
        </div>
      </div>
      <div style="padding:10px 16px;background:#fff;border-top:1px solid var(--border);display:flex;gap:8px;">
        <input v-model="input" class="form-input" placeholder="输入消息…" @keyup.enter="send" />
        <button class="btn btn-primary" @click="send" :disabled="!input.trim()">发送</button>
      </div>
    </div>
    <div style="flex:1;display:flex;align-items:center;justify-content:center;color:var(--t4);" v-else>选择一个会话</div>
  </div>
</template>
<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { msgApi } from '@/api'
import { useAuthStore } from '@/stores/auth'
const authStore = useAuthStore()
const convs = ref([]); const messages = ref([]); const activeId = ref(null); const activeConv = ref(null)
const input = ref(''); const msgsEl = ref(null); let lastId = null; let pollTimer = null
async function loadConvs(){ const r = await msgApi.conversations(); if(r.code===0) convs.value = r.data.list||[] }
async function open(c){ activeId.value=c.id; activeConv.value=c; lastId=null; messages.value=[]; await loadMsgs(); startPoll() }
async function loadMsgs(){
  const p = lastId ? {after:lastId} : {page:1,per_page:50}
  const r = await msgApi.messages(activeId.value, p)
  if(r.code===0){ const list=r.data.list||[]; messages.value = lastId?[...messages.value,...list]:list; if(list.length) lastId=list[list.length-1].id }
  await nextTick(); if(msgsEl.value) msgsEl.value.scrollTop = msgsEl.value.scrollHeight
}
async function send(){ if(!input.value.trim()||!activeId.value) return; const t=input.value.trim(); input.value=''; await msgApi.send(activeId.value,{content:t}); await loadMsgs(); await loadConvs() }
function startPoll(){ clearInterval(pollTimer); pollTimer=setInterval(()=>{ if(activeId.value) loadMsgs() },3000) }
onMounted(loadConvs); onUnmounted(()=>clearInterval(pollTimer))
</script>
<style scoped>
.conv-item{display:flex;align-items:center;gap:10px;padding:11px 14px;cursor:pointer;border-bottom:1px solid var(--t6);transition:background .12s;}
.conv-item:hover{background:var(--bg0);}
.conv-item.active{background:var(--blue-xl);border-left:3px solid var(--blue);}
.conv-av{width:34px;height:34px;border-radius:9px;background:linear-gradient(135deg,var(--blue),#5e5ce6);color:#fff;font-size:14px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;}
.unread-badge{min-width:18px;height:18px;background:var(--red);color:#fff;border-radius:9px;font-size:10px;font-weight:700;display:flex;align-items:center;justify-content:center;padding:0 4px;flex-shrink:0;}
.msg-row{display:flex;flex-direction:column;max-width:60%;}
.msg-row.me{align-self:flex-end;align-items:flex-end;}
.msg-row.other{align-self:flex-start;align-items:flex-start;}
.msg-bubble{padding:9px 13px;border-radius:14px;font-size:13px;line-height:1.5;}
.msg-row.other .msg-bubble{background:#fff;color:var(--t2);border-radius:4px 14px 14px 14px;box-shadow:var(--sh-sm);}
.msg-row.me    .msg-bubble{background:var(--blue);color:#fff;border-radius:14px 4px 14px 14px;}
</style>
