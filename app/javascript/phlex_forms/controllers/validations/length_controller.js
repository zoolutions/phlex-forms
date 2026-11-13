import { FieldValidatorController } from "phlex_forms/controllers/validations/base_controller"
import { interpolate } from "phlex_forms/i18n"

// Mirrors ActiveModel::Validations::LengthValidator. Reads:
//   - maximum / minimum / is
//   - recommended (advisory: the counter's target, never an error)
//   - too-long / too-short / wrong-length messages (win over `message`)
//   - allow-blank / allow-nil
//
// Counter is rendered next to the input when `maximum` or `recommended`
// is set, so the user gets a live "12 / 60" indicator without having to
// wait for blur. Past `recommended` it counts against `maximum` and turns
// `text-warning`; past `maximum` it turns `text-error`.
export default class extends FieldValidatorController {
  // Stimulus walks the prototype chain to accumulate `static values`
  // and `static targets`, so we only declare the validator-specific
  // ones here. `counter` is opt-in: callers that pre-render
  // `<span data-validations--length-target="counter">` get a
  // stable slot the controller updates. Inputs without an explicit
  // target still get a lazily-injected one (see counterElement).
  static targets = ["counter"]
  static values = {
    maximum: Number,
    minimum: Number,
    is: Number,
    recommended: Number,
    tooLongMessage: String,
    tooShortMessage: String,
    wrongLengthMessage: String,
  }

  connect() {
    super.connect()
    if (this.counts) {
      this.renderCounter()
      this.element.addEventListener("input", this.updateCounter)
    }
  }

  disconnect() {
    super.disconnect()
    if (this.counts) {
      this.element.removeEventListener("input", this.updateCounter)
    }
  }

  get counts() {
    return this.hasMaximumValue || this.recommendedLength(null) !== null
  }

  check(value) {
    const length = this.codepointLength(value)

    if (this.hasIsValue && length !== this.isValue) {
      return this.lengthMessage(this.wrongLengthMessageValue, "wrong_length", this.isValue)
    }
    if (this.hasMaximumValue && length > this.maximumValue) {
      return this.lengthMessage(this.tooLongMessageValue, "too_long", this.maximumValue)
    }
    if (this.hasMinimumValue && length < this.minimumValue) {
      return this.lengthMessage(this.tooShortMessageValue, "too_short", this.minimumValue)
    }
    return null
  }

  // A per-case message (`too_long:` & co.) wins over `message:`, as on the
  // server; the bundled translation is the final fallback.
  lengthMessage(caseMessage, key, count) {
    if (caseMessage) return interpolate(caseMessage, { value: this.fieldValue(), count })
    return this.messageOr(`js.forms.validations.length.${key}`, { count })
  }

  updateCounter = () => {
    const counter = this.counterElement()
    if (!counter) return
    const length = this.codepointLength(this.element.value)
    const { limit, state, advisory } = this.counterState(length)
    counter.textContent = `${length} / ${limit}`
    // Without a recommended length the counter is exactly 0.5.0's: a caller's
    // own `text-warning` on a pre-rendered counter target is left alone.
    if (advisory) counter.classList.toggle("text-warning", state === "warning")
    counter.classList.toggle("text-error", state === "error")
  }

  // The counter's denominator and state. `recommended` applies only below
  // `maximum` (the server drops it otherwise; this guards a hand-written
  // attribute): up to it the counter reads "n / recommended", past it
  // "n / maximum" in a warning colour, past `maximum` an error.
  counterState(length) {
    const maximum = this.hasMaximumValue ? this.maximumValue : null
    const recommended = this.recommendedLength(maximum)

    const advisory = recommended !== null

    if (maximum !== null && length > maximum) return { limit: maximum, state: "error", advisory }
    if (!advisory) return { limit: maximum, state: null, advisory }
    if (length <= recommended) return { limit: recommended, state: null, advisory }
    return { limit: maximum ?? recommended, state: "warning", advisory }
  }

  recommendedLength(maximum) {
    if (!this.hasRecommendedValue) return null
    const recommended = this.recommendedValue
    if (!(recommended > 0) || (maximum !== null && recommended >= maximum)) return null
    return recommended
  }

  // Ruby's String#length counts Unicode codepoints; JS's String#length
  // counts UTF-16 code units, so an emoji like 👍 reads as 2 in JS but
  // 1 in Ruby. Matching Rails here avoids the client falsely rejecting
  // a string the server would accept.
  codepointLength(value) {
    return Array.from(String(value ?? "")).length
  }

  renderCounter() {
    const counter = this.counterElement({ create: true })
    this.updateCounter()
    return counter
  }

  counterElement({ create = false } = {}) {
    // Caller pre-rendered a Stimulus target — preferred path.
    if (this.hasCounterTarget) return this.counterTarget

    // Fallback: cache-by-id lookup or lazy injection for plain forms.
    const id = this.element.id || this.element.name
    const selector = `[data-validations--counter="${id}"]`
    const existing = this.element.closest("form")?.querySelector(selector)
    if (existing) return existing
    if (!create) return null

    const counter = document.createElement("span")
    counter.className = "text-xs text-base-content/60 ml-auto"
    // `dataset` rejects keys containing `--`; use the raw attribute API.
    counter.setAttribute("data-validations--counter", id)
    this.element.insertAdjacentElement("afterend", counter)
    return counter
  }
}
