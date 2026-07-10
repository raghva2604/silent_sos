import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Multilingual support service
class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._();

  factory LanguageService() => _instance;

  LanguageService._();

  String _currentLanguage = 'en';
  static const String _defaultLanguage = 'en';

  final Map<String, String> _languages = {
    'en': 'English',
    'es': 'Español',
    'fr': 'Français',
    'hi': 'हिन्दी',
    'te': 'తెలుగు',
    'zh': '中文',
    'pt': 'Português',
    'ar': 'العربية',
    'de': 'Deutsch',
  };

  /// UI Strings - Core SOS App
  final Map<String, Map<String, String>> _strings = {
    'en': {
      // Home Screen
      'app_title': 'Silent SOS',
      'sos_button': 'SOS',
      'sos_description': 'Press to activate emergency alert',
      'are_you_safe': 'ARE YOU SAFE?',
      'yes_im_safe': 'YES, I\'M SAFE',
      'no_need_help': 'NO, I NEED HELP',
      'alert_sent': 'Emergency alert sent to contacts',
      'alert_cancelled': 'Alert cancelled. You are marked safe.',

      // Automatic SOS
      'fall_detected': 'Fall detected! Sending SOS alert...',
      'voice_command': 'Voice command detected',

      // Contacts & Recipients
      'select_contacts': 'Select Emergency Contacts',
      'max_contacts': 'Maximum 5 contacts allowed',
      'max_emails': 'Maximum 5 email addresses allowed',
      'no_contacts_selected': 'No contacts selected',
      'contact_name': 'Contact Name',
      'contact_phone': 'Phone Number',
      'contact_email': 'Email Address',
      'add_contact': 'Add Contact',
      'remove_contact': 'Remove Contact',

      // Validation
      'invalid_email': 'Invalid email address',
      'invalid_phone': 'Invalid phone number',
      'email_already_added': 'Email already added',
      'phone_already_added': 'Phone already added',
      'verify_contacts': 'Verify contacts before sending',

      // AI Assistant
      'ai_assistant': 'AI Health Assistant',
      'describe_symptoms': 'Describe your symptoms or emergency',
      'offline_mode': 'Operating in offline mode',
      'online_mode': 'Connected to online AI',
      'critical_condition': 'CRITICAL: Call emergency services immediately',
      'first_aid_advice': 'First Aid Advice',

      // Settings
      'settings': 'Settings',
      'language': 'Language',
      'fall_detection': 'Fall Detection',
      'vibration_intensity': 'Vibration Intensity',
      'vibration_strength': 'Vibration Strength',
      'amplitude': 'Amplitude',
      'sos_timer': 'SOS Countdown Timer',
      'fall_threshold': 'Fall Detection Threshold',
      'preview_vibration': 'Preview Fall Vibration',
      'seconds': 'seconds',
      'enable_all_features': 'Enable All Features',
      'permissions': 'Permissions',
      'about': 'About App',

      // Map
      'show_map': 'Show Map',
      'nearby_hospitals': 'Nearby Hospitals',
      'nearby_police': 'Nearby Police',
      'nearby_fire': 'Nearby Fire Station',
      'current_location': 'Your Location',
      'offline_map': 'Offline map available',

      // Permissions
      'location_permission': 'Location Access',
      'camera_permission': 'Camera Access',
      'microphone_permission': 'Microphone Access',
      'contacts_permission': 'Contacts Access',
      'storage_permission': 'Storage Access',

      // Video & Media
      'front_camera': 'Front Camera',
      'back_camera': 'Back Camera',
      'recording': 'Recording...',
      'video_sent': 'Video sent to contacts',

      // General
      'ok': 'OK',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'close': 'Close',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
    },
    'es': {
      'app_title': 'SOS Silencioso',
      'sos_button': 'SOS',
      'sos_description': 'Presiona para activar alerta de emergencia',
      'are_you_safe': '¿ESTÁS SEGURO?',
      'yes_im_safe': 'SÍ, ESTOY SEGURO',
      'no_need_help': 'NO, NECESITO AYUDA',
      'alert_sent': 'Alerta enviada a contactos',
      'fall_detected': '¡Caída detectada! Enviando alerta SOS...',
      'voice_command': 'Comando de voz detectado',
      'select_contacts': 'Seleccionar Contactos de Emergencia',
      'max_contacts': 'Máximo 5 contactos permitidos',
      'ai_assistant': 'Asistente de Salud IA',
      'offline_mode': 'Operando en modo sin conexión',
      'critical_condition': 'CRÍTICO: Llama a emergencias inmediatamente',
      'settings': 'Configuración',
      'language': 'Idioma',
      'fall_detection': 'Detección de Caídas',
      'vibration_strength': 'Fuerza de Vibración',
      'amplitude': 'Amplitud',
      'sos_timer': 'Temporizador de Cuenta Regresiva SOS',
      'fall_threshold': 'Umbral de Detección de Caídas',
      'preview_vibration': 'Vista Previa de Vibración',
      'seconds': 'segundos',
      'ok': 'OK',
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'delete': 'Eliminar',
    },
    'fr': {
      'app_title': 'SOS Silencieux',
      'sos_button': 'SOS',
      'sos_description': 'Appuyez pour activer l\'alerte d\'urgence',
      'are_you_safe': 'ÊTES-VOUS EN SÉCURITÉ?',
      'yes_im_safe': 'OUI, JE SUIS EN SÉCURITÉ',
      'no_need_help': 'NON, J\'AI BESOIN D\'AIDE',
      'alert_sent': 'Alerte envoyée aux contacts',
      'fall_detected': 'Chute détectée! Envoi de l\'alerte SOS...',
      'select_contacts': 'Sélectionner les Contacts d\'Urgence',
      'ai_assistant': 'Assistant Santé IA',
      'offline_mode': 'Fonctionnement en mode hors ligne',
      'settings': 'Paramètres',
      'language': 'Langue',
      'fall_detection': 'Détection des Chutes',
      'vibration_strength': 'Force de Vibration',
      'amplitude': 'Amplitude',
      'sos_timer': 'Minuteur de Décompte SOS',
      'fall_threshold': 'Seuil de Détection des Chutes',
      'preview_vibration': 'Aperçu de la Vibration',
      'seconds': 'secondes',
      'ok': 'OK',
      'cancel': 'Annuler',
    },
    'hi': {
      'app_title': 'साइलेंट एसओएस',
      'sos_button': 'एसओएस',
      'sos_description': 'आपातकालीन अलर्ट सक्रिय करने के लिए दबाएं',
      'are_you_safe': 'क्या आप सुरक्षित हैं?',
      'yes_im_safe': 'हाँ, मैं सुरक्षित हूँ',
      'no_need_help': 'नहीं, मुझे मदद चाहिए',
      'alert_sent': 'संपर्कों को अलर्ट भेजा गया',
      'fall_detected': 'गिरावट का पता चला! एसओएस अलर्ट भेज रहे हैं...',
      'select_contacts': 'आपातकालीन संपर्क चुनें',
      'ai_assistant': 'एआई स्वास्थ्य सहायक',
      'offline_mode': 'ऑफ़लाइन मोड में चल रहा है',
      'settings': 'सेटिंग्स',
      'language': 'भाषा',
      'fall_detection': 'गिरावट पहचान',
      'vibration_strength': 'कंपन की शक्ति',
      'amplitude': 'आयाम',
      'sos_timer': 'एसओएस काउंटडाउन टाइमर',
      'fall_threshold': 'गिरावट पहचान थ्रेशोल्ड',
      'preview_vibration': 'कंपन पूर्वावलोकन',
      'seconds': 'सेकंड',
      'ok': 'ठीक है',
      'cancel': 'रद्द करें',
    },
    'zh': {
      'app_title': '静默SOS',
      'sos_button': 'SOS',
      'sos_description': '按下激活紧急警报',
      'are_you_safe': '你安全吗?',
      'yes_im_safe': '是的，我很安全',
      'no_need_help': '不，我需要帮助',
      'alert_sent': '已向联系人发送警报',
      'fall_detected': '检测到跌倒！正在发送SOS警报...',
      'select_contacts': '选择紧急联系人',
      'ai_assistant': 'AI 健康助手',
      'offline_mode': '离线模式运行',
      'settings': '设置',
      'language': '语言',
      'ok': '确定',
      'cancel': '取消',
    },
    'te': {
      'app_title': 'నిశ్శబ్ద SOS',
      'sos_button': 'SOS',
      'sos_description': 'জরুरی అలర్ట్ को సక్రియ చేయడానికి నొక్కండి',
      'are_you_safe': 'మీరు సురక్షితమైనారా?',
      'yes_im_safe': 'అవును, నేను సురక్షితమైనవాడిని',
      'no_need_help': 'లేవు, నాకు సహాయం కావాలి',
      'alert_sent': 'సంప్రదింపులకు అలర్ట్ పంపబడింది',
      'fall_detected': 'పడిపోవడం గుర్తించబడింది! SOS అలర్ట్ పంపుతున్నాము...',
      'voice_command': 'వాయిస్ కమాండ్ గుర్తించబడింది',
      'select_contacts': 'అత్యవసర సంప్రదింపులను ఎంచుకోండి',
      'max_contacts': 'గరిష్టంగా 5 సంప్రదింపులు అనుమతించబడతాయి',
      'ai_assistant': 'AI ఆరోగ్య సహాయకుడు',
      'describe_symptoms': 'మీ లక్షణాలు లేదా ఆపత్కాలీనతను వివరించండి',
      'offline_mode': 'ఆఫ్‌లైన్ మోడ్‌లో పనిచేస్తున్నాము',
      'online_mode': 'ఆన్‌లైన్ AIకు కనెక్ట్ చేయబడింది',
      'critical_condition': 'కీలకమైనది: వెంటనే అత్యవసర సేవలకు కాల్ చేయండి',
      'first_aid_advice': 'ప్రథమ సహాయ సలహా',
      'settings': 'సెట్టింగ్‌లు',
      'language': 'భాష',
      'fall_detection': 'పడిపోవడం గుర్తించడం',
      'vibration_intensity': 'వైబ్రేషన్ తీవ్రత',
      'vibration_strength': 'వైబ్రేషన్ శక్తి',
      'amplitude': 'విస్తృతి',
      'sos_timer': 'SOS కౌంట్‌డౌన్ టైమర్',
      'fall_threshold': 'పడిపోవడం గుర్తించే విలువ',
      'preview_vibration': 'వైబ్రేషన్ ప్రీవ్యూ',
      'seconds': 'సెకన్లు',
      'enable_all_features': 'అన్ని ఫీచర్‌లను ప్రారంభించండి',
      'permissions': 'అనుమతులు',
      'about': 'అనువర్తనం గురించి',
      'show_map': 'మ్యాప్ చూపించండి',
      'current_location': 'మీ స్థానం',
      'offline_map': 'ఆఫ్‌లైన్ మ్యాప్ అందుబాటులో ఉంది',
      'ok': 'సరే',
      'cancel': 'రద్దు చేయి',
      'save': 'సేవ్ చేయి',
      'delete': 'తొలిగించండి',
      'edit': 'సవరించండి',
      'close': 'మూసివేయి',
      'error': 'లోపం',
      'success': 'విజయం',
      'loading': 'లోడ్ చేస్తున్నాము...',
    },
  };

  /// Initialize language service
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('app_language') ?? _defaultLanguage;
    if (_languages.containsKey(saved)) {
      _currentLanguage = saved;
    }
  }

  /// Get translated string by key
  String t(String key) {
    return _strings[_currentLanguage]?[key] ??
        _strings[_defaultLanguage]?[key] ??
        key;
  }

  /// Get current language code
  String get currentLanguage => _currentLanguage;

  /// Get current language name
  String get currentLanguageName =>
      _languages[_currentLanguage] ?? _defaultLanguage;

  /// Get all available languages
  Map<String, String> get availableLanguages => _languages;

  /// Set language
  Future<void> setLanguage(String languageCode) async {
    if (!_languages.containsKey(languageCode)) return;

    _currentLanguage = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    notifyListeners();
  }

  /// Get all translations for current language
  Map<String, String> get allStrings =>
      _strings[_currentLanguage] ?? _strings[_defaultLanguage]!;
}

/// Helper function for quick access
String translate(String key) => LanguageService().t(key);
