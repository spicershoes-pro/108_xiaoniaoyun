<template>
  <div class="toast-zone" id="toast-zone">
    <transition-group name="toast-anim">
      <div
        v-for="t in toasts"
        :key="t.id"
        :class="['toast', `toast-${t.type}`]"
      >
        {{ t.msg }}
      </div>
    </transition-group>
  </div>
</template>

<script setup>
import { ref, provide } from 'vue'

const toasts = ref([])
let uid = 0

function toast(msg, type = 'success', duration = 2500) {
  const id = ++uid
  toasts.value.push({ id, msg, type })
  setTimeout(() => {
    toasts.value = toasts.value.filter(t => t.id !== id)
  }, duration)
}

provide('toast', toast)
</script>

<style scoped>
.toast-zone {
  position: fixed; top: 68px; left: 50%; transform: translateX(-50%);
  z-index: 9000; display: flex; flex-direction: column; gap: 7px;
  pointer-events: none;
}
.toast {
  padding: 10px 20px; border-radius: 24px; font-size: 13px;
  font-weight: 600; color: #fff; pointer-events: auto;
  box-shadow: 0 4px 16px rgba(0,0,0,.15);
  white-space: nowrap;
}
.toast-success { background: rgba(8,22,10,.88); }
.toast-error   { background: rgba(150,18,18,.9); }
.toast-warning { background: rgba(140,70,0,.9); }
.toast-info    { background: rgba(22,119,255,.9); }

.toast-anim-enter-active { animation: toastIn .2s cubic-bezier(.34,1.56,.64,1); }
.toast-anim-leave-active { animation: toastOut .2s ease; }
@keyframes toastIn  { from { opacity:0; transform:translateY(-8px) scale(.94) } to { opacity:1; } }
@keyframes toastOut { to   { opacity:0; transform:translateY(-6px) scale(.96) } }
</style>
