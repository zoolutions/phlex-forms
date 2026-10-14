// Minimal, self-contained i18n for phlex-forms' client-side validation
// messages. Bundles the validation strings for every shipped locale so the
// gem needs no host i18n runtime. Host apps can override a message by defining
// window.PhlexForms.messages[locale] before the controllers connect.
//
// Locale is read from <html lang> (falling back to a <meta name="locale">, then
// "en"), matching the convention Rails apps already set.

import { messages } from "phlex_forms/messages"

function detectLocale() {
  if (typeof document === "undefined") return "en"
  const htmlLang = document.documentElement.lang
  if (htmlLang) return htmlLang.split("-")[0]
  const meta = document.querySelector('meta[name="locale"]')?.content
  return meta ? meta.split("-")[0] : "en"
}

function overrides() {
  if (typeof window === "undefined") return {}
  return (window.PhlexForms && window.PhlexForms.messages) || {}
}

function lookup(scope, locale) {
  const table = { ...(messages[locale] || {}), ...(overrides()[locale] || {}) }
  return scope.split(".").reduce((node, key) => (node == null ? undefined : node[key]), table)
}

export function interpolate(string, vars = {}) {
  return string.replace(/%\{(\w+)\}/g, (_, key) => (key in vars ? String(vars[key]) : `%{${key}}`))
}

// t("js.forms.validations.presence.blank", { count: 3 })
// Falls back to English, then to the raw key, so a missing translation never
// throws or renders blank.
export function t(scope, vars = {}) {
  const locale = detectLocale()
  const message = lookup(scope, locale) ?? lookup(scope, "en") ?? scope
  return typeof message === "string" ? interpolate(message, vars) : scope
}
