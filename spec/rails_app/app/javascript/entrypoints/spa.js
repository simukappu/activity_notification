import { createApp } from 'vue'
import App from '../App.vue'
import router from '../router'
import store from '../store'
import ActionCable from '../plugins/action-cable'
import env from '../config/environment'

document.addEventListener('DOMContentLoaded', () => {
  createApp(App)
    .use(router)
    .use(store)
    .use(ActionCable, { connectionUrl: env.ACTION_CABLE_CONNECTION_URL })
    .mount('#spa')
})
