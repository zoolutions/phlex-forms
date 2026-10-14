import { FieldValidatorController } from "phlex_forms/controllers/validations/base_controller"

// Mirrors ActiveModel::Validations::AcceptanceValidator. For
// checkboxes, asserts `.checked`. For other inputs, asserts the
// value is in the accepted list.
export default class extends FieldValidatorController {
  static values = {
    accept: { type: String, default: '["1","true"]' },
  }

  check(value) {
    if (this.element.type === "checkbox") {
      return this.element.checked ? null : this.messageOr("js.forms.validations.acceptance.accepted")
    }
    try {
      const list = JSON.parse(this.acceptValue)
      return list.map(String).includes(String(value ?? "")) ? null : this.messageOr("js.forms.validations.acceptance.accepted")
    } catch (_e) {
      return null
    }
  }
}
