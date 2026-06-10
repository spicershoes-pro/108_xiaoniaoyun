// src/stores/cart.js
import { defineStore } from 'pinia'
import { cartApi } from '@/api'

export const useCartStore = defineStore('cart', {
  state: () => ({
    items:   [],
    total:   0,
    loading: false,
  }),

  getters: {
    count: s => s.items.length,
    selectedTotal: s => s.items
      .filter(i => i._selected)
      .reduce((sum, i) => sum + i.subtotal, 0),
  },

  actions: {
    async fetch() {
      this.loading = true
      try {
        const res = await cartApi.list()
        if (res.code === 0) {
          this.items = (res.data.items || []).map(i => ({ ...i, _selected: true }))
          this.total = res.data.total || 0
        }
      } finally {
        this.loading = false
      }
    },

    async upsert(productId, qty) {
      const res = await cartApi.upsert({ product_id: productId, qty })
      if (res.code === 0) await this.fetch()
      return res
    },

    async remove(productId) {
      await cartApi.remove(productId)
      await this.fetch()
    },

    async clear() {
      await cartApi.clear()
      this.items = []
      this.total = 0
    },

    toggleSelect(productId) {
      const item = this.items.find(i => i.product_id === productId)
      if (item) item._selected = !item._selected
    },

    toggleAll(val) {
      this.items.forEach(i => i._selected = val)
    },
  },
})
