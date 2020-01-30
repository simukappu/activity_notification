<template>
  <div>
    <router-view />
  </div>
</template>

<script>
import Vue from 'vue'
import VueRouter from 'vue-router'
import VueMoment from 'vue-moment'
import moment from 'moment-timezone'
import VuePluralize from 'vue-pluralize'
import ActionCableVue from 'actioncable-vue'
import axios from 'axios'
import env from './config/environment'
import authStore from "./store/auth"
import Top from './components/Top.vue'
import DeviseTokenAuth from './components/DeviseTokenAuth.vue'
import NotificationsIndex from './components/notifications/Index.vue'
import SubscriptionsIndex from './components/subscriptions/Index.vue'

const router = new VueRouter({
  routes: [
    { path: '/', component: Top },
    { path: '/login', component: DeviseTokenAuth },
    { path: '/logout', component: DeviseTokenAuth, props: { isLogout: true } },
    // Routes for single page application working with activity_notification REST API backend for users
    {
      path: '/notifications',
      name: 'AuthenticatedUserNotificationsIndex',
      component: NotificationsIndex,
      props: () => ({ target_type: 'users', target: authStore.getters.currentUser }),
      meta: { requiresAuth: true }
    },
    {
      path: '/subscriptions',
      name: 'AuthenticatedUserSubscriptionsIndex',
      component: SubscriptionsIndex,
      props: () => ({ target_type: 'users', target: authStore.getters.currentUser }),
      meta: { requiresAuth: true }
    },
    // Routes for single page application working with activity_notification REST API backend for admins
    {
      path: '/admins/notifications',
      name: 'AuthenticatedAdminNotificationsIndex',
      component: NotificationsIndex,
      props: () => ({ target_type: 'admins', targetApiPath: 'admins', target: authStore.getters.currentUser.admin }),
      meta: { requiresAuth: true }
    },
    {
      path: '/admins/subscriptions',
      name: 'AuthenticatedAdminSubscriptionsIndex',
      component: SubscriptionsIndex,
      props: () => ({ target_type: 'admins', targetApiPath: 'admins', target: authStore.getters.currentUser.admin }),
      meta: { requiresAuth: true }
    },
    // Routes for single page application working with activity_notification REST API backend for unauthenticated targets
    {
      path: '/:target_type/:target_id/notifications',
      name: 'UnauthenticatedTargetNotificationsIndex',
      component: NotificationsIndex,
      props : true
    },
    {
      path: '/:target_type/:target_id/subscriptions',
      name: 'UnauthenticatedTargetSubscriptionsIndex',
      component: SubscriptionsIndex,
      props : true
    }
  ]
})

router.beforeEach((to, from, next) => {
  if (to.matched.some(record => record.meta.requiresAuth) && !authStore.getters.userSignedIn) {
      next({ path: '/login', query: { redirect: to.fullPath }});
  } else {
    next();
  }
})

if (authStore.getters.userSignedIn) {
  for (var authHeader of Object.keys(authStore.getters.authHeaders)) {
    axios.defaults.headers.common[authHeader] = authStore.getters.authHeaders[authHeader];
  }
}

Vue.use(VueRouter)
Vue.use(VueMoment, { moment })
Vue.use(VuePluralize)
Vue.use(ActionCableVue, {
  debug: true,
  debugLevel: 'error',
  connectionUrl: env.ACTION_CABLE_CONNECTION_URL,
  connectImmediately: true
})

export default {
  name: 'App',
  router
}
</script>

<style scoped>
</style>