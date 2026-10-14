import { Controller } from "@hotwired/stimulus"
import { interpolate, t } from "phlex_forms/i18n"

// Shared base for every field-level validator. Subclasses implement
// `check(value)` and return either `null` (valid) or a translation
// key / message string (invalid). The base class wires up the DOM
// hooks (blur, validate event), error rendering, and the message
// the form coordinator collects on submit.
//
// Each subclass declares its own `static values` for the rules it
// reads from data attributes; the base class only knows about the
// `allowBlank` / `allowNil` short-circuits and the `message` value,
// which carries the validator's own `message:` option (issue #41).
export class FieldValidatorController extends Controller {
  // `error` is opt-in: callers that pre-render a `<p data-validations--<validator>-target="error">`
  // get a stable slot the controller toggles. Inputs without an
  // explicit target still work — the controller lazily creates one
  // adjacent to the input below.
  static targets = ["error"]
  static values = {
    allowBlank: { type: Boolean, default: false },
    allowNil: { type: Boolean, default: false },
    message: String,
  }

  // Element must be the input itself — these controllers are attached
  // directly to <input>, <textarea>, <select> via the form builder.
  connect() {
    this.element.addEventListener("blur", this.onBlur)
    this.element.addEventListener("invalidate:validations", this.onValidate)
  }

  disconnect() {
    this.element.removeEventListener("blur", this.onBlur)
    this.element.removeEventListener("invalidate:validations", this.onValidate)
  }

  onBlur = () => {
    this.runCheck({ silent: false })
  }

  onValidate = (event) => {
    const result = this.runCheck({ silent: false })
    if (result) {
      event.detail.errors.push({ element: this.element, message: result })
    }
  }

  runCheck({ silent }) {
    const value = this.fieldValue()
    if (this.shouldSkip(value)) {
      this.clearError()
      return null
    }

    const error = this.check(value)
    if (error) {
      if (!silent) this.renderError(error)
      return error
    }
    this.clearError()
    return null
  }

  // Subclasses override.
  check(_value) {
    return null
  }

  // The validator's own `message:` when the server rendered one, else the
  // bundled translation for `key`. Either way `%{count}` & co. are filled in;
  // a custom message may also carry `%{value}`, as on the server.
  messageOr(key, vars = {}) {
    if (!(this.hasMessageValue && this.messageValue)) return t(key, vars)
    return interpolate(this.messageValue, { value: this.element.value, ...vars })
  }

  shouldSkip(value) {
    if (this.allowNilValue && (value === null || value === undefined)) return true
    if (this.allowBlankValue && this.isBlank(value)) return true
    return false
  }

  isBlank(value) {
    if (value === null || value === undefined) return true
    if (typeof value === "string") return value.trim().length === 0
    return false
  }

  fieldValue() {
    if (this.element.type === "checkbox") return this.element.checked
    return this.element.value
  }

  // Stores this validator's error state on the input element and
  // re-renders the consolidated message. Multiple validators share
  // a single container per field but track their errors separately
  // so one validator's "valid" doesn't blow away another's "invalid".
  renderError(message) {
    this.setValidatorError(message)
    this.renderConsolidated()
  }

  clearError() {
    this.setValidatorError(null)
    this.renderConsolidated()
  }

  setValidatorError(message) {
    if (!this.element.__formsValidationErrors) {
      this.element.__formsValidationErrors = {}
    }
    this.element.__formsValidationErrors[this.identifier] = message
  }

  renderConsolidated() {
    const errors = this.element.__formsValidationErrors || {}
    // Stable order so the displayed message doesn't flicker.
    const ordered = Object.keys(errors)
      .sort()
      .map((k) => errors[k])
      .filter(Boolean)
    const message = ordered[0] || null

    const container = this.errorContainer({ create: !!message })
    if (container) {
      container.textContent = message || ""
      container.hidden = !message
    }
    const errorClass = this.errorClassForElement()
    if (message) {
      this.element.setAttribute("aria-invalid", "true")
      this.element.classList.add(errorClass)
    } else {
      this.element.removeAttribute("aria-invalid")
      this.element.classList.remove(errorClass)
    }
  }

  // DaisyUI uses tag-specific error classes (`input-error` vs
  // `textarea-error` vs `select-error`). Adding all three to every
  // element is inert today but invites CSS bleed once the variants
  // diverge — pick the one that matches.
  errorClassForElement() {
    switch (this.element.tagName) {
      case "TEXTAREA":
        return "textarea-error"
      case "SELECT":
        return "select-error"
      default:
        return "input-error"
    }
  }

  errorContainer({ create = true } = {}) {
    // If the caller pre-rendered a Stimulus error target on the same
    // controller, use that — preferred path for server-rendered forms.
    if (this.hasErrorTarget) return this.errorTarget

    // Fallback: lazily create (and cache by element id/name) a slot
    // adjacent to the input. Keeps the framework usable on plain
    // forms that haven't opted into the static-target convention.
    const id = this.element.id || this.element.name
    const selector = `[data-validations--error="${id}"]`
    const existing = this.element.closest("form")?.querySelector(selector)
    if (existing) return existing
    if (!create) return null

    const container = document.createElement("p")
    container.className = "text-error text-sm mt-1"
    // `dataset` rejects keys with `--`, so we set the attribute
    // directly. The CSS selector still matches.
    container.setAttribute("data-validations--error", id)
    this.element.insertAdjacentElement("afterend", container)
    return container
  }
}
