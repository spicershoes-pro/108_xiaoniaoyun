<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">系统设置</h1></div>

    <div class="tab-row">
      <button v-for="t in tabs" :key="t.k"
              :class="['tab-btn', curTab===t.k?'active':'']"
              @click="curTab=t.k; loadTab()">{{ t.l }}</button>
    </div>

    <!-- 管理员账号 -->
    <div v-if="curTab==='admins'">
      <div class="card">
        <div style="display:flex;justify-content:space-between;align-items:center;padding:12px 16px;border-bottom:1px solid var(--t6);">
          <span style="font-size:13px;color:var(--t3);">共 {{ admins.length }} 位管理员</span>
          <button class="btn btn-primary btn-sm" @click="toast('功能开发中')">+ 添加管理员</button>
        </div>
        <div class="table-wrap">
          <table class="table">
            <thead><tr><th>管理员</th><th>角色</th><th>邮箱</th><th>权限范围</th><th>状态</th><th>操作</th></tr></thead>
            <tbody>
              <tr v-for="a in admins" :key="a.id">
                <td>
                  <div style="display:flex;gap:8px;align-items:center;">
                    <div class="admin-av">{{ a.name?.slice(0,1) }}</div>
                    <span style="font-weight:600;font-size:13px;">{{ a.name }}</span>
                  </div>
                </td>
                <td>
                  <span :class="['tag', a.role==='super_admin'?'tag-red':a.role==='admin'?'tag-blue':'tag-gray']">
                    {{ {super_admin:'超级管理员',admin:'管理员'}[a.role]||a.role }}
                  </span>
                </td>
                <td style="font-size:12px;color:var(--t3);">{{ a.email || '—' }}</td>
                <td style="font-size:12px;color:var(--t3);">全部权限</td>
                <td><span class="badge badge-active">正常</span></td>
                <td>
                  <div style="display:flex;gap:5px;">
                    <button class="btn btn-sm btn-ghost">编辑</button>
                    <button v-if="a.role!=='super_admin'" class="btn btn-sm btn-danger" @click="toast('已移除管理员','warning')">移除</button>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <!-- 全局配置 -->
    <div v-if="curTab==='config'">
      <div class="config-grid">
        <div v-for="g in configGroups" :key="g.title" class="card config-group">
          <div class="card-header"><span class="card-title">{{ g.title }}</span></div>
          <div class="card-body">
            <div v-for="item in g.items" :key="item.key" class="config-row">
              <div class="cfg-info">
                <div class="cfg-label">{{ item.label }}</div>
                <div class="cfg-desc">{{ item.desc }}</div>
              </div>
              <div class="cfg-right">
                <span class="cfg-val">{{ configMap[item.key] || item.default }}</span>
                <button class="btn btn-sm btn-ghost" @click="editConfig(item)">修改</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 操作日志 -->
    <div v-if="curTab==='logs'">
      <div class="card">
        <div class="table-wrap">
          <table class="table">
            <thead><tr><th>操作人</th><th>操作类型</th><th>操作对象</th><th>时间</th><th>IP</th></tr></thead>
            <tbody>
              <tr v-for="l in logs" :key="l.id">
                <td>
                  <div style="display:flex;gap:6px;align-items:center;">
                    <div class="admin-av" style="width:22px;height:22px;font-size:10px;">{{ l.admin_name?.slice(0,1) }}</div>
                    <span style="font-size:13px;font-weight:600;">{{ l.admin_name }}</span>
                  </div>
                </td>
                <td>
                  <span :class="['tag', l.action?.includes('封禁')||l.action?.includes('拒绝')||l.action?.includes('删除')?'tag-red':l.action?.includes('通过')||l.action?.includes('批准')?'tag-green':'tag-blue']">
                    {{ l.action }}
                  </span>
                </td>
                <td style="font-size:12px;color:var(--t3);max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">{{ l.target || '—' }}</td>
                <td style="font-size:12px;color:var(--t4);">{{ l.created_at?.slice(0,16).replace('T',' ') }}</td>
                <td style="font-family:monospace;font-size:11px;color:var(--t4);">{{ l.ip || '—' }}</td>
              </tr>
              <tr v-if="!logs.length">
                <td colspan="5"><div class="empty-state"><div class="empty-icon">📋</div><div class="empty-text">暂无操作日志</div></div></td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="pagination" v-if="totalPages>1">
          <button class="btn btn-ghost btn-sm" :disabled="page===1" @click="page--;loadTab()">上一页</button>
          <span class="page-info">{{ page }} / {{ totalPages }}</span>
          <button class="btn btn-ghost btn-sm" :disabled="page===totalPages" @click="page++;loadTab()">下一页</button>
        </div>
      </div>
    </div>

    <!-- 配置修改弹窗 -->
    <div class="modal-ov" v-if="editTarget" @click.self="editTarget=null">
      <div class="modal-box">
        <div class="modal-hd">
          <span class="modal-title">修改配置：{{ editTarget.label }}</span>
          <button class="modal-close" @click="editTarget=null">✕</button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label class="form-label">{{ editTarget.label }}</label>
            <input v-model="editVal" class="form-input" />
            <div style="font-size:12px;color:var(--t4);margin-top:6px;">{{ editTarget.desc }}</div>
          </div>
        </div>
        <div class="modal-ft">
          <button class="btn btn-ghost" @click="editTarget=null">取消</button>
          <button class="btn btn-primary" @click="saveConfig">保存</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, inject, onMounted } from 'vue'
import { adminApi } from '@/api'

const toast = inject('toast', () => {})

const curTab     = ref('admins')
const admins     = ref([])
const logs       = ref([])
const configMap  = ref({})
const editTarget = ref(null)
const editVal    = ref('')
const page       = ref(1)
const totalPages = ref(1)

const tabs = [
  { k:'admins', l:'管理员账号' },
  { k:'config', l:'全局配置' },
  { k:'logs',   l:'操作日志' },
]

const configGroups = [
  {
    title: '平台基础配置',
    items: [
      { key:'platform_name',   label:'平台名称',     desc:'显示在各页面标题',      default:'霄鸟云' },
      { key:'platform_fee_rate',label:'平台佣金率',  desc:'订单金额的抽成比例',    default:'0.05 (5%)' },
      { key:'min_withdrawal',  label:'最低提现金额', desc:'商家最低可提现额度(元)', default:'1000' },
    ]
  },
  {
    title: '业务规则配置',
    items: [
      { key:'inquiry_expire_days',          label:'询盘有效期',     desc:'单位：天',          default:'30' },
      { key:'sms_code_expire_minutes',      label:'验证码有效期',   desc:'单位：分钟',        default:'5' },
      { key:'sms_provider',                 label:'短信服务商',     desc:'mock/aliyun/tencent', default:'mock' },
    ]
  },
]

async function loadTab() {
  if (curTab.value === 'admins') {
    const res = await adminApi.config()
    // 用config接口同时加载管理员列表（实际可拆成独立接口）
    if (res.code === 0) configMap.value = res.data?.map || {}
    // mock管理员数据
    admins.value = [
      { id:'a1', name:'张超',   role:'super_admin', email:'admin@xiaoniao.com' },
      { id:'a2', name:'李运营', role:'admin',       email:'ops@xiaoniao.com' },
    ]
  } else if (curTab.value === 'config') {
    const res = await adminApi.config()
    if (res.code === 0) configMap.value = res.data?.map || {}
  } else if (curTab.value === 'logs') {
    const res = await adminApi.logs({ page: page.value })
    if (res.code === 0) {
      logs.value       = res.data || []
      totalPages.value = res.total_pages || 1
    }
  }
}

function editConfig(item) {
  editTarget.value = item
  editVal.value = configMap.value[item.key] || item.default
}

async function saveConfig() {
  const res = await adminApi.updateConfig({ key: editTarget.value.key, value: editVal.value })
  if (res.code === 0) {
    configMap.value[editTarget.value.key] = editVal.value
    toast('配置已更新')
    editTarget.value = null
  } else {
    toast(res.msg || '保存失败', 'error')
  }
}

onMounted(loadTab)
</script>

<style scoped>
.page-pad { padding: 22px 24px; }

.tab-row { display: flex; border-bottom: 1px solid var(--border); margin-bottom: 16px; background: #fff; border-radius: 10px 10px 0 0; padding: 0 16px; }
.tab-btn { padding: 11px 16px; border: none; background: none; font-size: 13px; font-weight: 500; color: var(--t4); cursor: pointer; border-bottom: 2px solid transparent; margin-bottom: -1px; transition: all .15s; }
.tab-btn.active { color: var(--blue); border-bottom-color: var(--blue); font-weight: 700; }

.admin-av { width: 28px; height: 28px; border-radius: 7px; background: linear-gradient(135deg,var(--blue),#5e5ce6); color: #fff; font-size: 12px; font-weight: 700; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }

.config-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.config-row  { display: flex; justify-content: space-between; align-items: center; padding: 12px 0; border-bottom: 1px solid var(--t6); }
.config-row:last-child { border: none; }
.cfg-info { flex: 1; }
.cfg-label { font-size: 13px; font-weight: 600; color: var(--t1); }
.cfg-desc  { font-size: 11px; color: var(--t4); margin-top: 2px; }
.cfg-right { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }
.cfg-val   { font-size: 13px; font-weight: 700; color: var(--blue); font-family: monospace; }

.pagination { display: flex; align-items: center; justify-content: center; gap: 12px; padding: 14px; }
.page-info  { font-size: 13px; color: var(--t3); }

.modal-ov  { position: fixed; inset: 0; background: rgba(0,0,0,.45); z-index: 1000; display: flex; align-items: center; justify-content: center; }
.modal-box { background: #fff; border-radius: 16px; width: 420px; display: flex; flex-direction: column; box-shadow: 0 20px 60px rgba(0,0,0,.2); overflow: hidden; }
.modal-hd  { display: flex; align-items: center; justify-content: space-between; padding: 18px 24px; border-bottom: 1px solid var(--border); }
.modal-title { font-size: 15px; font-weight: 700; }
.modal-close { background: var(--t6); border: none; width: 28px; height: 28px; border-radius: 6px; cursor: pointer; }
.modal-body  { padding: 18px 24px; }
.modal-ft    { padding: 14px 24px; border-top: 1px solid var(--border); display: flex; justify-content: flex-end; gap: 8px; }
</style>
