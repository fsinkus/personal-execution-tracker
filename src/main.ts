
import {
  createApp,
  defineComponent,
  h,
  onUnmounted,
  ref
} from 'vue'

import './assets/main.css'
import App from './App.vue'
import Login from './components/Login.vue'
import { supabase } from './lib/supabase'

const Root = defineComponent({
  setup() {
    const carregando = ref(true)
    const autenticado = ref(false)

    // Acompanha login e logout
    const { data: { subscription } } =
      supabase.auth.onAuthStateChange((_evento, sessao) => {
        autenticado.value = !!sessao
        carregando.value = false
      })

    // Verifica a sessão ao abrir o aplicativo
    async function inicializar() {
      carregando.value = true

      const { data, error } = await supabase.auth.getSession()

      if (error) {
        console.error(
          'Erro ao verificar sessão:',
          error.message
        )
      }

      autenticado.value = !!data.session
      carregando.value = false
    }

    void inicializar()

    // Encerra o acompanhamento ao desmontar
    onUnmounted(() => {
      subscription.unsubscribe()
    })

    // Define qual tela mostrar
    return () => {
      if (carregando.value) {
        return h(
          'div',
          { style: 'padding: 32px' },
          'Carregando...'
        )
      }

      if (!autenticado.value) {
        return h(Login)
      }

      // Sempre mostra o quadro após o login
      return h(App)
    }
  }
})

createApp(Root).mount('#app')
