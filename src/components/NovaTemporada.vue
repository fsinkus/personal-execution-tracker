
<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

const emit = defineEmits<{
  (e: 'temporadaCriada'): void
}>()

const nome = ref('')
const objetivos = ref('')
const atividadesPlanejadas = ref('')
const prioridade = ref('')
const criteriosSucesso = ref('')

const dataInicio = ref(
  new Date().toLocaleDateString('en-CA')
)

const carregando = ref(false)
const mensagem = ref('')
const sucesso = ref(false)

async function iniciarTemporada() {
  mensagem.value = ''
  sucesso.value = false

  if (!nome.value.trim()) {
    mensagem.value = 'Informe o nome da temporada.'
    return
  }

  if (!dataInicio.value) {
    mensagem.value = 'Informe a data de início.'
    return
  }

  carregando.value = true

  try {
    const { data: usuario, error: erroUsuario } =
      await supabase.auth.getUser()

    if (erroUsuario || !usuario.user) {
      throw new Error('Sua sessão expirou. Entre novamente.')
    }

    const { error } = await supabase.rpc('criar_temporada', {
      p_nome: nome.value.trim(),
      p_data_inicio: dataInicio.value,
      p_objetivos: objetivos.value.trim(),
      p_atividades_planejadas: atividadesPlanejadas.value.trim(),
      p_prioridade: prioridade.value.trim(),
      p_criterios_sucesso: criteriosSucesso.value.trim()
    })

    if (error) {
      throw error
    }

    sucesso.value = true
    mensagem.value = 'Temporada criada com sucesso!'

    emit('temporadaCriada')
  } catch (erro) {
    console.error('Erro ao criar temporada:', erro)

    mensagem.value =
      erro instanceof Error
        ? erro.message
        : 'Não foi possível criar a temporada.'
  } finally {
    carregando.value = false
  }
}
</script>

<template>
  <section class="pagina-temporada">
    <form
      class="cartao-temporada"
      @submit.prevent="iniciarTemporada"
    >
      <span class="etiqueta">NOVO CICLO DE EXECUÇÃO</span>

      <h1>Iniciar temporada</h1>

      <p class="descricao">
        Defina o que merece sua atenção nas próximas oito semanas.
      </p>

      <label for="nome">Nome da temporada</label>
      <input
        id="nome"
        v-model="nome"
        type="text"
        required
        placeholder="Ex.: Consolidação e consistência"
      />

      <label for="inicio">Data de início</label>
      <input
        id="inicio"
        v-model="dataInicio"
        type="date"
        required
      />

      <label for="objetivos">Objetivos principais</label>
      <textarea
        id="objetivos"
        v-model="objetivos"
        rows="3"
        placeholder="O que você pretende alcançar?"
      ></textarea>

      <label for="atividades">Atividades e compromissos</label>
      <textarea
        id="atividades"
        v-model="atividadesPlanejadas"
        rows="3"
        placeholder="Ex.: Inglês, academia, programação..."
      ></textarea>

      <label for="prioridade">Principal prioridade</label>
      <input
        id="prioridade"
        v-model="prioridade"
        type="text"
        placeholder="O que não pode ficar em segundo plano?"
      />

      <label for="criterios">Critérios de sucesso</label>
      <textarea
        id="criterios"
        v-model="criteriosSucesso"
        rows="2"
        placeholder="Como saberá que a temporada deu certo?"
      ></textarea>

      <p
        v-if="mensagem"
        class="mensagem"
        :class="{ 'mensagem-sucesso': sucesso }"
      >
        {{ mensagem }}
      </p>

      <button
        type="submit"
        :disabled="carregando || sucesso"
      >
        {{
          carregando
            ? 'Criando temporada...'
            : sucesso
              ? 'Temporada criada'
              : 'Iniciar temporada'
        }}
      </button>
    </form>
  </section>
</template>

<style scoped>
.pagina-temporada {
  display: grid;
  place-items: center;
  padding: 24px 20px;
  margin: 20px 0;
  background: #f4f7fc;
  border-radius: 16px;
}

.cartao-temporada {
  width: 100%;
  max-width: 560px;
  padding: 30px;
  background: #ffffff;
  border: 1px solid #e3eaf5;
  border-radius: 18px;
  box-shadow: 0 8px 28px rgba(25, 50, 90, 0.05);
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.etiqueta {
  color: #2563eb;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1px;
}

h1 {
  margin: 0;
  color: #172b4d;
  font-size: 26px;
}

.descricao {
  margin: 0 0 12px;
  color: #718096;
  font-size: 14px;
  line-height: 1.6;
}

label {
  margin-top: 8px;
  color: #334155;
  font-size: 13px;
  font-weight: 600;
}

input,
textarea {
  width: 100%;
  box-sizing: border-box;
  padding: 12px 14px;
  border: 1px solid #dce4ef;
  border-radius: 9px;
  background: #ffffff;
  color: #172b4d;
  font: inherit;
  font-size: 14px;
}

input:focus,
textarea:focus {
  outline: none;
  border-color: #2563eb;
}

textarea {
  resize: vertical;
}

button {
  margin-top: 16px;
  padding: 13px 20px;
  background: #2563eb;
  border: none;
  border-radius: 9px;
  color: white;
  font-size: 14px;
  font-weight: 700;
  cursor: pointer;
}

button:hover:not(:disabled) {
  background: #1d4ed8;
}

button:disabled {
  opacity: 0.65;
  cursor: not-allowed;
}

.mensagem {
  color: #b45309;
  font-size: 13px;
}

.mensagem-sucesso {
  color: #15803d;
}
</style>
