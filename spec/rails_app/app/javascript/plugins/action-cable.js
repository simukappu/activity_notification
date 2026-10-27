// Minimal Vue 3 plugin for Action Cable using @rails/actioncable.
// Components define channel callbacks in a `channels` option and subscribe with `this.$cable.subscribe(params)`.
// Callbacks are called with the component as `this`, and subscriptions are removed when the component is unmounted.
import { createConsumer } from '@rails/actioncable'

const CALLBACKS = ['connected', 'disconnected', 'rejected', 'received']

export default {
  install (app, { connectionUrl } = {}) {
    let consumer = null
    const getConsumer = () => (consumer ||= createConsumer(connectionUrl))

    app.mixin({
      beforeCreate () {
        const channels = this.$options.channels
        if (!channels) return
        const subscriptions = {}
        this.$cable = {
          subscribe: (params) => {
            const channelName = typeof params === 'string' ? params : params.channel
            const callbacks = channels[channelName] || {}
            const mixin = {}
            for (const callback of CALLBACKS) {
              if (callbacks[callback]) {
                mixin[callback] = (...args) => callbacks[callback].apply(this, args)
              }
            }
            if (subscriptions[channelName]) subscriptions[channelName].unsubscribe()
            subscriptions[channelName] = getConsumer().subscriptions.create(params, mixin)
            return subscriptions[channelName]
          },
          unsubscribe: (channelName) => {
            if (subscriptions[channelName]) {
              subscriptions[channelName].unsubscribe()
              delete subscriptions[channelName]
            }
          }
        }
        this._actionCableSubscriptions = subscriptions
      },
      beforeUnmount () {
        if (!this._actionCableSubscriptions) return
        for (const channelName of Object.keys(this._actionCableSubscriptions)) {
          this.$cable.unsubscribe(channelName)
        }
      }
    })
  }
}
