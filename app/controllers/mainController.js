const express = require("express")
const router = express.Router()

// Helpers for this controller/router

const render = function (response, view, locals) {
  response.render(["main", view].join("/") + ".html.pug", locals)
}

// Responses

const index = function (request, response) {
  console.log("mainController#index")
  render(response, "index")
}

// Routes

router.get("/", index)

// Exports

module.exports = {
  index: index,
  router: router
}
