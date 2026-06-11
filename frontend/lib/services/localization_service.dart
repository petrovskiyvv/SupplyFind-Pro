import 'package:flutter/material.dart';

class LocalizationService extends ChangeNotifier {
  final Locale _locale = const Locale('ru');
  Locale get locale => _locale;

  static final Map<String, Map<String, String>> _localizedValues = {
    'ru': {
      'app_title': 'Поставщики Food',
      'search_hint': 'Поиск по названию...',
      'category': 'Категория',
      'city': 'Город',
      'all': 'Все',
      'add_manual': 'Добавить вручную',
      'ai_discovery': 'AI Поиск',
      'discover_all': 'Глобальный AI Поиск',
      'compare': 'Сравнить',
      'manual_tag': 'Вручную',
      'ai_tag': 'AI',
      'no_suppliers': 'Поставщики не найдены',
      'inn': 'ИНН',
      'description': 'Описание',
      'website': 'Веб-сайт',
      'email': 'Электронная почта',
      'phone': 'Телефон',
      'min_order': 'Мин. заказ',
      'price_range': 'Цена',
      'certificates': 'Сертификаты',
      'delivery': 'Условия доставки',
      'notes': 'Ваши заметки',
      'save': 'Сохранить изменения',
      'compare_title': 'Сравнение условий',
      'parameter': 'Характеристика',
      'rating': 'Рейтинг',
      'add_title': 'Новый контрагент',
      'save_success': 'Данные успешно сохранены',
      'hide': 'Скрыть из списка',
      'undo': 'Отменить',
      'supplier_hidden': 'Контрагент перемещен в скрытые',
      'rfq': 'Запросить условия',
      'revenue': 'Годовая выручка',
      'status': 'Статус организации',
      'ai_summary': 'Аналитика нейросети',
      'error': 'Произошла ошибка',
      'select_filters': 'Укажите категорию и город для точного поиска',
      'discovery_in_progress': 'AI-Агент анализирует рынок и сайты поставщиков...',
      'discovered_count': 'Найдено новых компаний: ',
      'catalog_title': 'Каталог продукции',
      'company_name': 'Название компании',
      'loading_analytics': 'Нейросеть готовит отчет...',
      'no_data_analysis': 'Недостаточно данных для анализа',
      'ai_report_title': 'ИИ Отчет для Жизнь Март / Сушкофф',
      'tap_to_jump': 'Нажмите, чтобы прыгнуть!',
      'score': 'Счет',
      'cat_dairy': 'Молочные продукты',
      'cat_vegetables': 'Овощи и фрукты',
      'cat_meat': 'Мясная продукция',
      'cat_bakery': 'Хлебобулочные изделия',
      'verify_checking': 'Требуется проверка',
      'active_status': 'Действующая организация',
      'city_all': 'Все',
      'city_moscow': 'Москва',
      'city_spb': 'Санкт-Петербург',
      'city_krasnodar': 'Краснодар',
      'city_ekb': 'Екатеринбург',
    },
  };

  String translate(String key) {
    return _localizedValues[_locale.languageCode]?[key] ?? key;
  }
}

