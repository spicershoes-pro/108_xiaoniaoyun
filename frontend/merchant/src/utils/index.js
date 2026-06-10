/**
 * utils/index.js
 * 霄鸟云前端通用工具函数库
 * 对齐 XN-TECH-201-03 §7.4 数据展示规范
 */

// ── 金额格式化 ──────────────────────────────────────────────
/**
 * 格式化金额
 * @param {number|string} v 原始金额（元）
 * @param {string} symbol 货币符号，默认 ¥
 * @returns {string} 如 ¥89.00 / ¥1.2万 / ¥286万
 */
export function fmtMoney(v, symbol = '¥') {
  v = Number(v) || 0
  if (v >= 100_000_000) return symbol + (v / 100_000_000).toFixed(2) + '亿'
  if (v >= 10_000_000)  return symbol + (v / 10_000).toFixed(0) + '万'
  if (v >= 10_000)      return symbol + (v / 10_000).toFixed(1) + '万'
  return symbol + v.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
}

// ── 数量格式化 ──────────────────────────────────────────────
/**
 * 格式化数量
 * @param {number|string} n
 * @returns {string} 如 1,234 / 1.2w / 12万
 */
export function fmtNum(n) {
  n = Number(n) || 0
  if (n >= 100_000_000) return (n / 100_000_000).toFixed(1) + '亿'
  if (n >= 10_000)      return (n / 10_000).toFixed(1) + 'w'
  return n.toLocaleString('zh-CN')
}

// ── 时间格式化 ──────────────────────────────────────────────
/**
 * 格式化日期时间
 * @param {string|null} dateStr
 * @param {boolean} showTime 是否显示时分
 * @returns {string}
 */
export function fmtDate(dateStr, showTime = false) {
  if (!dateStr) return '—'
  const d = new Date(dateStr.replace(' ', 'T'))
  if (isNaN(d.getTime())) return dateStr
  const date = d.toLocaleDateString('zh-CN', { year: 'numeric', month: '2-digit', day: '2-digit' }).replace(/\//g, '-')
  if (!showTime) return date
  const time = d.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', hour12: false })
  return `${date} ${time}`
}

/**
 * 相对时间（如：3分钟前、2天前）
 * @param {string} dateStr
 * @returns {string}
 */
export function fmtRelativeTime(dateStr) {
  if (!dateStr) return ''
  const now  = Date.now()
  const then = new Date(dateStr.replace(' ', 'T')).getTime()
  const diff = Math.floor((now - then) / 1000) // 秒

  if (diff < 60)      return `${diff}秒前`
  if (diff < 3600)    return `${Math.floor(diff / 60)}分钟前`
  if (diff < 86400)   return `${Math.floor(diff / 3600)}小时前`
  if (diff < 2592000) return `${Math.floor(diff / 86400)}天前`
  if (diff < 31536000)return `${Math.floor(diff / 2592000)}个月前`
  return `${Math.floor(diff / 31536000)}年前`
}

// ── 订单状态机 ──────────────────────────────────────────────
/**
 * 订单状态 → 步骤数字
 * 对齐 XN-BIZ-201-02 §1.1 订单6步状态机
 */
const ORDER_STATUS_STEP = {
  pending_payment: 1,
  paid:            2,
  material:        3,
  production:      4,
  shipping:        5,
  delivered:       5,  // delivered 与 shipping 同步骤
  completed:       6,
  cancelled:       0,
  dispute:         0,
}

export function orderStatusToStep(status) {
  return ORDER_STATUS_STEP[status] ?? 0
}

/**
 * 订单状态 → 中文文案
 */
const ORDER_STATUS_LABEL = {
  pending_payment: '待付款',
  paid:            '已付款',
  material:        '备料中',
  production:      '生产中',
  shipping:        '运输中',
  delivered:       '已送达',
  completed:       '已完成',
  cancelled:       '已取消',
  dispute:         '纠纷中',
}

export function orderStatusLabel(status) {
  return ORDER_STATUS_LABEL[status] ?? status
}

/**
 * 订单状态 → badge 样式类
 */
const ORDER_STATUS_BADGE = {
  pending_payment: 'badge-warning',
  paid:            'badge-info',
  material:        'badge-info',
  production:      'badge-info',
  shipping:        'badge-info',
  delivered:       'badge-info',
  completed:       'badge-success',
  cancelled:       'badge-gray',
  dispute:         'badge-danger',
}

export function orderStatusBadge(status) {
  return ORDER_STATUS_BADGE[status] ?? 'badge-gray'
}

// ── 询盘状态 ─────────────────────────────────────────────────
const INQ_STATUS_LABEL = {
  pending:     '待回复',
  quoted:      '已报价',
  negotiating: '洽谈中',
  closed:      '已关闭',
  converted:   '已转化',
}

export function inquiryStatusLabel(status) {
  return INQ_STATUS_LABEL[status] ?? status
}

// ── 阶梯价计算 ───────────────────────────────────────────────
/**
 * 根据采购数量计算阶梯价
 * 对齐 XN-BIZ-201-02 §4.2
 * @param {number} qty 采购数量
 * @param {number} basePrice 基础价格
 * @param {Array}  priceTiers [{min_qty, price}]
 * @returns {number} 最终单价
 */
export function calcTierPrice(qty, basePrice, priceTiers = []) {
  if (!priceTiers || priceTiers.length === 0) return Number(basePrice)
  const sorted = [...priceTiers].sort((a, b) => b.min_qty - a.min_qty)
  for (const tier of sorted) {
    if (qty >= Number(tier.min_qty)) return Number(tier.price)
  }
  return Number(basePrice)
}

// ── 表单校验 ─────────────────────────────────────────────────
/**
 * 手机号校验（中国大陆11位）
 */
export function isPhone(val) {
  return /^1[3-9]\d{9}$/.test(String(val).trim())
}

/**
 * 邮箱校验
 */
export function isEmail(val) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(val).trim())
}

/**
 * 非空校验
 */
export function isRequired(val) {
  return String(val ?? '').trim().length > 0
}

/**
 * 长度区间校验
 */
export function isLength(val, min, max) {
  const len = String(val ?? '').trim().length
  return len >= min && len <= max
}

// ── 路由工具 ─────────────────────────────────────────────────
/**
 * 从URL解析查询参数
 */
export function parseQuery(search = window.location.search) {
  return Object.fromEntries(new URLSearchParams(search).entries())
}

// ── 文件工具 ─────────────────────────────────────────────────
/**
 * 文件大小格式化
 */
export function fmtFileSize(bytes) {
  if (bytes < 1024) return `${bytes}B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)}KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)}MB`
}

// ── 防抖 ──────────────────────────────────────────────────────
/**
 * 防抖函数
 */
export function debounce(fn, delay = 300) {
  let timer
  return function (...args) {
    clearTimeout(timer)
    timer = setTimeout(() => fn.apply(this, args), delay)
  }
}

// ── 复制到剪贴板 ───────────────────────────────────────────────
export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text)
    return true
  } catch {
    // 兼容旧浏览器
    const el = document.createElement('textarea')
    el.value = text
    document.body.appendChild(el)
    el.select()
    document.execCommand('copy')
    document.body.removeChild(el)
    return true
  }
}

// ── 颜色工具 ──────────────────────────────────────────────────
/**
 * 角色 → 显示颜色
 */
export function roleColor(role) {
  const map = { buyer: '#1677FF', merchant: '#52C41A', admin: '#722ED1', super_admin: '#FF4D4F' }
  return map[role] ?? '#9CA3AF'
}

/**
 * 等级 → 文案和颜色
 */
export function levelInfo(level) {
  const map = {
    bronze:   { label: '铜牌', color: '#CD7F32', bg: '#FFF2E8' },
    silver:   { label: '银牌', color: '#8C8C8C', bg: '#F5F5F5' },
    gold:     { label: '🥇 黄金', color: '#D48806', bg: '#FFFBE6' },
    platinum: { label: '💎 白金', color: '#722ED1', bg: '#F9F0FF' },
  }
  return map[level] ?? { label: level, color: '#9CA3AF', bg: '#F3F4F6' }
}
