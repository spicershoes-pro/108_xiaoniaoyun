<template>
  <div class="msg-layout">
    <!-- 左侧会话列表 -->
    <div class="conv-list">
      <div class="conv-header">
        <h2 style="font-size:16px;font-weight:700;">消息中心</h2>
      </div>
      <div v-if="!convs.length" class="empty-state" style="padding:30px 16px;">
        <div class="empty-icon" style="font-size:32px;">💬</div>
        <div class="empty-text">暂无会话</div>
      </div>
      <div v-for="c in convs" :key="c.id"
           :class="['conv-item', { active: activeConvId === c.id }]"
           @click="openConv(c)">
        <div class="conv-av">{{ c.peer_display?.slice(0,1)||'?' }}</div>
        <div class="conv-info">
          <div class="conv-name">{{ c.peer_display }}</div>
          <div class="conv-last">{{ c.last_message }}</div>
        </div>
        <div class="conv-meta">
          <div class="conv-time text-muted" style="font-size:11px;">{{ c.last_msg_at?.slice(11,16) }}</div>
          <div class="unread-badge" v-if="c.unread_count">{{ c.unread_count }}</div>
        </div>
      </div>
    </div>

    <!-- 右侧聊天区 -->
    <div class="chat-area" v-if="activeConvId">
      <div class="chat-header">
        <div class="chat-av">{{ activeConv?.peer_display?.slice(0,1) }}</div>
        <div>
          <div style="font-size:14px;font-weight:700;">{{ activeConv?.peer_display }}</div>
          <div class="text-muted" style="font-size:12px;">{{ peerRoleLabel(activeConv) }}</div>
        </div>
      </div>

      <div class="chat-msgs" ref="msgsEl">
        <div v-for="m in messages" :key="m.id"
             :class="['msg-row', m.sender_id===authStore.user?.id?'me':'other']">
          <div v-if="m.sender_id!==authStore.user?.id" class="msg-av">
            {{ activeConv?.peer_display?.slice(0,1) }}
          </div>
          <div class="msg-bubble">
            <div v-if="m.type==='product_card'" class="msg-product-card">
              📦 产品推荐
            </div>
            <template v-else>{{ m.content }}</template>
          </div>
          <div class="msg-time">{{ m.created_at?.slice(11,16) }}</div>
        </div>
      </div>

      <!-- 快捷回复 -->
      <div class="quick-replies">
        <button v-for="q in quickReplies" :key="q"
                class="quick-btn" @click="input=q">{{ q }}</button>
      </div>

      <div class="chat-input-wrap">
        <input v-model="input" class="chat-input"
               placeholder="输入消息，Enter发送…"
               @keyup.enter="sendMsg" />
        <button class="btn btn-primary" @click="sendMsg" :disabled="!input.trim()">发送</button>
      </div>
    </div>

    <div class="chat-empty" v-else>
      <div style="font-size:48px;margin-bottom:12px;">💬</div>
      <div class="text-muted">选择一个会话开始聊天</div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, onUnmounted, nextTick } from 'vue'
import { useRoute } from 'vue-router'
import { msgApi } from '@/api'
import { useAuthStore } from '@/stores/auth'

const route = useRoute()

const authStore    = useAuthStore()
const convs        = ref([])
const messages     = ref([])
const activeConvId = ref(null)
const activeConv   = ref(null)
const input        = ref('')
const msgsEl       = ref(null)
let pollTimer      = null
let lastMsgId      = null

const quickReplies = ['MOQ多少？','支持OEM吗？','有现货吗？','能发样品吗？','价格能优惠吗？','您好，请问…']

function peerRoleLabel(c) {
  const role = c?.peer_role || c?.peer?.role
  return role === 'merchant' ? '供应商' : role === 'buyer' ? '买家' : '联系人'
}

async function loadConvs() {
  const res = await msgApi.conversations()
  if (res.code === 0) convs.value = res.data.list || []
}

async function openConv(c) {
  activeConvId.value = c.id
  activeConv.value   = c
  lastMsgId = null
  messages.value = []
  await loadMessages()
  startPoll()
}

async function loadMessages() {
  const params = lastMsgId ? { after: lastMsgId } : { page: 1, per_page: 50 }
  const res = await msgApi.messages(activeConvId.value, params)
  if (res.code === 0) {
    const list = res.data.list || []
    if (lastMsgId) {
      messages.value = [...messages.value, ...list]
    } else {
      messages.value = list
    }
    if (list.length) lastMsgId = list[list.length - 1].id
    await nextTick()
    if (msgsEl.value) msgsEl.value.scrollTop = msgsEl.value.scrollHeight
  }
}

async function sendMsg() {
  if (!input.value.trim() || !activeConvId.value) return
  const text = input.value.trim()
  input.value = ''
  await msgApi.send(activeConvId.value, { content: text })
  await loadMessages()
  await loadConvs()
}

function startPoll() {
  clearInterval(pollTimer)
  pollTimer = setInterval(async () => {
    if (activeConvId.value) await loadMessages()
  }, 3000)
}

onMounted(async () => {
  await loadConvs()
  const qid = route.query.conv
  if (qid) {
    const c = convs.value.find(x => String(x.id) === String(qid))
    if (c) await openConv(c)
  }
})

onUnmounted(() => clearInterval(pollTimer))
</script>

<style scoped>
.msg-layout{display:flex;height:calc(100vh - 58px);overflow:hidden;}
.conv-list{width:280px;border-right:1px solid var(--border);background:#fff;display:flex;flex-direction:column;flex-shrink:0;}
.conv-header{padding:16px;border-bottom:1px solid var(--t6);flex-shrink:0;}
.conv-item{display:flex;align-items:center;gap:10px;padding:12px 16px;cursor:pointer;transition:background .12s;border-bottom:1px solid var(--t6);}
.conv-item:hover{background:var(--bg0);}
.conv-item.active{background:var(--blue-xl);border-left:3px solid var(--blue);}
.conv-av{width:38px;height:38px;border-radius:10px;background:linear-gradient(135deg,var(--blue),#5e5ce6);color:#fff;font-size:15px;font-weight:700;display:flex;align-items:center;justify-content:center;flex-shrink:0;}
.conv-info{flex:1;min-width:0;}
.conv-name{font-size:13px;font-weight:600;color:var(--t1);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.conv-last{font-size:12px;color:var(--t4);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}
.conv-meta{display:flex;flex-direction:column;align-items:flex-end;gap:4px;flex-shrink:0;}
.unread-badge{min-width:18px;height:18px;background:var(--red);color:#fff;border-radius:9px;font-size:10px;font-weight:700;display:flex;align-items:center;justify-content:center;padding:0 4px;}

.chat-area{flex:1;display:flex;flex-direction:column;background:var(--bg0);}
.chat-empty{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;color:var(--t4);}
.chat-header{display:flex;align-items:center;gap:10px;padding:12px 18px;background:#fff;border-bottom:1px solid var(--border);flex-shrink:0;}
.chat-av{width:36px;height:36px;border-radius:9px;background:var(--blue-xl);display:flex;align-items:center;justify-content:center;font-size:16px;font-weight:700;color:var(--blue);}

.chat-msgs{flex:1;overflow-y:auto;padding:16px 20px;display:flex;flex-direction:column;gap:12px;}
.msg-row{display:flex;align-items:flex-end;gap:8px;}
.msg-row.me{flex-direction:row-reverse;}
.msg-av{width:30px;height:30px;border-radius:8px;background:var(--t6);display:flex;align-items:center;justify-content:center;font-size:13px;font-weight:700;flex-shrink:0;}
.msg-bubble{max-width:60%;padding:10px 14px;border-radius:16px;font-size:13px;line-height:1.5;}
.msg-row.other .msg-bubble{background:#fff;color:var(--t2);border-radius:4px 16px 16px 16px;box-shadow:var(--sh-sm);}
.msg-row.me .msg-bubble{background:var(--blue);color:#fff;border-radius:16px 4px 16px 16px;}
.msg-time{font-size:10px;color:var(--t4);}
.msg-product-card{background:rgba(255,255,255,.2);border-radius:8px;padding:6px 10px;font-size:12px;}

.quick-replies{display:flex;gap:6px;padding:8px 16px;overflow-x:auto;flex-shrink:0;}
.quick-btn{padding:5px 12px;border:1.5px solid var(--border);border-radius:20px;font-size:12px;background:#fff;cursor:pointer;white-space:nowrap;transition:all .15s;flex-shrink:0;}
.quick-btn:hover{border-color:var(--blue);color:var(--blue);}

.chat-input-wrap{display:flex;gap:10px;padding:12px 16px;background:#fff;border-top:1px solid var(--border);flex-shrink:0;}
.chat-input{flex:1;padding:9px 14px;border:1.5px solid var(--border);border-radius:10px;font-size:13px;outline:none;transition:border-color .15s;}
.chat-input:focus{border-color:var(--blue);}
</style>
