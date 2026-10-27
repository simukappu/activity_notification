// Minimal Vuex plugin to persist the store state into Web Storage (sessionStorage by default).
export default function createPersistedState ({ key = 'vuex', storage = window.sessionStorage } = {}) {
  return (store) => {
    try {
      const savedState = JSON.parse(storage.getItem(key))
      if (savedState) {
        store.replaceState(Object.assign({}, store.state, savedState))
      }
    } catch (e) {
      storage.removeItem(key)
    }
    store.subscribe((mutation, state) => {
      storage.setItem(key, JSON.stringify(state))
    })
  }
}
