# frozen_string_literal: true

module PhlexForms
  # Ractor-shareable copies of boot-time settings (the configuration, the
  # form_options / live class macros), so any Ractor can read them after boot.
  module Shareable
    module_function

    # A deep-frozen, Ractor-shareable copy of value; value itself is left as the
    # caller has it. A Proc cannot be copied, so it is shared in place, which
    # works only when its self and everything it captures are already shareable
    # (it never freezes them). A value that cannot be shared (a Proc whose self
    # is not shareable, an IO, ...) comes back unchanged: it still works on the
    # main Ractor. Engines without Ractor get the value back as is.
    def copy(value)
      return value unless defined?(::Ractor)
      return value if ::Ractor.shareable?(value)
      return ::Ractor.make_shareable(value) if value.is_a?(::Proc)

      ::Ractor.make_shareable(value, copy: true)
    rescue ::Ractor::Error, ::TypeError
      value
    end
  end
end
