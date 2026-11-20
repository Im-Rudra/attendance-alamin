/// Public surface of the settings feature (plan section 1 #32).
/// M6-E exports what other features need: the payment-method configuration
/// (the payment form shows `paymentMethodsConfigProvider`'s `.visible`) and the
/// template helpers (setting keys, defaults, sample rendering).
library;

export 'package:attendance_alamin/features/settings/controllers/settings_providers.dart'
    show paymentMethodsConfigProvider;
export 'package:attendance_alamin/features/settings/data/payment_methods_config.dart'
    show CustomLabelCheck, PaymentMethodsConfig;
export 'package:attendance_alamin/features/settings/data/template_logic.dart'
    show TemplateKind, defaultTemplate, editorTextFor, templateKey;
export 'package:attendance_alamin/features/settings/ui/payment_methods_screen.dart'
    show paymentMethodLabel;
