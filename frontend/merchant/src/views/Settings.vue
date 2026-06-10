<template>
  <div class="page-pad">
    <div class="page-header"><h1 class="page-title">账号设置</h1></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;">
      <!-- 基本信息 -->
      <div class="card card-body">
        <div class="card-title" style="margin-bottom:16px;">工厂基本信息</div>
        <div class="form-group"><label class="form-label">工厂简称</label><input v-model="form.short_name" class="form-input" /></div>
        <div class="form-group"><label class="form-label">工厂描述</label><textarea v-model="form.description" class="form-input" rows="3"/></div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;">
          <div class="form-group"><label class="form-label">所在省份</label><input v-model="form.province" class="form-input" /></div>
          <div class="form-group"><label class="form-label">所在城市</label><input v-model="form.city" class="form-input" /></div>
        </div>
        <div class="form-group"><label class="form-label">员工规模</label>
          <select v-model="form.staff_range" class="form-input form-select">
            <option v-for="s in staffRanges" :key="s">{{s}}</option>
          </select>
        </div>
        <div class="form-group"><label class="form-label">平均响应时间</label><input v-model="form.response_time" class="form-input" placeholder="例：平均2小时"/></div>
        <button class="btn btn-primary" :disabled="saving" @click="save">{{saving?'保存中…':'保存信息'}}</button>
      </div>

      <!-- 经营品类 -->
      <div>
        <div class="card card-body" style="margin-bottom:14px;">
          <div class="card-title" style="margin-bottom:14px;">主营品类</div>
          <div style="display:flex;flex-wrap:wrap;gap:8px;">
            <label v-for="c in allCats" :key="c" style="display:flex;align-items:center;gap:5px;cursor:pointer;font-size:13px;">
              <input type="checkbox" :value="c" v-model="form.categories" />
              <span>{{c}}</span>
            </label>
          </div>
          <button class="btn btn-outline btn-sm" style="margin-top:12px;" @click="saveCats">保存品类</button>
        </div>

        <!-- 收款信息 -->
        <div class="card card-body">
          <div class="card-title" style="margin-bottom:14px;">收款信息</div>
          <div class="form-group"><label class="form-label">开户银行</label><input v-model="form.bank_name" class="form-input" placeholder="例：中国工商银行"/></div>
          <div class="form-group"><label class="form-label">银行账号</label><input v-model="form.bank_account" class="form-input" placeholder=""/></div>
          <div class="form-group"><label class="form-label">账户名称</label><input v-model="form.bank_holder" class="form-input" placeholder=""/></div>
          <button class="btn btn-outline" @click="saveBank">保存收款信息</button>
        </div>
      </div>
    </div>
  </div>
</template>
<script setup>
import { ref, reactive, inject, onMounted } from 'vue'
import { profileApi } from '@/api'
const toast=inject('toast',()=>{})
const saving=ref(false)
const form=reactive({short_name:'',description:'',province:'',city:'',staff_range:'',response_time:'',categories:[],bank_name:'',bank_account:'',bank_holder:''})
const staffRanges=['1-50人','50-100人','100-200人','200-500人','500-1000人','1000人以上']
const allCats=['遥控玩具','益智玩具','户外玩具','毛绒玩具','科技玩具','传统玩具','电子玩具','模型玩具']
async function save(){saving.value=true;const r=await profileApi.update({short_name:form.short_name,description:form.description,province:form.province,city:form.city,staff_range:form.staff_range,response_time:form.response_time});saving.value=false;toast(r.code===0?'保存成功 ✅':(r.msg||'保存失败'),r.code===0?'success':'error')}
async function saveCats(){const r=await profileApi.update({categories:form.categories});toast(r.code===0?'品类已更新':(r.msg||'失败'),r.code===0?'success':'error')}
async function saveBank(){const r=await profileApi.update({bank_name:form.bank_name,bank_account:form.bank_account,bank_holder:form.bank_holder});toast(r.code===0?'收款信息已保存':(r.msg||'失败'),r.code===0?'success':'error')}
onMounted(async()=>{ const r=await profileApi.get(); if(r.code===0){const d=r.data||{};form.short_name=d.short_name||'';form.description=d.description||'';form.province=d.province||'';form.city=d.city||'';form.staff_range=d.staff_range||'';form.response_time=d.response_time||'';form.categories=(d.categories||[]).map(c=>c.category||c);form.bank_name=d.bank_name||'';form.bank_account=d.bank_account||'';form.bank_holder=d.bank_holder||''} })
</script>
<style scoped>.page-pad{padding:22px 24px;}</style>