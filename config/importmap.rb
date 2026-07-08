# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@vitable-inc/drops/react", to: "@vitable-inc--drops--react.js" # @0.1.5
pin "react" # @19.2.7
pin "react-dom" # @19.2.7
pin "react/jsx-runtime", to: "react--jsx-runtime.js" # @19.2.7
pin "react-dom/client", to: "react-dom--client.js" # @19.2.7
pin "scheduler" # @0.27.0
pin "@vitable-inc/drops/core", to: "@vitable-inc--drops--core.js" # @0.1.5
