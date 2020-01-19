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
import axios from 'axios'
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
    {
      path: '/notifications',
      name: 'AuthenticatedUserNotificationsIndex',
      component: NotificationsIndex,
      props: () => ({ target: authStore.getters.currentUser }),
      meta: { requiresAuth: true }
    },
    {
      path: '/admins/notifications',
      name: 'AuthenticatedAdminNotificationsIndex',
      component: NotificationsIndex,
      props: () => ({ target: authStore.getters.currentUser.admin, targetApiPath: 'admins' }),
      meta: { requiresAuth: true }
    },
    {
      path: '/:target_type/:target_id/notifications',
      name: 'UnauthenticatedTargetNotificationsIndex',
      component: NotificationsIndex,
      props : true
    },
    {
      path: '/subscriptions',
      name: 'AuthenticatedUserSubscriptionsIndex',
      component: SubscriptionsIndex,
      props: () => ({ target: authStore.getters.currentUser }),
      meta: { requiresAuth: true }
    },
    {
      path: '/admins/subscriptions',
      name: 'AuthenticatedAdminSubscriptionsIndex',
      component: SubscriptionsIndex,
      props: () => ({ target: authStore.getters.currentUser.admin, targetApiPath: 'admins' }),
      meta: { requiresAuth: true }
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

export default {
  name: 'App',
  router
}
</script>

<style scoped>
</style>