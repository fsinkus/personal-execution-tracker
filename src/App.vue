<script setup lang="ts">

import { computed, ref, onMounted, onUnmounted } from 'vue'

import NovaTemporada from './components/NovaTemporada.vue'

import EncerrarTemporada from './components/EncerrarTemporada.vue'
import Celebracao from './components/Celebracao.vue'

import { supabase } from './lib/supabase'

type Atividade = {

  id: string

  nome: string

  dia: string

  icone: string

  concluida: boolean

}

type Semana = {
  id: string
  numero: number
  meta_pontos: number
  status: 'aberta' | 'encerrada'
  revisao_resultados: string | null
  revisao_dificuldades: string | null
  revisao_aprendizados: string | null
  revisao_comprometimento: number | null
}

const mostrarGerenciamento = ref(false)
const mostrarRevisao = ref(false)
const celebrandoSemana = ref(false)
const encerrandoSemana = ref(false)
const erroEncerramento = ref('')
const revisaoResultados = ref('')
const revisaoDificuldades = ref('')
const revisaoAprendizados = ref('')
const revisaoComprometimento = ref<number | null>(null)

const mostrarCheckConcluido = ref(false)

let timerCheck: ReturnType<typeof setTimeout> | undefined

// Som curto e suave de confirmação, gerado no navegador sem arquivo de áudio.

function tocarSomConclusao() {

  try {

    const AudioContextClass = window.AudioContext

    if (!AudioContextClass) return

    const contexto = new AudioContextClass()

    const inicio = contexto.currentTime

    const notas = [523.25, 659.25, 783.99]

    notas.forEach((frequencia, indice) => {

      const oscilador = contexto.createOscillator()

      const volume = contexto.createGain()

      const comeco = inicio + indice * 0.085

      oscilador.type = 'sine'

      oscilador.frequency.setValueAtTime(frequencia, comeco)

      volume.gain.setValueAtTime(0.0001, comeco)

      volume.gain.exponentialRampToValueAtTime(0.055, comeco + 0.018)

      volume.gain.exponentialRampToValueAtTime(0.0001, comeco + 0.25)

      oscilador.connect(volume)

      volume.connect(contexto.destination)

      oscilador.start(comeco)

      oscilador.stop(comeco + 0.26)

    })

    setTimeout(() => { void contexto.close() }, 750)

  } catch (erro) {

    console.debug('Áudio de conclusão indisponível:', erro)

  }

}

function celebrarAtividade() {

  if (timerCheck) clearTimeout(timerCheck)

  mostrarCheckConcluido.value = false

  // Reinicia a animação mesmo quando duas atividades são concluídas rapidamente.

  requestAnimationFrame(() => {

    mostrarCheckConcluido.value = true

    timerCheck = setTimeout(() => { mostrarCheckConcluido.value = false }, 1100)

  })

}

onUnmounted(() => { if (timerCheck) clearTimeout(timerCheck) })

const menuRecolhido = ref(false)

const semanaAtual = ref(1)

const temporadaAtual = ref(1)

const temporadaId = ref<string | null>(null)

const nomeTemporada = ref('')
const objetivoPrincipal = ref('')
const marcosTemporada = ref<string[]>([])

const erroTemporada = ref('')

const carregandoTemporada = ref(true)

const carregandoAtividades = ref(false)

const erroAtividades = ref('')

const processandoAtividade = ref(false)

const semanas = ref<Semana[]>([])

const atividades = ref<Atividade[]>([])

const mostrarFormulario = ref(false)

const novaAtividade = ref({ nome: '', dia: 'Segunda', icone: '📌' })

const diaEmDestaque = ref<string | null>(null)

const atividadeArrastada = ref<string | null>(null)

const inicioTemporada = ref(new Date(2026, 9, 12))

const dias = [

  { nome: 'Segunda', curto: 'Seg' }, { nome: 'Terça', curto: 'Ter' },

  { nome: 'Quarta', curto: 'Qua' }, { nome: 'Quinta', curto: 'Qui' },

  { nome: 'Sexta', curto: 'Sex' }, { nome: 'Sábado', curto: 'Sáb' },

  { nome: 'Domingo', curto: 'Dom' }

]

const semanaEncerrada = computed(() => semanaSelecionada()?.status === 'encerrada')
const totalAtividades = computed(() => atividades.value.length)
const percentualRealizado = computed(() => totalAtividades.value ? Math.round(pontos.value / totalAtividades.value * 100) : 0)
const metaSemanal = computed(() => semanas.value.find(s => s.numero === semanaAtual.value)?.meta_pontos ?? 12)

const pontos = computed(() => atividades.value.filter(a => a.concluida).length)

const progresso = computed(() => Math.min((pontos.value / metaSemanal.value) * 100, 100))

const pads = [

  { codigo: 'PAD-003', frase: 'Resultado é retorno repetido ao procedimento.' },

  { codigo: 'PAD-019', frase: 'Ativos intelectuais produzem patrimônio composto.' },

  { codigo: 'PAD-020', frase: 'Mantenha o Rumo e a Chegada Será Inevitável.' }

]

const indiceSalvo = Number(localStorage.getItem('ultimo-pad-exibido') ?? '-1')

const proximoIndice = Number.isInteger(indiceSalvo) ? (indiceSalvo + 1) % pads.length : 0

const padAtual = ref(pads[proximoIndice]!)

localStorage.setItem('ultimo-pad-exibido', String(proximoIndice))

function dataLocal(data: string) { return new Date(`${data}T12:00:00`) }

function calcularSemanaAtual() {

  const hoje = new Date()

  const inicio = inicioTemporada.value

  const diferenca = Math.floor((Date.UTC(hoje.getFullYear(), hoje.getMonth(), hoje.getDate()) - Date.UTC(inicio.getFullYear(), inicio.getMonth(), inicio.getDate())) / 86400000)

  return Math.max(1, Math.min(Math.floor(diferenca / 7) + 1, 8))

}

function periodoDaSemana(semana: number) {

  const inicio = new Date(inicioTemporada.value)

  inicio.setDate(inicio.getDate() + (semana - 1) * 7)

  const fim = new Date(inicio)

  fim.setDate(fim.getDate() + 6)

  const formatar = (data: Date) => data.toLocaleDateString('pt-BR', { day: '2-digit', month: 'short' })

  return `${formatar(inicio)} – ${formatar(fim)}`

}

function semanaSelecionada() { return semanas.value.find(s => s.numero === semanaAtual.value) }

function mensagemErro(erro: unknown) { return erro instanceof Error ? erro.message : 'Erro inesperado.' }

async function carregarTemporadaAtiva() {

  carregandoTemporada.value = true

  erroTemporada.value = ''

  erroAtividades.value = ''

  const { data, error } = await supabase.from('temporadas')

    .select('id, numero, nome, data_inicio, objetivos, objetivo_principal, marcos_temporada').eq('status', 'ativa').maybeSingle()

  if (error) {

    erroTemporada.value = 'Não foi possível consultar a temporada ativa: ' + error.message

    carregandoTemporada.value = false

    return

  }

  if (!data) {

    temporadaId.value = null

    nomeTemporada.value = ''
    objetivoPrincipal.value = ''
    marcosTemporada.value = []

    semanas.value = []

    atividades.value = []

    carregandoTemporada.value = false

    return

  }

  temporadaId.value = data.id

  temporadaAtual.value = data.numero

  nomeTemporada.value = data.nome
  objetivoPrincipal.value = data.objetivo_principal?.trim() || data.objetivos?.trim() || ''
  marcosTemporada.value = Array.isArray(data.marcos_temporada)
    ? data.marcos_temporada.filter((marco: unknown): marco is string => typeof marco === 'string' && marco.trim().length > 0)
    : []

  inicioTemporada.value = dataLocal(data.data_inicio)

  const { data: listaSemanas, error: erroSemanas } = await supabase.from('semanas')

    .select('id, numero, meta_pontos, status, revisao_resultados, revisao_dificuldades, revisao_aprendizados, revisao_comprometimento').eq('temporada_id', data.id).order('numero')

  if (erroSemanas || !listaSemanas || listaSemanas.length !== 8) {

    erroTemporada.value = erroSemanas?.message ?? 'Esta temporada não possui oito semanas cadastradas.'

    carregandoTemporada.value = false

    return

  }

  semanas.value = listaSemanas

  semanaAtual.value = calcularSemanaAtual()

  carregandoTemporada.value = false

  await carregarAtividades()

}

async function carregarAtividades() {

  const semana = semanaSelecionada()

  if (!semana || !temporadaId.value) { atividades.value = []; return }

  carregandoAtividades.value = true

  erroAtividades.value = ''

  const idConsultado = semana.id

  const { data, error } = await supabase.from('atividades')

    .select('id, nome, dia, icone, concluida').eq('semana_id', idConsultado).order('criada_em')

  // Evita que uma resposta atrasada sobrescreva a semana que o usuário selecionou.

  if (semanaSelecionada()?.id !== idConsultado) return

  if (error) {

    erroAtividades.value = 'Não foi possível carregar as atividades: ' + error.message

  } else {

    atividades.value = (data ?? []) as Atividade[]

  }

  carregandoAtividades.value = false

}

async function executarAlteracao(operacao: () => Promise<void>) {

  if (semanaEncerrada.value) {
    erroAtividades.value = 'Esta semana já foi encerrada e está disponível apenas para consulta.'
    return
  }
  if (processandoAtividade.value || carregandoAtividades.value || encerrandoSemana.value || !semanaSelecionada()) return

  processandoAtividade.value = true

  erroAtividades.value = ''

  try { await operacao() }

  catch (erro) { erroAtividades.value = mensagemErro(erro); console.error(erro) }

  finally { processandoAtividade.value = false }

}

async function adicionarAtividade() {

  const nome = novaAtividade.value.nome.trim()

  const semana = semanaSelecionada()

  if (!nome || !semana || !temporadaId.value) return

  await executarAlteracao(async () => {

    const { data: usuario, error: erroUsuario } = await supabase.auth.getUser()

    if (erroUsuario || !usuario.user) throw new Error('Sua sessão expirou. Entre novamente.')

    const { data, error } = await supabase.from('atividades').insert({

      usuario_id: usuario.user.id, semana_id: semana.id, nome,

      dia: novaAtividade.value.dia, icone: novaAtividade.value.icone, concluida: false

    }).select('id, nome, dia, icone, concluida').single()

    if (error) throw error

    atividades.value.push(data as Atividade)

    novaAtividade.value.nome = ''

    novaAtividade.value.icone = '📌'

    mostrarFormulario.value = false

  })

}

async function excluirAtividade(id: string) {

  if (!window.confirm('Deseja realmente excluir esta atividade?')) return

  await executarAlteracao(async () => {

    const { error } = await supabase.from('atividades').delete().eq('id', id)

    if (error) throw error

    atividades.value = atividades.value.filter(a => a.id !== id)

  })

}

async function atualizarAtividade(id: string, alteracoes: Partial<Pick<Atividade, 'dia' | 'concluida'>>) {

  await executarAlteracao(async () => {

    const { data, error } = await supabase.from('atividades').update({

      ...alteracoes,

      ...(typeof alteracoes.concluida === 'boolean' ? { concluida_em: alteracoes.concluida ? new Date().toISOString() : null } : {})

    }).eq('id', id).select('id, nome, dia, icone, concluida').single()

    if (error) throw error

    const indice = atividades.value.findIndex(a => a.id === id)

    if (indice !== -1) atividades.value[indice] = data as Atividade

    if (alteracoes.concluida === true && data.concluida === true) celebrarAtividade()

  })

}

function concluir(id: string) {

  const atividade = atividades.value.find(a => a.id === id)

  if (atividade && !atividade.concluida && !semanaEncerrada.value && !processandoAtividade.value && !carregandoAtividades.value) {

    tocarSomConclusao()

  }

  void atualizarAtividade(id, { concluida: true })

}

function desfazer(id: string) { void atualizarAtividade(id, { concluida: false }) }

function iniciarArraste(id: string) { if (!semanaEncerrada.value) atividadeArrastada.value = id }

function soltarAtividade(diaDestino: string) {

  const id = atividadeArrastada.value

  atividadeArrastada.value = null

  if (!id || semanaEncerrada.value) return

  const atividade = atividades.value.find(a => a.id === id)

  if (atividade && !atividade.concluida && atividade.dia !== diaDestino) {

    void atualizarAtividade(id, { dia: diaDestino })

  }

}

async function mudarSemana(novaSemana: number) {

  if (novaSemana < 1 || novaSemana > 8 || processandoAtividade.value || carregandoAtividades.value || novaSemana === semanaAtual.value) return

  semanaAtual.value = novaSemana
  mostrarRevisao.value = false
  erroEncerramento.value = ''
  mostrarFormulario.value = false
  atividades.value = []

  await carregarAtividades()

}

async function encerrarSemana() {
  const semana = semanaSelecionada()
  if (!semana || semana.status === 'encerrada' || encerrandoSemana.value || processandoAtividade.value || carregandoAtividades.value) return
  erroEncerramento.value = ''
  if (revisaoComprometimento.value === null || revisaoComprometimento.value < 1 || revisaoComprometimento.value > 5) {
    erroEncerramento.value = 'Escolha uma nota de comprometimento de 1 a 5.'
    return
  }
  if (!window.confirm(`Encerrar a semana ${semana.numero}? Depois disso, suas atividades não poderão ser alteradas.`)) return
  encerrandoSemana.value = true
  try {
    const { data: auth, error: erroAuth } = await supabase.auth.getUser()
    if (erroAuth || !auth.user) throw new Error('Sua sessão expirou. Entre novamente.')
    const { data, error } = await supabase.from('semanas').update({
      status: 'encerrada',
      revisao_resultados: revisaoResultados.value.trim(),
      revisao_dificuldades: revisaoDificuldades.value.trim(),
      revisao_aprendizados: revisaoAprendizados.value.trim(),
      revisao_comprometimento: revisaoComprometimento.value
    }).eq('id', semana.id).eq('usuario_id', auth.user.id).eq('status', 'aberta')
      .select('id, status, revisao_resultados, revisao_dificuldades, revisao_aprendizados, revisao_comprometimento').single()
    if (error) throw error
    if (!data) throw new Error('Esta semana não está mais aberta.')
    Object.assign(semana, data)
    mostrarRevisao.value = false
    mostrarFormulario.value = false
    celebrandoSemana.value = true
  } catch (erro) {
    erroEncerramento.value = mensagemErro(erro)
  } finally {
    encerrandoSemana.value = false
  }
}

function proximaSemana() { void mudarSemana(semanaAtual.value + 1) }

function semanaAnterior() { void mudarSemana(semanaAtual.value - 1) }

async function sair() {

  const { error } = await supabase.auth.signOut()

  if (error) { console.error(error); alert('Não foi possível encerrar a sessão.') }

}

onMounted(() => { void carregarTemporadaAtiva() })

</script>

<template>

  <div class="layout">

    <aside

  class="sidebar"

  :class="{ 'sidebar-recolhida': menuRecolhido }"

>

<button

  class="botao-menu"

  type="button"

  :aria-label="menuRecolhido ? 'Expandir menu' : 'Recolher menu'"

  @click="menuRecolhido = !menuRecolhido"

>

  {{ menuRecolhido ? '»' : '«' }}

</button>

      <div class="marca">

        <div class="marca-icone">✦</div>

        <div>

          <strong>Execução</strong>

          <small>Meu espaço</small>

        </div>

      </div>

      <nav class="menu">

  <a class="menu-ativo">

    <span>▦</span>

    <span>Quadro</span>

  </a>

  <a>

    <span>◫</span>

    <span>Progresso</span>

  </a>

  <a>

    <span>☷</span>

    <span>Atividades</span>

  </a>

  <a>

    <span>⚙</span>

    <span>Configurações</span>

  </a>

  <a href="#" :class="{ 'menu-ativo': mostrarGerenciamento }"

     @click.prevent="mostrarGerenciamento = !mostrarGerenciamento"

     :title="mostrarGerenciamento ? 'Voltar ao quadro' : 'Gerenciar temporadas'">

    <span>🗓️</span>

    <span>{{ mostrarGerenciamento ? 'Voltar ao quadro' : 'Gerenciar temporadas' }}</span>

  </a>

</nav>

      <div class="temporada">

  <small>TEMPORADA ATUAL</small>

  <strong>{{ nomeTemporada || 'Nenhuma temporada ativa' }}</strong>

  <span>Semana {{ semanaAtual }} de 8</span>

</div>

    </aside>

    <main class="conteudo">

      <header class="cabecalho">

        <div>

          <span class="etiqueta">

  {{ nomeTemporada || 'SEM TEMPORADA ATIVA' }} · SEMANA {{ semanaAtual }}

</span>

          <h1>Meu quadro semanal</h1>

          <p>Pequenas ações, grandes resultados.</p>

        </div>

        <button class="botao-nova-atividade" @click="mostrarFormulario = !mostrarFormulario" :disabled="!temporadaId || mostrarGerenciamento || semanaEncerrada || carregandoAtividades || processandoAtividade || encerrandoSemana">

  + Nova atividade

</button>

<button class="botao-sair" @click="sair">

  Sair

</button>

<div v-if="mostrarFormulario && !semanaEncerrada && !mostrarGerenciamento" class="formulario-atividade">

  <input

    v-model="novaAtividade.nome"

    type="text"

    placeholder="Nome da atividade"

    @keyup.enter="adicionarAtividade"

  />

  <select v-model="novaAtividade.dia">

    <option

      v-for="dia in dias"

      :key="dia.nome"

      :value="dia.nome"

    >

      {{ dia.nome }}

    </option>

  </select>

   <select v-model="novaAtividade.icone" aria-label="Ícone da atividade">

  <option value="📌">📌 Geral</option>

  <option value="🏋️">🏋️ Academia</option>

  <option value="📘">📘 Estudos</option>

  <option value="🎓">🎓 Faculdade</option>

  <option value="💻">💻 Programação</option>

  <option value="🎸">🎸 Música</option>

  <option value="📚">📚 Leitura</option>

  <option value="🚶">🚶 Caminhada</option>

  <option value="💼">💼 Trabalho</option>

  <option value="🧠">🧠 Desenvolvimento</option>

</select>

  <button @click="adicionarAtividade" :disabled="carregandoAtividades || processandoAtividade">

    Adicionar

  </button>

  <button @click="mostrarFormulario = false">

    Cancelar

  </button>

</div>

      </header>

      <p v-if="erroTemporada" style="color:#b91c1c">{{ erroTemporada }}</p>

        <p v-if="carregandoTemporada">Carregando temporada...</p>

        <p v-if="!carregandoTemporada && !temporadaId && !erroTemporada" class="aviso-sync">Nenhuma temporada ativa. Abra “Gerenciar temporadas” no menu para iniciar.</p>

        <p v-if="erroAtividades" class="aviso-sync">{{ erroAtividades }} <button type="button" @click="carregarAtividades">Tentar novamente</button></p>

        <p v-if="carregandoAtividades" class="aviso-sync">Carregando atividades da semana...</p>

        <p v-if="processandoAtividade" class="aviso-sync">Salvando alteração na nuvem...</p>

<section v-if="mostrarGerenciamento" class="gerenciamento-temporadas">

  <div class="gerenciamento-cabecalho">

    <h2>Gerenciar temporadas</h2>

    <p v-if="temporadaId">Temporada ativa: <strong>{{ nomeTemporada }}</strong></p>

    <p v-else>Não há temporada ativa no momento.</p>

  </div>

  <EncerrarTemporada

    v-if="temporadaId && !carregandoTemporada && !erroTemporada"

    :key="temporadaId"

    :temporada-id="temporadaId"

    :temporada-nome="nomeTemporada"

    @temporada-encerrada="mostrarGerenciamento = false; carregarTemporadaAtiva()"

  />

  <NovaTemporada

    v-if="!temporadaId && !carregandoTemporada && !erroTemporada"

    @temporada-criada="mostrarGerenciamento = false; carregarTemporadaAtiva()"

  />

</section>

        <section v-if="!mostrarGerenciamento && !carregandoTemporada && !erroTemporada && temporadaId" class="secao">

  <div class="faixa-destaques">

    <!-- PROGRESSO SEMANAL -->

    <div class="progresso">

      <div

        class="anel"

        :style="{ '--progresso': progresso + '%' }"

      >

        <div class="anel-centro">

          <strong>{{ pontos }}/{{ metaSemanal }}</strong>

          <small>pontos</small>

        </div>

      </div>

      <div class="progresso-texto">

        <strong>Seu progresso semanal</strong>

        <span>Continue avançando!</span>

      </div>

    </div>

    <!-- PAD ROTATIVO -->

    <div class="cartao-pad">

      <span class="pad-codigo">{{ padAtual.codigo }}</span>

      <p class="pad-frase">{{ padAtual.frase }}</p>

    </div>

    <!-- SELETOR DE SEMANAS -->

    <div class="navegacao-semanas">

      <button

        class="seta-semana"

        @click="semanaAnterior"

        :disabled="semanaAtual === 1 || carregandoAtividades || processandoAtividade"

      >

        ←

      </button>

      <div class="informacoes-semana">

        <span

          class="status-semana"

          :class="{

            'status-semana-atual': semanaAtual === calcularSemanaAtual()

          }"

        >

          {{

            semanaAtual === calcularSemanaAtual()

              ? '● Semana atual'

              : 'Semana selecionada'

          }}

        </span>

        <div class="numeracao-semana">

          <span class="numero-principal">

            {{ String(semanaAtual).padStart(2, '0') }}

          </span>

          <span class="separador-semana">/</span>

          <span class="numero-total">08</span>

        </div>

        <div class="periodo-semana">

          {{ periodoDaSemana(semanaAtual) }}

        </div>

        <div class="linha-progresso-semanas">

          <div

            v-for="numero in 8"

            :key="numero"

            class="etapa-semana"

            :class="{

              'etapa-ativa': numero === semanaAtual,

              'etapa-passada': numero < semanaAtual

            }"

            @click="mudarSemana(numero)"

          >

            {{ numero }}

          </div>

        </div>

      </div>

      <button

        class="seta-semana"

        @click="proximaSemana"

        :disabled="semanaAtual === 8 || carregandoAtividades || processandoAtividade"

      >

        →

      </button>

    </div>

  </div>

        <section class="objetivos-temporada">
          <div class="objetivo-destaque">
            <div class="objetivo-alvo" aria-hidden="true">◎</div>
            <div>
              <span class="objetivo-etiqueta">OBJETIVO PRINCIPAL DA TEMPORADA</span>
              <strong>{{ objetivoPrincipal || 'Objetivo principal ainda não cadastrado.' }}</strong>
              <small>A direção das suas oito semanas.</small>
            </div>
          </div>
          <div class="marcos-temporada">
            <span class="objetivo-etiqueta">MARCOS DA TEMPORADA</span>
            <ol v-if="marcosTemporada.length">
              <li v-for="(marco, indice) in marcosTemporada" :key="indice">
                <span class="numero-marco">{{ String(indice + 1).padStart(2, '0') }}</span>
                <span>{{ marco }}</span>
              </li>
            </ol>
            <p v-else class="sem-marcos">Nenhum marco adicional cadastrado nesta temporada.</p>
          </div>
        </section>
  <div class="quadro">

  <div

    v-for="dia in dias"

    :key="dia.nome"

    class="coluna"

  >

    <div class="coluna-cabecalho">

      <strong>{{ dia.nome }}</strong>

    </div>

    <div

  class="coluna-corpo"

  :class="{ 'coluna-destaque': !semanaEncerrada && diaEmDestaque === dia.nome }"

  @dragover.prevent="!semanaEncerrada && (diaEmDestaque = dia.nome)"

  @dragleave.self="diaEmDestaque = null"

  @drop.prevent="soltarAtividade(dia.nome); diaEmDestaque = null"

>

      <div

        v-for="atividade in atividades.filter(

          a => a.dia === dia.nome && !a.concluida

        )"

        :key="atividade.id"

        class="cartao" :class="{ 'cartao-bloqueado': semanaEncerrada }"

        :draggable="!semanaEncerrada"

        @dragstart="iniciarArraste(atividade.id)"

        @dragend="atividadeArrastada = null"

        @click="!semanaEncerrada && concluir(atividade.id)"

      >

        <span class="cartao-icone">

          {{ atividade.icone }}

        </span>

        <span class="cartao-nome">

          {{ atividade.nome }}

        </span>

        <span class="cartao-check"></span>

        <button

          type="button"

          v-if="!semanaEncerrada" class="botao-excluir"

          title="Excluir atividade"

          aria-label="Excluir atividade"

          @click.stop="excluirAtividade(atividade.id)"

        >

          ×

        </button>

      </div>

    </div>

  </div>

</div>
      <div class="acoes-abaixo-quadro">
        <span v-if="semanaEncerrada" class="semana-finalizada">✓ Semana encerrada — somente leitura</span>
        <button v-else type="button" class="botao-encerrar-semana"
          :disabled="processandoAtividade || carregandoAtividades || encerrandoSemana"
          @click="mostrarRevisao = !mostrarRevisao">
          {{ mostrarRevisao ? 'Cancelar revisão' : 'Encerrar semana' }}
        </button>
      </div>
        <div v-if="mostrarRevisao || semanaEncerrada" class="revisao-semanal">
    <div class="revisao-topo">
      <div>
        <strong>{{ semanaEncerrada ? '✓ Semana encerrada' : 'Revisão da semana' }}</strong>
        <p>{{ semanaEncerrada ? 'Histórico consolidado — somente leitura.' : 'Ao finalizar, as atividades desta semana ficam bloqueadas.' }}</p>
      </div>

    </div>
    <div v-if="mostrarRevisao || semanaEncerrada" class="revisao-corpo">
      <div class="revisao-numeros">
        <span><strong>{{ pontos }}</strong> concluídas</span>
        <span><strong>{{ totalAtividades }}</strong> planejadas</span>
        <span><strong>{{ percentualRealizado }}%</strong> realizadas</span>
        <span><strong>{{ pontos }}/{{ metaSemanal }}</strong> meta de pontos</span>
      </div>
      <template v-if="semanaEncerrada">
        <p><strong>Resultados:</strong> {{ semanaSelecionada()?.revisao_resultados || 'Não informado' }}</p>
        <p><strong>Dificuldades:</strong> {{ semanaSelecionada()?.revisao_dificuldades || 'Não informado' }}</p>
        <p><strong>Aprendizados:</strong> {{ semanaSelecionada()?.revisao_aprendizados || 'Não informado' }}</p>
        <p><strong>Comprometimento:</strong> {{ semanaSelecionada()?.revisao_comprometimento ?? 'Não informado' }}/5</p>
      </template>
      <form v-else class="revisao-formulario" @submit.prevent="encerrarSemana">
        <label>Principais resultados<textarea v-model="revisaoResultados" rows="2" placeholder="O que avançou nesta semana?"></textarea></label>
        <label>Dificuldades<textarea v-model="revisaoDificuldades" rows="2" placeholder="O que atrapalhou a execução?"></textarea></label>
        <label>Aprendizados<textarea v-model="revisaoAprendizados" rows="2" placeholder="O que vale levar para a próxima semana?"></textarea></label>
        <label>Comprometimento (1 a 5)
          <select v-model.number="revisaoComprometimento" required>
            <option :value="null" disabled>Escolha uma nota</option>
            <option v-for="nota in 5" :key="nota" :value="nota">{{ nota }}</option>
          </select>
        </label>
        <p v-if="erroEncerramento" class="erro-revisao">{{ erroEncerramento }}</p>
        <button type="submit" class="botao-encerrar-semana" :disabled="encerrandoSemana || processandoAtividade || carregandoAtividades">
          {{ encerrandoSemana ? 'Encerrando...' : 'Confirmar encerramento' }}
        </button>
      </form>
    </div>
  </div>

      </section>

      <section v-if="!mostrarGerenciamento && temporadaId && !carregandoTemporada && !erroTemporada" class="done">

        <div class="done-cabecalho">

          <div class="done-titulo">

            <span class="done-icone">✓</span>

            <h2>Concluídas</h2>

            <span class="done-contador">{{ pontos }}</span>

          </div>

          <span class="done-subtitulo">

            Cada atividade concluída vale 1 ponto

          </span>

        </div>

        <div class="done-lista">

          <button

            v-for="atividade in atividades.filter(a => a.concluida)"

            :key="atividade.id"

            class="done-cartao"

            @click="!semanaEncerrada && desfazer(atividade.id)" :disabled="semanaEncerrada"

          >

            <span class="cartao-icone">

              {{ atividade.icone }}

            </span>

            <span>{{ atividade.nome }}</span>

            <span v-if="!semanaEncerrada" class="done-remover">↩</span>

          </button>

          <p v-if="pontos === 0" class="done-vazio">

            Suas atividades concluídas aparecerão aqui.

          </p>

        </div>

      </section>

    </main>

  </div>

  <Celebracao v-if="celebrandoSemana" tipo="semana" @terminou="celebrandoSemana = false" />
  <div v-if="mostrarCheckConcluido" class="check-concluido" aria-label="Atividade concluída" role="status">

    <div class="check-circulo">

      <svg viewBox="0 0 64 64" aria-hidden="true">

        <path d="M15 33 L27 45 L50 20" fill="none" stroke="currentColor" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" />

      </svg>

    </div>

    <strong class="check-texto">Atividade concluída!</strong>

  </div>

</template>

<style scoped>

* {

  box-sizing: border-box;

}

.layout {

  display: flex;

  height: 100vh;

  overflow: hidden;

  background: #f6f8fc;

  color: #17233b;

  font-family: Inter, Arial, sans-serif;

}

.sidebar {

  width: 225px;

  min-width: 225px;

  background: #ffffff;

  border-right: 1px solid #e8edf5;

  padding: 28px 16px;

  display: flex;

  flex-direction: column;

}

.marca {

  display: flex;

  align-items: center;

  gap: 12px;

  padding: 0 10px;

}

.marca-icone {

  width: 42px;

  height: 42px;

  background: #2764f5;

  border-radius: 13px;

  color: white;

  display: grid;

  place-items: center;

  font-size: 25px;

}

.marca strong,

.marca small {

  display: block;

}

.marca strong {

  font-size: 17px;

}

.marca small {

  color: #8290a5;

  font-size: 12px;

  margin-top: 3px;

}

.menu {

  display: flex;

  flex-direction: column;

  gap: 8px;

  margin-top: 48px;

}

.menu a {

  display: flex;

  gap: 14px;

  align-items: center;

  padding: 13px 16px;

  border-radius: 11px;

  color: #63718a;

  font-size: 14px;

  font-weight: 500;

}

.menu-ativo {

  background: #eaf0ff;

  color: #245df0 !important;

}

.temporada {

  margin-top: auto;

  padding: 18px;

  background: #edf3ff;

  border-radius: 14px;

  display: flex;

  flex-direction: column;

  gap: 6px;

}

.temporada small {

  color: #6780b0;

  font-size: 10px;

  font-weight: 700;

}

.temporada strong {

  font-size: 14px;

}

.temporada span {

  font-size: 12px;

  color: #70809b;

}

.conteudo {

  flex: 1;

  min-width: 0;

  min-height: 0;

  padding: 24px 30px;

  overflow-y: auto;

}

.cabecalho {

  display: flex;

  align-items: center;

  justify-content: space-between;

  gap: 24px;

  margin-bottom: 24px;

}

.cabecalho h1 {

  font-size: 30px;

  font-weight: 800;

  letter-spacing: -1.2px;

  line-height: 1.2;

  color: #25334c;

}

.etiqueta {

  font-size: 11px;

  font-weight: 700;

  color: #376df0;

  letter-spacing: 1px;

}

.cabecalho p {

  margin: 0;

  color: #8490a3;

  font-size: 14px;

}

.progresso {

  display: flex;

  align-items: center;

  gap: 16px;

  background: white;

  border: 1px solid #e9edf5;

  border-radius: 18px;

  padding: 12px 22px 12px 12px;

}

.anel {

  width: 74px;

  height: 74px;

  border-radius: 50%;

  background: conic-gradient(

    #21bf91 var(--progresso),

    #e7edf5 0

  );

  display: grid;

  place-items: center;

}

.anel-centro {

  width: 60px;

  height: 60px;

  border-radius: 50%;

  background: white;

  display: flex;

  flex-direction: column;

  justify-content: center;

  align-items: center;

}

.anel-centro strong {

  font-size: 19px;

}

.anel-centro small {

  font-size: 10px;

  color: #8490a3;

}

.progresso-texto {

  display: flex;

  flex-direction: column;

  gap: 5px;

}

.progresso-texto strong {

  font-size: 13px;

}

.progresso-texto span {

  font-size: 12px;

  color: #8995a7;

}

.secao-titulo {

  display: flex;

  justify-content: space-between;

  align-items: center;

  margin-bottom: 18px;

}

.secao-titulo h2,

.done h2 {

  font-size: 18px;

  margin: 0;

}

.secao-titulo > span {

  color: #8490a3;

  font-size: 13px;

}

.quadro {

  display: grid;

  grid-template-columns: repeat(7, minmax(0, 1fr));

  gap: 10px;

  width: 100%;

  padding-bottom: 12px;

}

.coluna {

  min-height: 240px;

  border: 1px solid #e8edf5;

  border-radius: 15px;

  background: #f0f3f9;

  overflow: hidden;

}

.coluna-cabecalho {

  background: white;

  padding: 17px 10px;

  border-bottom: 1px solid #e8edf5;

  display: flex;

  align-items: center;

  justify-content: center;

  position: relative;

  text-align: center;

}

.coluna-cabecalho strong {

  font-size: 13px;

  font-weight: 600;

}

/* Linha azul animada */

.coluna-cabecalho::after {

  content: "";

  position: absolute;

  bottom: 0;

  left: 50%;

  width: 36px;

  height: 3px;

  background: #4263eb;

  border-radius: 3px 3px 0 0;

  transform: translateX(-50%) scaleX(0);

  opacity: 0;

  transition:

    transform 0.2s ease,

    opacity 0.2s ease;

}

.coluna:hover .coluna-cabecalho::after {

  transform: translateX(-50%) scaleX(1);

  opacity: 1;

}

.coluna-corpo {

  padding: 9px;

  display: flex;

  flex-direction: column;

  gap: 9px;

}

.cartao {

  width: 100%;

  display: flex;

  align-items: center;

  gap: 8px;

  padding: 11px 9px;

  background: #ffffff;

  border: 1px solid #e3e9f4;

  border-radius: 10px;

  box-shadow: 0 2px 4px rgba(35, 60, 100, 0.025);

  text-align: left;

  cursor: pointer;

  font-family: 'Manrope', Arial, sans-serif;

  transition:

    transform 0.18s ease,

    box-shadow 0.18s ease,

    border-color 0.18s ease,

    background 0.18s ease;

}

.cartao:hover {

  transform: translateY(-2px);

  background: #fafdff;

  border-color: #9db8f5;

  box-shadow: 0 5px 14px rgba(66, 99, 235, 0.10);

}

.cartao-icone {

  font-size: 19px;

  flex-shrink: 0;

}

.cartao-nome {

  font-size: 12px;

  font-weight: 600;

  flex: 1;

  min-width: 0;

  overflow-wrap: anywhere;

  color: #25334c;

  line-height: 1.4;

   white-space: nowrap;

  overflow: hidden;

  text-overflow: ellipsis;

  min-width: 0;

}

.cartao-check {

  width: 15px;

  height: 15px;

  border: 1.5px solid #bac7d9;

  border-radius: 50%;

  flex-shrink: 0;

}

.done {

  margin-top: 18px;

  padding: 18px;

  border-radius: 17px;

  background: white;

  border: 1px solid #e8edf5;

}

.done-cabecalho {

  display: flex;

  align-items: center;

  justify-content: space-between;

  gap: 12px;

  margin-bottom: 20px;

}

.done-titulo {

  display: flex;

  align-items: center;

  gap: 10px;

}

.done-icone {

  width: 28px;

  height: 28px;

  background: #20bf91;

  color: white;

  border-radius: 50%;

  display: grid;

  place-items: center;

}

.done-contador {

  background: #d9f8ed;

  color: #128864;

  padding: 4px 10px;

  border-radius: 20px;

  font-size: 12px;

  font-weight: 700;

}

.done-subtitulo {

  color: #94a0b0;

  font-size: 12px;

}

.done-lista {

  display: flex;

  flex-wrap: wrap;

  gap: 12px;

}

.done-cartao {

  min-width: 165px;

  display: flex;

  align-items: center;

  gap: 10px;

  padding: 13px;

  border-radius: 11px;

  background: #f8fafc;

  border: 1px solid #e7edf5;

  cursor: pointer;

  font-family: inherit;

  font-size: 12px;

  font-weight: 600;

  color: #25334c;

}

.done-remover {

  margin-left: auto;

  color: #8392a8;

}

.done-vazio {

  color: #a0aabb;

  font-size: 13px;

}

@media (max-width: 900px) {

  .sidebar {

    display: none;

  }

  .conteudo {

    padding: 22px;

  }

  .cabecalho {

    flex-direction: column;

    align-items: flex-start;

  }

  .progresso {

    width: 100%;

  }

}

/* Transição suave ao recolher e expandir */

.sidebar {

  position: relative;

  transition: width 0.25s ease, min-width 0.25s ease;

}

.sidebar-recolhida {

  width: 76px;

  min-width: 76px;

}

/* Botão de recolher */

.botao-menu {

  position: absolute;

  top: 32px;

  right: -13px;

  z-index: 5;

  width: 27px;

  height: 27px;

  border-radius: 50%;

  border: 1px solid #e3e9f3;

  background: white;

  color: #53647e;

  cursor: pointer;

  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);

}

.botao-menu:hover {

  background: #edf3ff;

}

/* Ajustes quando recolhida */

.sidebar-recolhida .marca {

  justify-content: center;

  padding: 0;

}

.sidebar-recolhida .marca > div:last-child {

  display: none;

}

.sidebar-recolhida .menu {

  align-items: center;

}

.sidebar-recolhida .menu a {

  width: 46px;

  justify-content: center;

  padding: 13px 0;

  font-size: 19px;

}

.sidebar-recolhida .menu a span {

  display: none;

}

.sidebar-recolhida .temporada {

  display: none;

}

.botao-nova-atividade {

  background: #2563eb;

  color: white;

  border: none;

  border-radius: 10px;

  padding: 10px 16px;

  font-weight: 700;

  cursor: pointer;

  margin-bottom: 16px;

}

.botao-nova-atividade:hover {

  background: #1d4ed8;

}

.formulario-atividade {

  display: flex;

  flex-wrap: wrap;

  gap: 10px;

  padding: 16px;

  margin-bottom: 18px;

  background: #f4f7fc;

  border: 1px solid #e3e9f3;

  border-radius: 14px;

}

.formulario-atividade input,

.formulario-atividade select {

  padding: 10px 12px;

  border: 1px solid #d8e1ed;

  border-radius: 8px;

  background: white;

  color: #25334c;

}

.formulario-atividade button {

  padding: 10px 14px;

  border: none;

  border-radius: 8px;

  cursor: pointer;

  background: #e3e9f3;

  color: #25334c;

  font-weight: 700;

}

.formulario-atividade button:first-of-type {

  background: #21bf91;

  color: white;

}

.cartao {

  position: relative;

}

.botao-excluir {

  position: absolute;

  top: -9px;

  right: -9px;

  width: 22px;

  height: 22px;

  border: none;

  border-radius: 6px;

  background: transparent;

  color: #94a3b8;

  font-size: 18px;

  line-height: 1;

  cursor: pointer;

  opacity: 0;

  transition: 0.2s;

}

.cartao:hover .botao-excluir,

.botao-excluir:focus-visible {

  opacity: 1;

}

.botao-excluir:hover {

  background: #fee2e2;

  color: #dc2626;

}

.cartao {

  cursor: grab;

  user-select: none;

}

.cartao:active {

  cursor: grabbing;

}

.coluna-corpo {

  min-height: 160px;

}

.coluna-corpo {

  transition: background-color 0.2s ease;

  border-radius: 12px;

}

.coluna-corpo.coluna-destaque {

  background: #eaf2ff;

  outline: 2px dashed #93b4f5;

  outline-offset: -2px;

}

.navegacao-semanas {

  display: flex;

  align-items: center;

  gap: 20px;

}

.informacoes-semana {

  display: flex;

  flex-direction: column;

  align-items: center;

  gap: 9px;

  width: 290px;

  flex-shrink: 0;

}

.semana-linha {

  display: flex;

  align-items: center;

  gap: 10px;

}

.semana-texto {

  font-size: 15px;

  font-weight: 700;

  color: #25334c;

}

.numero-semana {

  width: 34px;

  height: 34px;

  display: grid;

  place-items: center;

  border-radius: 9px;

  font-size: 17px;

  font-weight: 800;

}

.numero-semana.ativo {

  background: #2563eb;

  color: white;

}

.numero-semana.total {

  background: #e9edf5;

  color: #25334c;

}

.indicador-atual {

  background: #eaf1ff;

  color: #2563eb;

  padding: 7px 12px;

  border-radius: 20px;

  font-size: 11px;

  font-weight: 700;

  white-space: nowrap;

}

.periodo-semana {

  font-size: 13px;

  color: #8490a3;

  font-weight: 600;

}

.linha-progresso-semanas {

  display: flex;

  align-items: center;

  gap: 7px;

  position: relative;

  isolation: isolate;

  justify-content: center;

}

/* Linha que conecta as oito semanas */

.linha-progresso-semanas::before {

  content: "";

  position: absolute;

  left: 12px;

  right: 12px;

  top: 50%;

  height: 3px;

  background: #d5deed;

  transform: translateY(-50%);

  z-index: -1;

}

.etapa-semana {

  width: 24px;

  height: 24px;

  border: 2px solid #d5deed;

  border-radius: 50%;

  background: white;

  color: #8290a5;

  display: grid;

  place-items: center;

  font-size: 11px;

  font-weight: 700;

  cursor: pointer;

}

.etapa-semana:hover {

  border-color: #2563eb;

}

.etapa-semana.etapa-ativa {

  background: #2563eb;

  border-color: #2563eb;

  color: white;

}

.etapa-semana.etapa-passada {

  background: #dbeafe;

  border-color: #93b4f5;

  color: #2563eb;

}

.seta-semana {

  width: 34px;

  height: 34px;

  border: 1px solid #e3e9f3;

  border-radius: 9px;

  background: white;

  color: #2563eb;

  font-size: 18px;

  cursor: pointer;

}

.seta-semana:hover:not(:disabled) {

  background: #edf3ff;

}

.seta-semana:disabled {

  opacity: 0.3;

  cursor: not-allowed;

}

.semana-linha {

  min-height: 34px;

}

.indicador-atual {

  min-width: 100px;

  text-align: center;

}

/* Novo visual do seletor de semanas */

.informacoes-semana {

  width: 290px;

  flex-shrink: 0;

  display: flex;

  flex-direction: column;

  align-items: center;

  gap: 8px;

}

.status-semana {

  display: inline-block;

  min-width: 130px;

  padding: 6px 12px;

  border-radius: 20px;

  background: #edf0f5;

  color: #7b879a;

  text-align: center;

  font-size: 11px;

  font-weight: 700;

  white-space: nowrap;

}

.status-semana-atual {

  background: #eaf1ff;

  color: #2563eb;

}

.numeracao-semana {

  display: flex;

  align-items: center;

  justify-content: center;

  gap: 10px;

}

.numero-principal {

  color: #2563eb;

  font-size: 30px;

  font-weight: 800;

  line-height: 1.1;

}

.separador-semana {

  color: #c4cedc;

  font-size: 23px;

}

.numero-total {

  color: #9aa7b9;

  font-size: 24px;

  font-weight: 700;

  line-height: 1.1;

}

.periodo-semana {

  font-size: 12px;

  color: #8490a3;

  font-weight: 600;

}

.linha-progresso-semanas {

  display: flex;

  align-items: center;

  justify-content: center;

  gap: 7px;

  position: relative;

  isolation: isolate;

}

.linha-progresso-semanas::before {

  content: "";

  position: absolute;

  left: 12px;

  right: 12px;

  top: 50%;

  height: 3px;

  background: #d5deed;

  transform: translateY(-50%);

  z-index: -1;

}

.etapa-semana {

  position: relative;

  z-index: 1;

}

.cartao-pad {

  padding: 18px 22px;

  margin-bottom: 20px;

  background: #edf3ff;

  border: 1px solid #dce7fc;

  border-radius: 14px;

}

.pad-codigo {

  display: block;

  color: #2563eb;

  font-size: 11px;

  font-weight: 800;

  margin-bottom: 6px;

}

.pad-frase {

  margin: 0;

  color: #25334c;

  font-size: 15px;

  font-weight: 600;

  line-height: 1.5;

}

.faixa-destaques {

  display: grid;

  grid-template-columns: 1fr 1fr;

  gap: 16px;

  margin: 18px 0 24px;

  align-items: stretch;

}

.faixa-destaques > * {

  min-width: 0;

}

.faixa-destaques .progresso {

  width: 100%;

  height: 100%;

  box-sizing: border-box;

  justify-content: flex-start;

  background: #edf3ff;

  border: 1px solid #dce7fc;

  border-radius: 14px;

  padding: 16px 20px;

}

.faixa-destaques .cartao-pad {

  margin: 0;

  display: flex;

  flex-direction: column;

  justify-content: center;

}

@media (max-width: 900px) {

  .faixa-destaques {

    grid-template-columns: 1fr;

  }

}

/* Faixa com progresso, PAD e navegação */

.faixa-destaques {

  display: grid;

  grid-template-columns:

    minmax(0, 1fr)

    minmax(0, 1fr)

    340px;

  gap: 14px;

  align-items: stretch;

  margin: 18px 0 24px;

}

.faixa-destaques > * {

  min-width: 0;

}

.faixa-destaques .progresso {

  width: 100%;

  height: 100%;

  box-sizing: border-box;

}

.faixa-destaques .cartao-pad {

  margin: 0;

}

.faixa-destaques .navegacao-semanas {

  display: flex;

  align-items: center;

  justify-content: center;

  gap: 8px;

}

.faixa-destaques .informacoes-semana {

  width: 250px;

  flex-shrink: 1;

}

@media (max-width: 1150px) {

  .faixa-destaques {

    grid-template-columns: 1fr;

  }

}

.botao-sair {

  padding: 9px 14px;

  border: 1px solid #dbe3ee;

  border-radius: 8px;

  background: white;

  color: #64748b;

  font-size: 12px;

  font-weight: 600;

  cursor: pointer;

}

.botao-sair:hover {

  background: #f1f5f9;

}

.aviso-sync { padding: 12px 16px; margin: 12px 0; background: #fff7ed; border: 1px solid #fed7aa; color: #92400e; border-radius: 10px; font-size: 13px; }

.aviso-sync button { margin-left: 8px; cursor: pointer; }

.gerenciamento-temporadas { padding: 8px 0 30px; }

.gerenciamento-cabecalho { max-width: 650px; margin: 0 auto 10px; }

.gerenciamento-cabecalho h2 { font-size: 22px; color: #25334c; margin: 8px 0; }

.gerenciamento-cabecalho p { font-size: 14px; color: #64748b; }

.menu a { cursor: pointer; text-decoration: none; }

.sidebar-recolhida .menu a span:first-child { display: inline; }

.check-concluido {

  position: fixed; inset: 0; z-index: 10000; pointer-events: none;

  display: flex; flex-direction: column; align-items: center; justify-content: center;

  gap: 18px;

  animation: check-sumir 1.1s ease-out both;

}

.check-texto {

  color: #17233b;

  font-size: 22px;

  font-weight: 800;

  letter-spacing: -.3px;

  text-align: center;

  text-shadow: 0 1px 8px rgba(255,255,255,.9);

  animation: check-entrar 1.1s cubic-bezier(.2, .8, .2, 1) both;

}

.check-circulo {

  width: 112px; height: 112px; border-radius: 50%;

  background: #20bf91; color: white;

  box-shadow: 0 12px 36px rgba(22, 163, 116, .24);

  display: grid; place-items: center;

  animation: check-entrar 1.1s cubic-bezier(.2, .8, .2, 1) both;

}

.check-circulo svg { width: 65px; height: 65px; }

.check-circulo path { stroke-dasharray: 70; stroke-dashoffset: 70; animation: check-tracar .38s ease-out .14s forwards; }

@keyframes check-entrar {

  0% { transform: scale(.5); opacity: 0; }

  25% { transform: scale(1.08); opacity: 1; }

  38%, 72% { transform: scale(1); opacity: 1; }

  100% { transform: scale(.92); opacity: 0; }

}

@keyframes check-tracar { to { stroke-dashoffset: 0; } }

@keyframes check-sumir { 0%, 75% { opacity: 1; } 100% { opacity: 0; } }

@media (prefers-reduced-motion: reduce) {

  .check-concluido, .check-circulo, .check-circulo path { animation: none; }

}

.revisao-semanal { background: #fff; border: 1px solid #e3eaf5; border-radius: 14px; padding: 18px 20px; margin: 0 0 22px; }
.revisao-topo { display: flex; align-items: center; justify-content: space-between; gap: 15px; }
.revisao-topo strong { font-size: 15px; color: #25334c; }
.revisao-topo p { color: #8290a5; font-size: 12px; margin: 6px 0 0; }
.botao-encerrar-semana { border: 0; border-radius: 9px; padding: 11px 16px; background: #2563eb; color: white; font-weight: 700; cursor: pointer; }
.botao-encerrar-semana:disabled { opacity: .5; cursor: not-allowed; }
.revisao-corpo { border-top: 1px solid #e8edf5; padding-top: 18px; margin-top: 18px; }
.revisao-numeros { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 18px; }
.revisao-numeros span { background: #edf3ff; padding: 10px 13px; border-radius: 9px; font-size: 12px; color: #52627e; }
.revisao-numeros strong { color: #25334c; }
.revisao-corpo > p { color: #52627e; font-size: 13px; white-space: pre-wrap; }
.revisao-formulario { display: grid; gap: 12px; max-width: 720px; }
.revisao-formulario label { display: grid; gap: 6px; font-size: 13px; font-weight: 600; color: #25334c; }
.revisao-formulario textarea, .revisao-formulario select { border: 1px solid #d8e1ed; border-radius: 9px; padding: 11px; font: inherit; background: white; color: #25334c; }
.revisao-formulario select { max-width: 220px; }
.revisao-formulario button { justify-self: start; }
.erro-revisao { color: #b91c1c; font-size: 13px; }
.cartao-bloqueado { cursor: default !important; opacity: .85; }
.cartao-bloqueado:hover { transform: none; }
.done-cartao:disabled { cursor: default; opacity: 1; }
@media(max-width:700px) { .revisao-topo { flex-direction: column; align-items: flex-start; } }
.objetivos-temporada { display:grid; grid-template-columns: minmax(0, 1fr) minmax(0, 1.3fr); gap:22px; padding:20px 24px; background:#f0f5ff; border:1px solid #dce7fc; border-radius:15px; margin:0 0 22px; }
.objetivo-destaque { display:flex; align-items:center; gap:18px; min-width:0; }
.objetivo-alvo { width:58px; height:58px; border-radius:16px; flex-shrink:0; display:grid; place-items:center; background:#e0ebff; color:#2563eb; font-size:50px; line-height:1; }
.objetivo-destaque > div:last-child { display:flex; flex-direction:column; gap:6px; min-width:0; }
.objetivo-destaque strong { font-size:16px; line-height:1.45; color:#172b4d; white-space:pre-wrap; overflow-wrap:anywhere; }
.objetivo-destaque small { font-size:12px; color:#8290a5; }
.objetivo-etiqueta { font-size:10px; font-weight:800; letter-spacing:.7px; color:#3268d7; }
.marcos-temporada { border-left:1px solid #cfddf5; padding-left:22px; min-width:0; }
.marcos-temporada ol { list-style:none; padding:0; margin:12px 0 0; display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:12px 20px; }
.marcos-temporada li { display:flex; align-items:flex-start; gap:10px; color:#25334c; font-size:13px; line-height:1.45; overflow-wrap:anywhere; }
.numero-marco { font-size:11px; color:#2563eb; font-weight:800; background:white; border-radius:7px; padding:5px 7px; }
.sem-marcos { font-size:12px; color:#8290a5; }
.acoes-abaixo-quadro { display:flex; justify-content:flex-end; margin:0 0 14px; }
.semana-finalizada { font-size:12px; color:#128864; font-weight:700; padding:10px; }
@media(max-width:1000px) { .objetivos-temporada { grid-template-columns:1fr; } .marcos-temporada { border-left:0; border-top:1px solid #cfddf5; padding:15px 0 0; } }
@media(max-width:650px) { .marcos-temporada ol { grid-template-columns:1fr; } }
</style>
