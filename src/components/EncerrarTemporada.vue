<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import Celebracao from './Celebracao.vue'

const props = defineProps<{ temporadaId: string; temporadaNome: string }>()
const emit = defineEmits<{ (e: 'temporadaEncerrada'): void }>()

const resultados = ref('')
const desafios = ref('')
const aprendizados = ref('')
const proxima = ref('')
const comprometimento = ref<number | null>(null)
const satisfacao = ref<number | null>(null)
const carregando = ref(false)
const sucesso = ref(false)
const celebrando = ref(false)
const erro = ref('')

async function encerrar() {
  if (carregando.value || sucesso.value) return
  erro.value = ''
  if (!comprometimento.value || !satisfacao.value) {
    erro.value = 'Avalie comprometimento e satisfação de 1 a 5.'
    return
  }
  if (!window.confirm(`Encerrar a temporada "${props.temporadaNome}"? As atividades serão preservadas.`)) return
  carregando.value = true
  try {
    const { data: auth, error: erroAuth } = await supabase.auth.getUser()
    if (erroAuth || !auth.user) throw new Error('Sua sessão expirou. Entre novamente.')
    const { data, error } = await supabase
      .from('temporadas')
      .update({
        status: 'encerrada',
        resultados_obtidos: resultados.value.trim(),
        desafios: desafios.value.trim(),
        aprendizados: aprendizados.value.trim(),
        proxima_temporada: proxima.value.trim(),
        comprometimento: comprometimento.value,
        satisfacao: satisfacao.value,
        encerrada_em: new Date().toISOString()
      })
      .eq('id', props.temporadaId)
      .eq('usuario_id', auth.user.id)
      .eq('status', 'ativa')
      .select('id')
      .single()
    if (error) throw error
    if (!data) throw new Error('A temporada não está mais ativa.')
    sucesso.value = true
    celebrando.value = true
  } catch (e) {
    console.error('Erro ao encerrar temporada:', e)
    erro.value = e instanceof Error ? e.message : 'Não foi possível encerrar a temporada.'
  } finally {
    carregando.value = false
  }
}

function terminarAnimacao() {
  celebrando.value = false
  emit('temporadaEncerrada')
}
</script>

<template>
  <section class="painel-encerramento">
    <div class="cabecalho">
      <span class="etiqueta">REFLEXÃO DE FIM DE CICLO</span>
      <h2>Encerrar temporada</h2>
      <p>Temporada: <strong>{{ temporadaNome }}</strong></p>
      <p>Registre seu aprendizado. Suas semanas e atividades não serão apagadas.</p>
    </div>

    <form @submit.prevent="encerrar">
      <label for="resultados">Resultados obtidos</label>
      <textarea id="resultados" v-model="resultados" rows="3" placeholder="O que você realizou?" />

      <label for="desafios">Desafios e dificuldades</label>
      <textarea id="desafios" v-model="desafios" rows="3" placeholder="O que atrapalhou sua execução?" />

      <label for="aprendizados">Principais aprendizados</label>
      <textarea id="aprendizados" v-model="aprendizados" rows="3" placeholder="O que você aprendeu sobre sua rotina?" />

      <label for="proxima">O que levar para a próxima temporada?</label>
      <textarea id="proxima" v-model="proxima" rows="3" placeholder="O que manter, ajustar ou abandonar?" />

      <div class="notas">
        <div>
          <label for="comprometimento">Comprometimento (1 a 5)</label>
          <select id="comprometimento" v-model.number="comprometimento" required>
            <option :value="null" disabled>Selecione</option>
            <option v-for="n in 5" :key="n" :value="n">{{ n }}</option>
          </select>
        </div>
        <div>
          <label for="satisfacao">Satisfação (1 a 5)</label>
          <select id="satisfacao" v-model.number="satisfacao" required>
            <option :value="null" disabled>Selecione</option>
            <option v-for="n in 5" :key="n" :value="n">{{ n }}</option>
          </select>
        </div>
      </div>

      <p v-if="erro" class="erro" role="alert">{{ erro }}</p>
      <p v-if="sucesso" class="sucesso">Temporada encerrada com sucesso!</p>
      <button type="submit" :disabled="carregando || sucesso">
        {{ carregando ? 'Salvando encerramento...' : sucesso ? 'Temporada encerrada' : 'Concluir e encerrar temporada' }}
      </button>
    </form>

    <Celebracao v-if="celebrando" tipo="temporada" @terminou="terminarAnimacao" />
  </section>
</template>

<style scoped>
.painel-encerramento { width:100%; max-width:650px; margin:20px auto; padding:30px; box-sizing:border-box; background:#fff; border:1px solid #e3eaf5; border-radius:18px; box-shadow:0 8px 28px rgba(25,50,90,.05); color:#172b4d; }
.cabecalho { margin-bottom:22px; }
.etiqueta { color:#2563eb; font-size:11px; font-weight:700; letter-spacing:1px; }
h2 { margin:8px 0; font-size:26px; }
p { color:#64748b; font-size:14px; line-height:1.5; }
form { display:flex; flex-direction:column; gap:12px; }
label { display:block; margin-top:8px; font-size:13px; font-weight:600; color:#334155; }
textarea, select { width:100%; box-sizing:border-box; padding:12px 14px; border:1px solid #dce4ef; border-radius:9px; background:white; color:#172b4d; font:inherit; font-size:14px; }
textarea { resize:vertical; }
textarea:focus, select:focus { outline:none; border-color:#2563eb; }
.notas { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
.notas label { margin-bottom:10px; }
button { margin-top:12px; padding:13px 20px; background:#2563eb; color:white; border:0; border-radius:9px; font-weight:700; cursor:pointer; }
button:disabled { opacity:.65; cursor:not-allowed; }
.erro { color:#b91c1c; }
.sucesso { color:#15803d; }
@media(max-width:500px) { .painel-encerramento { padding:20px; } .notas { grid-template-columns:1fr; } }
</style>
