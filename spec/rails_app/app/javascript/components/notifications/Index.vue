<template>
  <div class="notification_wrapper">
    <div class="notification_header">
      <h1>
        Notifications to {{ currentTarget.printable_target_name }}
        <a href="#" v-on:click="openAll()" data-remote="true">
          <span class="notification_count"><span v-bind:class="[unopenedNotificationCount > 0 ? 'unopened' : '']">
            {{ unopenedNotificationCount }}
          </span></span>
        </a>
      </h1>
      <h3>
        <span class="action_cable_status">Disabled</span>
      </h3>
    </div>
    <div class="notifications">
      <div v-for="notification in notifications" :key="`${notification.id}_${notification.opened_at}`">
        <notification :targetNotification="notification" :targetApiPath="targetApiPath" @getUnopenedNotificationCount="getUnopenedNotificationCount" />
      </div>
    </div>
  </div>
</template>

<script>
import axios from 'axios'
import Notification from './Notification.vue'

export default {
  name: 'NotificationsIndex',
  components: {
    Notification
  },
  props: {
    target_type: {
      type: String
    },
    target_id: {
      type: [String, Number]
    },
    targetApiPath: {
      type: String,
      default: function () { 
        if (this.target_type && this.target_id) {
          return '/' + this.target_type + '/' + this.target_id;
        } else {
          return '';
        }
      }
    },
    target: {
      type: Object
    }
  },
  data () {
    return {
      currentTarget: { printable_target_name: '' },
      unopenedNotificationCount: 0,
      notifications: []
    }
  },
  mounted () {
    if (this.target) {
      this.currentTarget = this.target;
    } else {
      this.getCurrentTarget();
    }
    this.getNotifications();
    this.getUnopenedNotificationCount();
  },
  methods: {
    getCurrentTarget () {
      axios
        .get(this.targetApiPath)
        .then(response => (this.currentTarget = response.data))
    },
    getNotifications () {
      axios
        .get(this.targetApiPath + '/notifications', { params: this.$route.query })
        .then(response => (this.notifications = response.data.notifications))
        .catch (error => {
          if (error.response.status == 401) {
            this.$router.push('/logout');
          }
        })
    },
    getUnopenedNotificationCount () {
      if (this.$route.query.filter == 'opened') {
        this.unopenedNotificationCount = 0;
      } else {
        axios
          .get(this.targetApiPath + '/notifications', { params: Object.assign({ filter: 'unopened' }, this.$route.query) })
          .then(response => (this.unopenedNotificationCount = response.data.count))
          .catch (error => {
            if (error.response.status == 401) {
              this.$router.push('/logout');
            }
          })
      }
    },
    openAll () {
      axios
        .post(this.targetApiPath + '/notifications/open_all')
        .then(response => {
          if (response.status == 200) {
            this.getNotifications();
            this.getUnopenedNotificationCount();
          }
        })
    }
  }
}
</script>

<style scoped>
.notification_wrapper .notification_header h1 span span{
  color: #fff;
  background-color: #e5e5e5;
  border-radius: 4px;
  font-size: 12px;
  padding: 4px 8px;
}
.notification_wrapper .notification_header h1 span span.unopened{
  background-color: #f87880;
}
</style>