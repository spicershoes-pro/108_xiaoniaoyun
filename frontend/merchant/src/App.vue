<template>
  <router-view />
  <div class="toast-wrapper">
    <transition-group name="toast-fade">
      <div v-for="t in toasts" :key="t.id" :class="['toast', `toast-${t.type}`]">
        {{ t.msg }}
      </div>
    </transition-group>
  </div>
</template>

<script setup>
import { ref, provide, onMounted } from 'vue'
import { useAuthStore } from '@/stores/auth'

const auth   = useAuthStore()
const toasts = ref([])

function showToast(msg, type = 'success', duration = 2500) {
  const id = Date.now()
  toasts.value.push({ id, msg, type })
  setTimeout(() => { toasts.value = toasts.value.filter(t => t.id !== id) }, duration)
}
provide('toast', showToast)

onMounted(() => { if (auth.token) auth.fetchMe() })
</script>

<style>
@import './assets/main.css';
.toast-fade-enter-active, .toast-fade-leave-active { transition: all .2s ease; }
.toast-fade-enter-from, .toast-fade-leave-to { opacity: 0; transform: translateY(-10px); }
</style>
