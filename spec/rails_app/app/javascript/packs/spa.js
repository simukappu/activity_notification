import Vue from 'vue'
import axios from 'axios'
import App from '../App.vue'

axios.defaults.baseURL = "/api/v2"

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    render: h => h(App)
  }).$mount('#spa')
})
