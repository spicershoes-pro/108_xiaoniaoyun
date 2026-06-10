import { msgApi } from '@/api'
import router from '@/router'

/** 打开或创建与指定用户的会话 */
export async function openChat(targetUserId, toast) {
  const uid = Number(targetUserId)
  if (!uid) {
    toast?.('无法打开会话', 'error')
    return false
  }
  const res = await msgApi.createConv(uid)
  if (res.code !== 0) {
    toast?.(res.msg || '打开会话失败', 'error')
    return false
  }
  const cid = res.data?.conversation_id
  await router.push(cid ? { path: '/messages', query: { conv: String(cid) } } : '/messages')
  return true
}
