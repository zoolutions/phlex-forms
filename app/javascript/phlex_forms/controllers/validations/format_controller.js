import { FieldValidatorController } from "phlex_forms/controllers/validations/base_controller"

// Mirrors ActiveModel::Validations::FormatValidator.
export default class extends FieldValidatorController {
  static values = {
    pattern: String,
    flags: { type: String, default: "" },
  }

  check(value) {
    if (!this.hasPatternValue) return null
    try {
      const regex = new RegExp(this.patternValue, this.flagsValue)
      return regex.test(String(value ?? "")) ? null : this.messageOr("js.forms.validations.format.invalid")
    } catch (_e) {
      // If Rails' regex doesn't translate cleanly to JS, fall back to
      // letting the server be the authority — don't block submit on a
      // pattern we can't evaluate.
      return null
    }
  }
}
