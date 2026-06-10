<template>
  <div class="empty-state">
    <div class="empty-icon">{{ icon }}</div>
    <div class="empty-title">{{ title }}</div>
    <div v-if="desc" class="empty-desc">{{ desc }}</div>
    <slot />
  </div>
</template>

<script setup>
defineProps({
  icon:  { type: String, default: '📭' },
  title: { type: String, required: true },
  desc:  { type: String, default: '' },
})
</script>

<style scoped>
.empty-state {
  display: flex; flex-direction: column; align-items: center;
  justify-content: center; gap: 12px; padding: 64px 20px;
  color: var(--t4); text-align: center;
}
.empty-icon  { font-size: 48px; opacity: .32; }
.empty-title { font-size: 14px; font-weight: 600; color: var(--t3); }
.empty-desc  { font-size: 12px; max-width: 280px; line-height: 1.7; }
</style>
