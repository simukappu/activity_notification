<template>
  <div>
    <router-view />
  </div>
</template>

<script>
import axios from 'axios'

axios.defaults.baseURL = "/api/v2"

export default {
  name: 'App',
  mounted () {
    if (this.$store.getters.userSignedIn) {
      for (var authHeader of Object.keys(this.$store.getters.authHeaders)) {
        axios.defaults.headers.common[authHeader] = this.$store.getters.authHeaders[authHeader];
      }
    }
  }
}
</script>

<style scoped>
</style>