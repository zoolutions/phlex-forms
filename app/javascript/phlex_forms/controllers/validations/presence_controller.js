import { FieldValidatorController } from "phlex_forms/controllers/validations/base_controller"

// Mirrors ActiveModel::Validations::PresenceValidator.
export default class extends FieldValidatorController {
  static values = {
    required: { type: Boolean, default: true },
  }

  check(value) {
    if (!this.requiredValue) return null
    return this.isBlank(value) ? this.messageOr("js.forms.validations.presence.blank") : null
  }
}
