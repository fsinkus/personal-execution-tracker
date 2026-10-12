<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '../lib/supabase'
import Celebracao from './Celebracao.vue'

const emit = defineEmits<{ (e: 'temporadaCriada'): void }>()
const nome = ref('')
const objetivoPrincipal = ref('')
const marcos = ref<string[]>([''])
const atividadesPlanejadas = ref('')
const prioridade = ref('')
const criteriosSucesso = ref('')

function adicionarMarco() { marcos.value.push('') }
function removerMarco(indice: number) { marcos.value.splice(indice, 1) }

function dataHojeLocal(): string {
  const hoje = new Date()
  return `${hoje.getFullYear()}-${String(hoje.getMonth() + 1).padStart(2, '0')}-${String(hoje.getDate()).padStart(2, '0')}`
}

const dataInicio = ref(dataHojeLocal())
const carregando = ref(false)
const mensagem = ref('')
const sucesso = ref(false)
const mostrarCelebracao = ref(false)

function finalizarCelebracao() {
  mostrarCelebracao.value = false
  emit('temporadaCriada')
}

async function iniciarTemporada() {
  if (carregando.value || sucesso.value) return
  mensagem.value = ''
  if (!nome.value.trim()) { mensagem.value = 'Informe o nome da temporada.'; return }
  if (!dataInicio.value) { mensagem.value = 'Informe a data de início.'; return }
  if (!objetivoPrincipal.value.trim()) { mensagem.value = 'Informe o objetivo principal.'; return }
  const marcosValidos = marcos.value.map(m => m.trim()).filter(Boolean)
  carregando.value = true
  try {
    const { data: usuario, error: erroUsuario } = await supabase.auth.getUser()
    if (erroUsuario || !usuario.user) throw new Error('Sua sessão expirou. Entre novamente.')

    // Mantemos a RPC existente: ela cria a temporada e suas oito semanas.
    // O campo antigo 'objetivos' recebe também o objetivo principal, por compatibilidade.
    const { data: idCriado, error } = await supabase.rpc('criar_temporada', {
      p_nome: nome.value.trim(),
      p_data_inicio: dataInicio.value,
      p_objetivos: objetivoPrincipal.value.trim(),
      p_atividades_planejadas: atividadesPlanejadas.value.trim(),
      p_prioridade: prioridade.value.trim(),
      p_criterios_sucesso: criteriosSucesso.value.trim()
    })
    if (error) throw error

    // A RPC atual retorna o UUID da temporada criada.
    // Se o salvamento complementar falhar, não tentamos criar outra temporada.
    const id = typeof idCriado === 'string' ? idCriado : null
    if (!id) throw new Error('A temporada foi criada, mas não foi possível identificar seu ID. Atualize a página antes de tentar novamente.')

    const { error: erroObjetivos } = await supabase.from('temporadas').update({
      objetivo_principal: objetivoPrincipal.value.trim(),
      marcos_temporada: marcosValidos
    }).eq('id', id).eq('usuario_id', usuario.user.id).select('id').single()
    if (erroObjetivos) throw new Error('A temporada foi criada, mas não foi possível salvar os marcos: ' + erroObjetivos.message + '. Não tente criar outra; os marcos podem ser recuperados depois.')

    sucesso.value = true
    mensagem.value = 'Temporada criada com sucesso!'
    mostrarCelebracao.value = true
  } catch (erro) {
    console.error('Erro ao criar temporada:', erro)
    mensagem.value = erro instanceof Error ? erro.message : 'Não foi possível criar a temporada.'
  } finally {
    carregando.value = false
  }
}
</script>

<template>
  <section class="pagina-temporada">
    <form class="cartao-temporada" @submit.prevent="iniciarTemporada">
      <span class="etiqueta">NOVO CICLO DE EXECUÇÃO</span>
      <h1>Iniciar temporada</h1>
      <p class="descricao">Defina o que merece sua atenção nas próximas oito semanas.</p>

      <label for="nome">Nome da temporada</label>
      <input id="nome" v-model="nome" type="text" required placeholder="Ex.: Consolidação e consistência" />

      <label for="inicio">Data de início</label>
      <input id="inicio" v-model="dataInicio" type="date" required />

      <div class="grupo-objetivos">
        <span class="titulo-grupo">DIREÇÃO DA TEMPORADA</span>
        <label for="objetivo-principal">Objetivo principal</label>
        <textarea id="objetivo-principal" v-model="objetivoPrincipal" rows="2" required placeholder="Qual é a principal conquista que quero alcançar nestas oito semanas?"></textarea>
        <div class="marcos-cabecalho">
          <label>Marcos da temporada</label>
          <span>Resultados importantes, sem necessidade de medir progresso agora.</span>
        </div>
        <div v-for="(marco, indice) in marcos" :key="indice" class="linha-marco">
          <span class="numero-marco">{{ String(indice + 1).padStart(2, '0') }}</span>
          <input v-model="marcos[indice]" type="text" :aria-label="`Marco ${indice + 1}`" :placeholder="`Descreva o marco ${indice + 1}`" />
          <button type="button" class="remover-marco" :disabled="marcos.length === 1" :aria-label="`Remover marco ${indice + 1}`" @click="removerMarco(indice)">×</button>
        </div>
        <button type="button" class="adicionar-marco" @click="adicionarMarco">+ Adicionar marco</button>
      </div>

      <label for="atividades">Atividades e compromissos</label>
      <textarea id="atividades" v-model="atividadesPlanejadas" rows="3" placeholder="Ex.: Inglês, academia, programação..."></textarea>

      <label for="prioridade">Principal prioridade</label>
      <input id="prioridade" v-model="prioridade" type="text" placeholder="O que não pode ficar em segundo plano?" />

      <label for="criterios">Critérios de sucesso</label>
      <textarea id="criterios" v-model="criteriosSucesso" rows="2" placeholder="Como saberá que a temporada deu certo?"></textarea>

      <p v-if="mensagem" class="mensagem" :class="{ 'mensagem-sucesso': sucesso }">{{ mensagem }}</p>
      <button type="submit" class="botao-criar" :disabled="carregando || sucesso">
        {{ carregando ? 'Criando temporada...' : sucesso ? 'Temporada criada' : 'Iniciar temporada' }}
      </button>
    </form>
    <Celebracao v-if="mostrarCelebracao" tipo="inicio" @terminou="finalizarCelebracao" />
  </section>
</template>

<style scoped>
.pagina-temporada { display:grid; place-items:center; padding:24px 20px; margin:20px 0; background:#f4f7fc; border-radius:16px; }
.cartao-temporada { width:100%; max-width:620px; padding:30px; background:white; border:1px solid #e3eaf5; border-radius:18px; box-shadow:0 8px 28px rgba(25,50,90,.05); display:flex; flex-direction:column; gap:12px; }
.etiqueta,.titulo-grupo { color:#2563eb; font-size:11px; font-weight:700; letter-spacing:1px; }
h1 { margin:0; color:#172b4d; font-size:26px; }
.descricao { margin:0 0 12px; color:#718096; font-size:14px; line-height:1.6; }
label { margin-top:8px; color:#334155; font-size:13px; font-weight:600; }
input,textarea { width:100%; box-sizing:border-box; padding:12px 14px; border:1px solid #dce4ef; border-radius:9px; background:white; color:#172b4d; font:inherit; font-size:14px; }
input:focus,textarea:focus { outline:none; border-color:#2563eb; }
textarea { resize:vertical; }
button { cursor:pointer; font:inherit; }
button:disabled { opacity:.5; cursor:not-allowed; }
.botao-criar { margin-top:16px; padding:13px 20px; background:#2563eb; border:none; border-radius:9px; color:white; font-size:14px; font-weight:700; }
.botao-criar:hover:not(:disabled) { background:#1d4ed8; }
.mensagem { color:#b45309; font-size:13px; line-height:1.5; }
.mensagem-sucesso { color:#15803d; }
.grupo-objetivos { display:flex; flex-direction:column; gap:12px; background:#f5f8ff; border:1px solid #dae6ff; border-radius:13px; padding:18px; margin-top:8px; }
.grupo-objetivos label { margin-top:0; }
.marcos-cabecalho { display:flex; flex-direction:column; gap:4px; }
.marcos-cabecalho span { color:#718096; font-size:12px; }
.linha-marco { display:flex; align-items:center; gap:9px; }
.numero-marco { color:#2563eb; font-size:12px; font-weight:800; min-width:23px; }
.linha-marco input { flex:1; min-width:0; }
.remover-marco { border:1px solid #dce4ef; border-radius:8px; width:34px; height:38px; background:white; color:#64748b; font-size:21px; }
.adicionar-marco { align-self:flex-start; padding:9px 12px; border:1px solid #b8cdfa; border-radius:8px; background:white; color:#2563eb; font-weight:700; font-size:12px; }
</style>
