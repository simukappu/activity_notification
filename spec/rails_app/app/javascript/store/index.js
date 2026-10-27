import { createStore } from 'vuex'
import createPersistedState from '../plugins/persisted-state'

export default createStore({
  state: {
    signedInStatus: false,
    currentUser: null,
    authHeaders: {}
  },
  mutations: {
    signIn(state, { user, authHeaders }) {
      state.currentUser = user;
      state.authHeaders = authHeaders;
      state.signedInStatus = true;
    },
    signOut(state) {
      state.signedInStatus = false;
      state.currentUser = null;
      state.authHeaders = {};
    }
  },
  getters: {
    userSignedIn(state) {
      return state.signedInStatus;
    },
    currentUser(state) {
      return state.currentUser;
    },
    authHeaders(state) {
      return state.authHeaders;
    }
  },
  plugins: [createPersistedState({ storage: window.sessionStorage })]
});
