<script setup lang="ts">
import { computed, onMounted, onUnmounted } from 'vue'

type Tipo = 'semana' | 'temporada' | 'inicio'
const props = defineProps<{ tipo: Tipo; titulo?: string }>()
const emit = defineEmits<{ (e: 'terminou'): void }>()
const confetes = Array.from({ length: 64 }, (_, i) => ({
  id: i,
  x: `${(i * 47.13) % 100}%`,
  atraso: `${(i * 0.071) % 1.2}s`,
  duracao: `${2.1 + (i % 7) * 0.22}s`,
  cor: ['#2563eb', '#22c55e', '#f59e0b', '#e879f9', '#06b6d4'][i % 5],
  rotacao: `${(i * 73) % 360}deg`
}))
const fogos = Array.from({ length: 5 }, (_, i) => ({
  id: i,
  x: `${18 + i * 16}%`,
  y: `${20 + (i % 3) * 13}%`,
  atraso: `${i * 0.38}s`
}))
const tituloExibido = computed(() => props.titulo || ({
  semana: 'Semana concluída!',
  temporada: 'Temporada concluída!',
  inicio: 'Nova temporada iniciada!'
} as Record<Tipo, string>)[props.tipo])
let temporizador: ReturnType<typeof setTimeout> | undefined
// Efeitos sonoros sintetizados, sem dependências nem arquivos externos.
function tocarCelebracao() {
  try {
    const ContextoAudio = window.AudioContext
    if (!ContextoAudio) return
    const audio = new ContextoAudio()
    void audio.resume().catch(() => {})
    const agora = audio.currentTime + 0.04

    function nota(frequencia: number, quando: number, duracao: number, volumeMax = 0.045, onda: OscillatorType = 'sine') {
      const oscilador = audio.createOscillator()
      const ganho = audio.createGain()
      oscilador.type = onda
      oscilador.frequency.setValueAtTime(frequencia, quando)
      ganho.gain.setValueAtTime(0.0001, quando)
      ganho.gain.exponentialRampToValueAtTime(volumeMax, quando + 0.025)
      ganho.gain.exponentialRampToValueAtTime(0.0001, quando + duracao)
      oscilador.connect(ganho)
      ganho.connect(audio.destination)
      oscilador.start(quando)
      oscilador.stop(quando + duracao + 0.01)
    }

    function confete(quando: number) {
      // Pequeno acorde alegre com brilhos agudos, em volume discreto.
      ;[523.25, 659.25, 783.99, 1046.5].forEach((freq, i) => {
        nota(freq, quando + i * 0.105, 0.36, 0.035)
      })
      ;[1174.66, 1318.51, 1567.98].forEach((freq, i) => {
        nota(freq, quando + 0.55 + i * 0.12, 0.19, 0.014, 'triangle')
      })
    }

    // Apenas o efeito agudo e alegre, sem o ruído grave do foguete.
    confete(agora)
    setTimeout(() => { void audio.close().catch(() => {}) }, 3200)
  } catch (erro) {
    console.debug('Som da celebração indisponível:', erro)
  }
}
onMounted(() => {
  tocarCelebracao()
  temporizador = setTimeout(() => emit('terminou'), 3600)
})
onUnmounted(() => { if (temporizador) clearTimeout(temporizador) })
</script>

<template>
  <div class="celebracao" role="status" aria-live="polite">
    <div v-if="tipo !== 'inicio'" class="particulas" aria-hidden="true">
      <span
        v-for="item in confetes"
        :key="item.id"
        class="confete"
        :style="{
          left: item.x,
          backgroundColor: item.cor,
          animationDelay: item.atraso,
          animationDuration: item.duracao,
          transform: `rotate(${item.rotacao})`
        }"
      />
    </div>

    <div v-if="tipo === 'temporada'" class="fogos" aria-hidden="true">
      <div
        v-for="fogo in fogos"
        :key="fogo.id"
        class="fogo"
        :style="{ left: fogo.x, top: fogo.y, animationDelay: fogo.atraso }"
      >
        <i v-for="raio in 12" :key="raio" :style="{ '--angulo': `${raio * 30}deg` }" />
      </div>
    </div>

    <div v-if="tipo === 'inicio'" class="foguete" aria-hidden="true">
      <span class="rastro" />
      <span class="nave">🚀</span>
    </div>

    <div class="mensagem">
      <span class="simbolo">{{ tipo === 'inicio' ? '🚀' : tipo === 'semana' ? '🎉' : '🏆' }}</span>
      <strong>{{ tituloExibido }}</strong>
      <span>{{ tipo === 'inicio' ? 'Hora de executar!' : 'Seu progresso foi registrado.' }}</span>
    </div>
  </div>
</template>

<style scoped>
.celebracao {
  position: fixed;
  inset: 0;
  z-index: 9999;
  overflow: hidden;
  pointer-events: none;
  display: grid;
  place-items: center;
  background: rgba(11, 26, 55, .16);
  animation: fundo 3.6s both;
}
.mensagem {
  z-index: 2;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  padding: 28px 40px;
  border-radius: 20px;
  background: rgba(255,255,255,.96);
  box-shadow: 0 18px 65px rgba(20,39,75,.18);
  color: #17233b;
  text-align: center;
  animation: surgir 3.6s both;
}
.simbolo { font-size: 38px; }
.mensagem strong { font-size: clamp(20px, 3vw, 30px); }
.mensagem > span:last-child { font-size: 14px; color: #64748b; }
.confete {
  position: absolute;
  top: -12%;
  width: 9px;
  height: 16px;
  border-radius: 2px;
  opacity: 0;
  animation-name: cair;
  animation-timing-function: ease-in;
  animation-fill-mode: both;
}
.fogo {
  position: absolute;
  width: 10px;
  height: 10px;
  animation: brilho 1.1s ease-out both;
}
.fogo i {
  position: absolute;
  left: 5px;
  top: 5px;
  width: 4px;
  height: 34px;
  border-radius: 5px;
  background: linear-gradient(#fbbf24, #60a5fa, transparent);
  transform-origin: 2px 0;
  transform: rotate(var(--angulo));
}
.foguete {
  position: absolute;
  left: 50%;
  bottom: -140px;
  display: flex;
  align-items: center;
  flex-direction: column;
  animation: decolar 3.1s ease-in both;
}
.nave { font-size: 68px; transform: rotate(-45deg); }
.rastro {
  position: absolute;
  top: 65px;
  width: 22px;
  height: 160px;
  border-radius: 100%;
  background: linear-gradient(#fbbf24, #fb923c, transparent);
  filter: blur(7px);
}
@keyframes cair {
  0% { opacity: 0; translate: 0 -20px; rotate: 0deg; }
  8% { opacity: 1; }
  100% { opacity: 0; translate: 70px 115vh; rotate: 700deg; }
}
@keyframes brilho {
  0% { opacity: 0; scale: .1; }
  35% { opacity: 1; scale: 1.4; }
  100% { opacity: 0; scale: 2.5; }
}
@keyframes decolar {
  0% { translate: 0 0; opacity: 0; }
  12% { opacity: 1; }
  100% { translate: 0 -125vh; opacity: 0; }
}
@keyframes surgir {
  0%, 8% { opacity: 0; scale: .85; }
  18%, 75% { opacity: 1; scale: 1; }
  100% { opacity: 0; scale: 1.05; }
}
@keyframes fundo {
  0%, 80% { opacity: 1; }
  100% { opacity: 0; }
}
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation: none !important; }
  .celebracao { background: transparent; }
  .particulas, .fogos, .foguete { display: none; }
}
</style>
