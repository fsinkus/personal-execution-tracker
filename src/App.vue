

<script setup lang="ts">

import { computed, ref, watch, onMounted } from 'vue'



import NovaTemporada from './components/NovaTemporada.vue'



import { supabase } from './lib/supabase'



const mostrarNovaTemporada = ref(false)

async function sair() {

  const { error } = await supabase.auth.signOut()



  if (error) {

    console.error('Erro ao sair:', error.message)

    alert('Não foi possível encerrar a sessão.')

  }

}



const diaEmDestaque = ref<string | null>(null)

const atividadeArrastada = ref<number | null>(null)



function iniciarArraste(id: number) {

  atividadeArrastada.value = id

}



function soltarAtividade(diaDestino: string) {

  if (atividadeArrastada.value === null) return



  const atividade = atividades.value.find(

    a => a.id === atividadeArrastada.value

  )



  if (atividade && !atividade.concluida) {

    atividade.dia = diaDestino

  }



  atividadeArrastada.value = null

}



const menuRecolhido = ref(false)

const semanaAtual = ref(1)

const temporadaAtual = ref(1)
const temporadaId = ref<string | null>(null)
const nomeTemporada = ref('')
const erroTemporada = ref('')
const carregandoTemporada = ref(true)

function dataLocal(data: string) {
  return new Date(`${data}T12:00:00`)
}

async function carregarTemporadaAtiva() {
  carregandoTemporada.value = true
  erroTemporada.value = ''
  const { data, error } = await supabase.from('temporadas')
    .select('id, numero, nome, data_inicio')
    .eq('status', 'ativa')
    .maybeSingle()

  if (error) {
    erroTemporada.value = 'Não foi possível consultar a temporada ativa.'
    console.error(error)
    carregandoTemporada.value = false
    return
  }

  if (data) {
    temporadaId.value = data.id
    temporadaAtual.value = data.numero
    nomeTemporada.value = data.nome
    inicioTemporada.setTime(dataLocal(data.data_inicio).getTime())
  } else {
    temporadaId.value = null
    nomeTemporada.value = ''
  }

  semanaAtual.value = calcularSemanaAtual()
  atividades.value = carregarAtividades(temporadaAtual.value, semanaAtual.value)
  carregandoTemporada.value = false
}

onMounted(() => { void carregarTemporadaAtiva() })



// A primeira temporada começa em 12/10/2026

const inicioTemporada = new Date(2026, 9, 12)



// Calcula as datas de cada semana

function periodoDaSemana(semana: number) {

  const inicio = new Date(inicioTemporada)

  inicio.setDate(inicio.getDate() + (semana - 1) * 7)



  const fim = new Date(inicio)

  fim.setDate(fim.getDate() + 6)



  const formatar = (data: Date) =>

    data.toLocaleDateString('pt-BR', {

      day: '2-digit',

      month: 'short'

    })



  return `${formatar(inicio)} – ${formatar(fim)}`

}



// Descobre qual semana corresponde à data de hoje

function calcularSemanaAtual() {

  const hoje = new Date()



  const diferencaDias = Math.floor(

    (

      Date.UTC(hoje.getFullYear(), hoje.getMonth(), hoje.getDate()) -

      Date.UTC(inicioTemporada.getFullYear(), inicioTemporada.getMonth(), inicioTemporada.getDate())

    ) / 86400000

  )



  const semana = Math.floor(diferencaDias / 7) + 1



  return Math.max(1, Math.min(semana, 8))

}



// Seleciona a semana correta antes de carregar as atividades

semanaAtual.value = calcularSemanaAtual()



const dias = [

  { nome: 'Segunda', curto: 'Seg' },

  { nome: 'Terça', curto: 'Ter' },

  { nome: 'Quarta', curto: 'Qua' },

  { nome: 'Quinta', curto: 'Qui' },

  { nome: 'Sexta', curto: 'Sex' },

  { nome: 'Sábado', curto: 'Sáb' },

  { nome: 'Domingo', curto: 'Dom' }

]



const atividades = ref([

  { id: 1, nome: 'Academia', dia: 'Segunda', icone: '🏋️', concluida: false },

  { id: 2, nome: 'Inglês', dia: 'Terça', icone: '📘', concluida: false },

  { id: 3, nome: 'Impacta', dia: 'Quarta', icone: '🎓', concluida: false },

  { id: 4, nome: 'DevOps', dia: 'Quinta', icone: '💻', concluida: false }

])



const mostrarFormulario = ref(false)



const novaAtividade = ref({

  nome: '',

  dia: 'Segunda',

  icone: '📌',

})



function adicionarAtividade() {

  const nome = novaAtividade.value.nome.trim()



  if (!nome) return



  atividades.value.push({

    id: Date.now(),

    nome,

    dia: novaAtividade.value.dia,

    icone: novaAtividade.value.icone,

    concluida: false,

  })



 novaAtividade.value.nome = ''

novaAtividade.value.icone = '📌'

mostrarFormulario.value = false

}





function excluirAtividade(id: number) {

  const confirmar = window.confirm(

    'Deseja realmente excluir esta atividade?'

  )



  if (!confirmar) return



  atividades.value = atividades.value.filter(

    atividade => atividade.id !== id

  )

}

// Identifica o armazenamento de cada semana e temporada

function chaveDaSemana(temporada: number, semana: number) {

  return temporadaId.value ? `atividades-cloud-pendente-${temporadaId.value}-s${semana}` : `atividades-t${temporada}-s${semana}`

}



// Recupera as atividades salvas de uma semana

function carregarAtividades(temporada: number, semana: number) {

  const dadosSalvos = localStorage.getItem(

    chaveDaSemana(temporada, semana)

  )



  if (!dadosSalvos) return []



  try {

    const dados = JSON.parse(dadosSalvos)

    return Array.isArray(dados) ? dados : []

  } catch (erro) {

    console.error('Erro ao carregar atividades:', erro)

    return []

  }

}



// Migra os dados antigos para a primeira semana

const chaveAntiga = 'atividades-semanais'

const chavePrimeiraSemana = chaveDaSemana(1, 1)



if (

  localStorage.getItem(chavePrimeiraSemana) === null &&

  localStorage.getItem(chaveAntiga) !== null

) {

  localStorage.setItem(

    chavePrimeiraSemana,

    localStorage.getItem(chaveAntiga)!

  )

}



// Carrega a semana inicial

atividades.value = carregarAtividades(

  temporadaAtual.value,

  semanaAtual.value

)



// Salva automaticamente as alterações

watch(

  atividades,

  (novasAtividades) => {

    localStorage.setItem(

      chaveDaSemana(temporadaAtual.value, semanaAtual.value),

      JSON.stringify(novasAtividades)

    )

  },

  { deep: true }

)

const metaSemanal = 12



const pads = [

  {

    codigo: 'PAD-003',

    frase: 'Resultado é retorno repetido ao procedimento.'

  },

  {

    codigo: 'PAD-019',

    frase: 'Ativos intelectuais produzem patrimônio composto.'

  },

  {

    codigo: 'PAD-020',

    frase: 'Mantenha o Rumo e a Chegada Será Inevitável.'

  }

]



const indiceSalvo = Number(localStorage.getItem('ultimo-pad-exibido') ?? '-1')



const proximoIndice = Number.isInteger(indiceSalvo)

  ? (indiceSalvo + 1) % pads.length

  : 0



const padAtual = ref(pads[proximoIndice]!)



localStorage.setItem('ultimo-pad-exibido', String(proximoIndice))



function mudarSemana(novaSemana: number) {

  if (novaSemana < 1 || novaSemana > 8) return



  // Salva os dados da semana que estamos deixando

  localStorage.setItem(

    chaveDaSemana(temporadaAtual.value, semanaAtual.value),

    JSON.stringify(atividades.value)

  )



  // Recupera os dados da semana de destino

  const atividadesDestino = carregarAtividades(

    temporadaAtual.value,

    novaSemana

  )



  // Atualiza a semana antes de carregar suas atividades

  semanaAtual.value = novaSemana

  atividades.value = atividadesDestino

}



function proximaSemana() {

  mudarSemana(semanaAtual.value + 1)

}



function semanaAnterior() {

  mudarSemana(semanaAtual.value - 1)

}



const pontos = computed(() =>

  atividades.value.filter(a => a.concluida).length

)



const progresso = computed(() =>

  Math.min((pontos.value / metaSemanal) * 100, 100)

)



function concluir(id: number) {

  const atividade = atividades.value.find(a => a.id === id)



  if (atividade) {

    atividade.concluida = true

  }

}



function desfazer(id: number) {

  const atividade = atividades.value.find(a => a.id === id)



  if (atividade) {

    atividade.concluida = false

  }

}

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



  <a

    href="#"

    @click.prevent="mostrarNovaTemporada = !mostrarNovaTemporada"

  >

    <span>🗓️</span>

    <span>

      {{ mostrarNovaTemporada ? 'Fechar temporada' : 'Nova temporada' }}

    </span>

  </a>

</nav>





      <div class="temporada">

  <small>TEMPORADA ATUAL</small>

  <strong>{{ nomeTemporada || `Temporada ${temporadaAtual}` }}</strong>

  <span>Semana {{ semanaAtual }} de 8</span>

</div>

    </aside>





    <main class="conteudo">

      <header class="cabecalho">



        <div>

          <span class="etiqueta">

  {{ nomeTemporada || `TEMPORADA ${temporadaAtual}` }} · SEMANA {{ semanaAtual }}

</span>

          <h1>Meu quadro semanal</h1>

          <p>Pequenas ações, grandes resultados.</p>

        </div>

        <button class="botao-nova-atividade" @click="mostrarFormulario = !mostrarFormulario">

  + Nova atividade

</button>





<button class="botao-sair" @click="sair">

  Sair

</button>



<div v-if="mostrarFormulario" class="formulario-atividade">

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



  <button @click="adicionarAtividade">

    Adicionar

  </button>



  <button @click="mostrarFormulario = false">

    Cancelar

  </button>

</div>





      </header>



      <p v-if="erroTemporada" style="color:#b91c1c">{{ erroTemporada }}</p>
        <p v-if="carregandoTemporada">Carregando temporada...</p>
        <section v-if="!carregandoTemporada && !erroTemporada" class="secao">

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

        :disabled="semanaAtual === 1"

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

        :disabled="semanaAtual === 8"

      >

        →

      </button>

    </div>

<NovaTemporada

  v-if="mostrarNovaTemporada"

  @temporada-criada="mostrarNovaTemporada = false; carregarTemporadaAtiva()"

/>



  </div>

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

  :class="{ 'coluna-destaque': diaEmDestaque === dia.nome }"

  @dragover.prevent="diaEmDestaque = dia.nome"

  @dragleave.self="diaEmDestaque = null"

  @drop.prevent="soltarAtividade(dia.nome); diaEmDestaque = null"

>

      <div

        v-for="atividade in atividades.filter(

          a => a.dia === dia.nome && !a.concluida

        )"

        :key="atividade.id"

        class="cartao"

        draggable="true"

        @dragstart="iniciarArraste(atividade.id)"

        @dragend="atividadeArrastada = null"

        @click="concluir(atividade.id)"

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

          class="botao-excluir"

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

      </section>



      <section class="done">

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

            @click="desfazer(atividade.id)"

          >

            <span class="cartao-icone">

              {{ atividade.icone }}

            </span>

            <span>{{ atividade.nome }}</span>

            <span class="done-remover">↩</span>

          </button>



          <p v-if="pontos === 0" class="done-vazio">

            Suas atividades concluídas aparecerão aqui.

          </p>

        </div>

      </section>

    </main>

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

</style>
