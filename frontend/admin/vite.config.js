import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig(({ mode }) => {
  // 加载对应环境的 .env 文件
  const env = loadEnv(mode, process.cwd(), 'VITE_')

  const isProd    = mode === 'production'
  const isStaging = mode === 'staging'
  const isDev     = mode === 'development' || mode === 'testing'
  const apiPort   = process.env.XNY_API_PORT || '18080'

  const basePath = env.VITE_BASE_PATH || '/'

  return {
    base: basePath,
    plugins: [vue()],

    resolve: {
      alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) }
    },

    // 开发服务器（本地开发用）
    server: {
      port: 5175,
      host: '0.0.0.0',
      proxy: {
        '/api': {
          target: `http://localhost:${apiPort}`,
          changeOrigin: true,
          // 开发时打印代理日志
          configure: (proxy) => {
            if (isDev) {
              proxy.on('error', (err) => console.error('[proxy error]', err))
            }
          }
        }
      }
    },

    // 构建配置
    build: {
      outDir: 'dist',
      sourcemap: isProd ? false : 'inline',  // 生产不生成 sourcemap
      minify: isProd ? 'esbuild' : false,
      target: 'es2015',
      rollupOptions: {
        output: {
          // 分割策略：vendor 单独打包
          manualChunks: {
            vendor: ['vue', 'vue-router', 'pinia', 'axios'],
          },
          // 加入内容哈希，利于 CDN 缓存
          chunkFileNames:  'assets/[name]-[hash].js',
          entryFileNames:  'assets/[name]-[hash].js',
          assetFileNames:  'assets/[name]-[hash].[ext]',
        }
      },
      // 关闭构建警告（生产静默）
      reportCompressedSize: !isProd,
    },

    // 全局常量注入（在代码中可用 import.meta.env.VITE_xxx）
    define: {
      'import.meta.env.VITE_BUILD_TIME': JSON.stringify(new Date().toISOString()),
    },
  }
})
