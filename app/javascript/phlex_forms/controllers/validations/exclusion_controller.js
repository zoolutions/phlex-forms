import { FieldValidatorController } from "phlex_forms/controllers/validations/base_controller"

// Mirrors ActiveModel::Validations::ExclusionValidator.
export default class extends FieldValidatorController {
  static values = {
    in: String,
  }

  check(value) {
    if (!this.hasInValue) return null
    try {
      const list = JSON.parse(this.inValue)
      return list.map(String).includes(String(value ?? "")) ? this.messageOr("js.forms.validations.exclusion.exclusion") : null
    } catch (_e) {
      return null
    }
  }
}
