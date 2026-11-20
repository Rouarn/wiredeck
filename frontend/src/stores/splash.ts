import { ref } from 'vue'
import { defineStore } from 'pinia'

const STORAGE_KEY = 'wiredeck.skipSplash'

export const useSplashStore = defineStore('splash', () => {
  const skip = ref(localStorage.getItem(STORAGE_KEY) === '1')

  function setSkip(next: boolean) {
    skip.value = next
    localStorage.setItem(STORAGE_KEY, next ? '1' : '0')
  }

  return { skip, setSkip }
})
