
<script setup lang="ts">
import { ref } from 'vue'
import { supabase } from '../lib/supabase'

const email = ref('')
const senha = ref('')
const mensagem = ref('')
const carregando = ref(false)

async function entrar() {
  mensagem.value = ''
  carregando.value = true

  try {
    const { error } = await supabase.auth.signInWithPassword({
      email: email.value.trim(),
      password: senha.value
    })

    if (error) throw error
  } catch (erro) {
    mensagem.value =
      erro instanceof Error ? erro.message : 'Erro ao entrar.'
  } finally {
    carregando.value = false
  }
}

async function cadastrar() {
  mensagem.value = ''
  carregando.value = true

  try {
    const { error } = await supabase.auth.signUp({
      email: email.value.trim(),
      password: senha.value
    })

    if (error) throw error

    mensagem.value =
      'Cadastro solicitado! Verifique seu e-mail para confirmar a conta.'
  } catch (erro) {
    mensagem.value =
      erro instanceof Error ? erro.message : 'Erro ao cadastrar.'
  } finally {
    carregando.value = false
  }
}
</script>

<template>
  <main class="pagina-login">
    <form class="cartao-login" @submit.prevent="entrar">
      <div class="simbolo">✦</div>

      <h1>Personal Execution Tracker</h1>
      <p>Entre para acompanhar sua evolução.</p>

      <label for="email">E-mail</label>
      <input
        id="email"
        v-model="email"
        type="email"
        autocomplete="email"
        required
        placeholder="seu@email.com"
      />

      <label for="senha">Senha</label>
      <input
        id="senha"
        v-model="senha"
        type="password"
        autocomplete="current-password"
        minlength="6"
        required
        placeholder="Sua senha"
      />

      <button type="submit" :disabled="carregando">
        {{ carregando ? 'Aguarde...' : 'Entrar' }}
      </button>

      <button
        type="button"
        class="botao-cadastro"
        :disabled="carregando"
        @click="cadastrar"
      >
        Criar minha conta
      </button>

      <p v-if="mensagem" class="mensagem">{{ mensagem }}</p>
    </form>
  </main>
</template>

<style scoped>
.pagina-login {
  min-height: 100vh;
  display: grid;
  place-items: center;
  background: #f4f7fc;
  padding: 24px;
}

.cartao-login {
  width: 100%;
  max-width: 390px;
  padding: 36px;
  background: white;
  border: 1px solid #e2e8f0;
  border-radius: 18px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.simbolo {
  color: #2563eb;
  font-size: 32px;
}

h1 {
  margin: 0;
  color: #1e293b;
  font-size: 23px;
}

p {
  margin: 0 0 12px;
  color: #64748b;
  font-size: 14px;
}

label {
  font-size: 13px;
  font-weight: 600;
  color: #334155;
}

input {
  padding: 12px;
  border: 1px solid #cbd5e1;
  border-radius: 9px;
  font: inherit;
}

button {
  margin-top: 10px;
  padding: 12px;
  border: 0;
  border-radius: 9px;
  background: #2563eb;
  color: white;
  font-weight: 700;
  cursor: pointer;
}

button:disabled {
  opacity: 0.6;
  cursor: wait;
}

.botao-cadastro {
  margin-top: 0;
  background: #eaf1ff;
  color: #2563eb;
}

.mensagem {
  margin: 8px 0 0;
  font-size: 13px;
  line-height: 1.5;
}
</style>
