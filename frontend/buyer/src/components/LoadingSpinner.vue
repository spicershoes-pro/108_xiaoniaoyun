<template>
  <div class="loading-wrap">
    <div class="spinner"></div>
    <div v-if="text" class="loading-text">{{ text }}</div>
  </div>
</template>

<script setup>
defineProps({ text: { type: String, default: '' } })
</script>

<style scoped>
.loading-wrap { display:flex; flex-direction:column; align-items:center; gap:10px; padding:40px; }
.spinner { width:32px; height:32px; border:3px solid var(--t6); border-top-color:var(--blue); border-radius:50%; animation:spin .6s linear infinite; }
@keyframes spin { to { transform:rotate(360deg) } }
.loading-text { font-size:13px; color:var(--t4); }
</style>
