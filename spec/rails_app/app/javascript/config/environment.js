// Environment specific configuration for the sample single page application.
// import.meta.env.MODE is set by vite_ruby from the Rails environment (development, test or production).
const configs = {
  development: {
    ACTION_CABLE_CONNECTION_URL: 'ws://localhost:3000/cable'
  },
  test: {
    ACTION_CABLE_CONNECTION_URL: 'ws://localhost:3000/cable'
  },
  production: {
    ACTION_CABLE_CONNECTION_URL: 'wss://activity-notification-example.herokuapp.com/cable'
  }
}

const config = configs[import.meta.env.MODE] || configs.development

export default class Environment {
  static get ACTION_CABLE_CONNECTION_URL() {
    return config.ACTION_CABLE_CONNECTION_URL;
  }
}
