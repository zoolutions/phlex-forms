import { FieldValidatorController } from "phlex_forms/controllers/validations/base_controller"

// Mirrors ActiveModel::Validations::ConfirmationValidator. Looks
// for the `<name>_confirmation` field by name within the same form
// and asserts equality.
export default class extends FieldValidatorController {
  static values = {
    match: String,
  }

  check(value) {
    if (!this.hasMatchValue) return null
    const form = this.element.closest("form")
    if (!form) return null
    const partner = form.elements[this.matchValue] || this.partnerByAttribute(form)
    if (!partner) return null
    return String(partner.value) === String(value ?? "") ? null : this.messageOr("js.forms.validations.confirmation.confirmation")
  }

  partnerByAttribute(form) {
    // Rails scopes form fields as `model[name_confirmation]`, so
    // `form.elements[matchValue]` lookup fails for scoped names.
    // Fall back to a `[name$="[<matchValue>]"]` selector.
    return form.querySelector(`[name$="[${this.matchValue}]"]`)
  }
}
